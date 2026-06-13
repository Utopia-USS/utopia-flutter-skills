---
title: Media uploads with CmsMediaEntry and CmsMediaDelegate
impact: MEDIUM
tags: media, upload, image, video, file
---

# Skill: Media Uploads

Images, videos, and generic file attachments live behind `CmsMediaEntry`. The
upload/delete contract is `CmsMediaDelegate` - there's no prebuilt
implementation; you write one against your storage backend (signed URLs, S3,
Firebase Storage, Supabase Storage).

## Quick Pattern

```dart
class FileDelegate implements CmsMediaDelegate {
  final CmsGraphQLService graphQLService;
  final GraphQLClient client;

  const FileDelegate(this.graphQLService, this.client);

  @override
  Future<CmsMediaUploadRes> upload(XFile file) async {
    final (uploadUrl, downloadUrl) = await _createAttachment(mimeType: file.mimeType!);
    await _upload(uploadUrl, file);
    return CmsMediaUploadRes(downloadUrl: downloadUrl, ref: 'opaque-id');
  }

  @override
  Future<void> delete(dynamic value) async {
    // `value` is whatever you stored on the row (via `valueBuilder`)
    // e.g. a download URL string, or a {url, content_type, ref} map.
    await api.deleteAttachment(value as String);
  }
}

// In your entries list:
CmsMediaEntry(
  key: 'attachments',
  label: 'Attachments',
  delegate: FileDelegate(service, client),
  supportedMedia: const [CmsMediaType.image, CmsMediaType.video, CmsMediaType.doc],
  mediaTypeBuilder: (object) => CmsMediaType.fromMime(object['content_type'] as String? ?? ''),
  urlBuilder:       (object) => object['url'] as String,
  valueBuilder:     (res, file) => {'url': res.downloadUrl, 'content_type': file.mimeType},
)
```

## API

```dart
CmsMediaEntry({
  required String key,
  required CmsMediaDelegate delegate,
  required List<CmsMediaType> supportedMedia,                   // [image, video, doc, unknown]
  required CmsMediaType Function(dynamic object) mediaTypeBuilder,
  String Function(dynamic object)? urlBuilder,                  // null → use object as URL directly
  dynamic Function(CmsMediaUploadRes res, XFile file)? valueBuilder,
  String? label,
  CmsEntryModifier modifier = const CmsEntryModifier(expanded: true),
  int flex = 2,
})
```

- **`supportedMedia`** - gates the file picker (`image`/`video`/`doc`/`unknown`).
- **`mediaTypeBuilder`** - given a stored object (`JsonMap` or a primitive), return its media type so the entry knows how to render it. `CmsMediaType.fromMime` is the easy implementation.
- **`urlBuilder`** - extract the displayable URL from each stored object. Default: the object itself is the URL.
- **`valueBuilder`** - convert the `CmsMediaUploadRes` returned by `delegate.upload` into the value stored on the row. Default: store the download URL string.
- **`modifier.expanded: true`** (default) - media gets its own full row in the edit overlay.

**Known limitation (v0.2.3):** the stock `CmsMediaEntry` edit field resolves the
overlay's `CmsManagementBaseState` with utopia_hooks' `useProvided`, but the
overlay provides it via `package:provider` - the lookup can throw
`ProvidedValueNotFoundException` when the field mounts. If you hit it, the
workaround is a custom entry whose edit field obtains the state with
`Provider.of<CmsManagementBaseState>(context, listen: false)` instead
(`CmsManagementBaseState` isn't exported - deep-import
`package:utopia_cms/src/ui/item_management/state/cms_management_state.dart`).
The same rule applies to all your own overlay code: always `Provider.of`,
never `useProvided`.

### `CmsMediaDelegate`

```dart
abstract class CmsMediaDelegate {
  Future<CmsMediaUploadRes> upload(XFile file);
  Future<void> delete(dynamic value);                                       // `value` is whatever you stored on the row
}
```

You implement this. The `XFile` comes from the user's picker; `CmsMediaUploadRes`
carries the resulting download URL plus an opaque `ref` (typedef
`CmsFileRef = String`). If `delete` needs the `ref`, stash it on the row via
`valueBuilder` - by default only the download URL string is stored.

`delete(value)` receives the row-side representation produced by your
`valueBuilder` - typically a download URL string or a `{url, content_type, ref}` map.
Cast accordingly.

### `CmsMediaType`

```dart
enum CmsMediaType {
  video(mimes: [...]),   // mp4, webm, quicktime, x-m4v
  image(mimes: [...]),   // jpeg, png, gif, webp
  doc(mimes: [...]),     // pdf, word, excel, powerpoint, csv, txt, epub
  unknown(mimes: []);

  final List<String> mimes;
  static CmsMediaType fromMime(String mime);    // classify a MIME string
}

// extension on List<CmsMediaType>
List<String> get getMimes;                      // expand supportedMedia into the MIME allowlist
```

Used both as a filter (`supportedMedia`) and as a discriminator
(`mediaTypeBuilder`). If the row stores each file's MIME type,
`(o) => CmsMediaType.fromMime(o['content_type'] as String? ?? '')` is the whole
`mediaTypeBuilder` - don't hand-roll the classification. Note the value is
`doc`, not `document`. Avoid putting `.unknown` into `supportedMedia`:
`getMimes` then returns `[]` and drag-and-drop rejects every file as of v0.2.3.

## Upload and delete lifecycle

How the field behaves at runtime (as of v0.2.3) determines where orphaned blobs
can appear in storage - know this before writing the delegate:

1. **Add = immediate upload.** The moment a file is picked or dropped,
   `delegate.upload` runs and the tile shows a spinner. On completion the file
   is replaced in the field value by your `valueBuilder` result (or the raw
   download URL).
2. **The field value contains only finished uploads.** While a spinner tile is
   visible the in-flight file is not part of the entry's value - saving at that
   moment stores the row without it, even though the blob still lands in
   storage.
3. **Remove = deferred storage delete.** Removing a tile only queues the item;
   `delegate.delete` runs for each removed item *after the overlay saves
   successfully* (registered through the overlay's saved callbacks). Row update
   and storage delete are not atomic.
4. **Cancel rolls back nothing.** Closing the overlay without saving deletes
   nothing from storage: files uploaded during the session stay behind as
   orphaned blobs, and removed-then-cancelled items keep both row value and
   blob.
5. **Reordering is drag-based** and disabled while any upload is pending; the
   stored list order is the tile order.

Consequence: orphaned blobs are a normal outcome (upload-then-cancel,
save-mid-upload). Make `delete` best-effort and, if storage cost matters, run a
periodic server-side orphan sweep instead of trying to prevent orphans
client-side.

## Writing a delegate - pattern

The shape is always:

1. Ask the backend for an upload URL (signed PUT for S3, Supabase Storage path, Firebase Storage ref, GraphQL `createAttachment` mutation, etc.).
2. PUT/POST the file bytes.
3. Return the download URL (+ any opaque ref you need to later delete).

Three production details, whatever the backend:

- **uuid object names.** Never use the user's filename as the object name - `image.png` collides instantly. Generate a uuid, keep the extension.
- **Explicit `contentType` metadata.** Without it many backends serve `application/octet-stream` and browsers download files instead of rendering previews.
- **Best-effort `delete`.** It runs inside the save flow (see lifecycle above); a failed blob delete must not fail the row save. Swallow errors.

```dart
// Firebase Storage example - one instance per storage path prefix.
class StorageMediaDelegate implements CmsMediaDelegate {
  final String pathPrefix;

  const StorageMediaDelegate({required this.pathPrefix});

  @override
  Future<CmsMediaUploadRes> upload(XFile file) async {
    final ext = file.name.split('.').last;
    final ref = FirebaseStorage.instance.ref('$pathPrefix/${const Uuid().v4()}.$ext');
    await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: file.mimeType));
    return CmsMediaUploadRes(downloadUrl: await ref.getDownloadURL(), ref: ref.fullPath);
  }

  @override
  Future<void> delete(dynamic value) async {
    try {
      // `value` is whatever you stored - here the plain URL (default).
      final url = value is CmsMediaUploadRes ? value.downloadUrl : value as String;
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (_) {/* orphaned blobs are acceptable; broken saves are not */}
  }
}
```

The framework code includes an HTTP example using `HttpRequest` (web). For
cross-platform use, prefer `http.put` or `dio.put`.

## Single file (scalar column)

`CmsMediaEntry` is `CmsEntry<Iterable<dynamic>?>` - it always stores a *list*.
For a scalar URL column (`cover_url`, `avatar_url`) write a thin custom entry
that delegates to the exported `CmsMediaField` widget and wraps/unwraps a
one-element list:

```dart
class SingleMediaEntry extends CmsEntry<dynamic> {
  final CmsMediaDelegate delegate;

  SingleMediaEntry({required this.key, required this.delegate, this.label});

  @override
  final String key;
  @override
  final String? label;
  @override
  final CmsEntryModifier modifier = const CmsEntryModifier(expanded: true);
  @override
  final int flex = 2;

  @override
  Widget buildPreview(BuildContext context, dynamic value) =>
      value == null ? const Text('-') : Image.network(value as String, height: 40);

  @override
  Widget buildEditField({
    required BuildContext context,
    required dynamic value,
    required void Function(dynamic) onChanged,
  }) {
    return CmsMediaField(
      label: fixedLabelRequired,
      delegate: delegate,
      supportedMedia: const [CmsMediaType.image],
      mediaTypeBuilder: (_) => CmsMediaType.image,
      urlBuilder: (object) => object as String,
      valueBuilder: (res, _) => res.downloadUrl,
      initialValues: value == null ? null : [value],                  // scalar → 1-element list
      onChanged: (values) {
        final list = values?.toList();
        onChanged(list == null || list.isEmpty ? null : list.first);  // list → scalar
      },
    );
  }
}
```

Notes:

- v0.2.3's `CmsMediaField` has no max-files cap, so the add button stays
  visible while a file is present; the unwrap keeps the *first* item - remove
  the old file before adding its replacement.
- Newer development branches of utopia_cms ship this as a built-in
  `CmsSingleMediaEntry`; released v0.2.3 does not - keep the wrapper in app
  code until you're on a version that has it.
- `CmsMediaField` resolves the overlay state the same way the stock entry does,
  so the known limitation above applies to this wrapper too.

## Standalone preview: CmsVideoPlayer

The themed video player behind media previews is exported on its own - use it
when a management section or custom page needs to play a row's video outside
`CmsMediaEntry`. It re-exports `package:video_player`, so you don't add that
dependency yourself.

```dart
CmsVideoPlayer(
  url: row['video_url'] as String,
  previewOnly: false,                      // true = render only, no interaction
  playerBuilder: (controller, player) =>   // optional: wrap the raw player
      Column(children: [player, VideoProgressIndicator(controller, allowScrubbing: true)]),
)
```

Play/pause overlay and focus-based auto-pause (it stops when focus is lost)
come built in; a loader shows until the controller initializes.

## Rules

- **Use `CmsMediaEntry` for files** - don't store base64 in a text field.
- **`expanded: true`** is sensible for media - the picker UI is large.
- **Multiple files = `Iterable<dynamic>` value.** The entry handles a list; design `valueBuilder` to produce list-friendly items. For scalar columns, see "Single file" above.
- **Don't reuse one upload URL.** Each upload should mint a fresh signed URL on the backend.
- **Implement `delegate.delete`.** Removed files are deleted after save (see lifecycle) - without it they leak unconditionally.

## Pitfalls

1. **Forgetting `mimeType` on `XFile`.** Web `XFile` carries mime; mobile may be null. Provide a fallback.
2. **Returning a non-list value from `valueBuilder`** when the storage column expects a list. Match the backend schema.
3. **Skipping `urlBuilder` while storing structured objects.** If the row stores `{url, content_type}` per file, the entry needs `urlBuilder` to find the displayable URL.
4. **CORS on the signed URL.** Browser uploads fail silently without proper CORS on the storage bucket.
5. **Writing `CmsMediaType.document`.** The enum value is `doc` - `document` does not compile.

## See also

- [entries.md](entries.md) - entry catalog
- [delegates.md](delegates.md) - main row delegate
- [management-sections.md](management-sections.md) - custom overlay sections (and the saved-callback mechanism deletes hook into)
- [`utopia_cms` core README - Media section](https://github.com/Utopia-USS/utopia_cms) - original example with GraphQL `createAttachment`
