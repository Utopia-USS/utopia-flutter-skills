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
  int? flex = 2,
  double? width,
  int? maxFiles,                                                // null = unlimited; cap simultaneous files
})
```

- **`supportedMedia`** - gates the file picker (`image`/`video`/`doc`/`unknown`).
- **`mediaTypeBuilder`** - given a stored object (`JsonMap` or a primitive), return its media type so the entry knows how to render it. `CmsMediaType.fromMime` is the easy implementation.
- **`urlBuilder`** - extract the displayable URL from each stored object. Default: the object itself is the URL.
- **`valueBuilder`** - convert the `CmsMediaUploadRes` returned by `delegate.upload` into the value stored on the row. Default: store the download URL string.
- **`maxFiles`** - cap on simultaneous files (`null` = unlimited); once reached, the add button hides. For single-file fields prefer `CmsSingleMediaEntry` (below).
- **`modifier.expanded: true`** (default) - media gets its own full row in the edit overlay.

> The 0.2.x "stock media field throws `ProvidedValueNotFoundException`" bug is **fixed in 0.3.0**:
> the field reads the overlay state with `Provider.of<CmsManagementBaseState>(context, listen: false)`.
> The rule for your *own* overlay code still holds - resolve the overlay state with `Provider.of`,
> never utopia_hooks' `useProvided` (the overlay publishes it through `package:provider`). And
> `CmsManagementBaseState` is now a public export, so no deep `src/` import is needed.

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
`getMimes` then returns `[]` and drag-and-drop rejects every file as of 0.3.0.

## Upload and delete lifecycle

How the field behaves at runtime (as of 0.3.0) determines where orphaned blobs
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

`CmsMediaEntry` stores an `Iterable` (a list). For a scalar column (`cover_url`,
`avatar_url`) use **`CmsSingleMediaEntry`** (new in 0.3.0) - it stores a single object
directly under `key` (typically the URL string from `valueBuilder`) instead of a
one-element list, and renders a `CmsMediaField` capped at one file:

```dart
CmsSingleMediaEntry(
  key: 'cover_url',
  label: 'Cover',
  delegate: StorageMediaDelegate(pathPrefix: 'covers'),
  supportedMedia: const [CmsMediaType.image],
  mediaTypeBuilder: (_) => CmsMediaType.image,
  urlBuilder: (object) => object as String,            // stored value -> displayable URL
  // valueBuilder: (res, file) => res.downloadUrl,      // default already stores the download URL string
)
```

Its constructor mirrors `CmsMediaEntry` (`delegate` / `supportedMedia` / `mediaTypeBuilder` /
`urlBuilder` / `valueBuilder` / `label` / `modifier` / `flex` / `width`), minus `maxFiles`
(it is pinned to one file). It extends `CmsEntry<dynamic>`, so the value you read and write is
the scalar itself, not a list. The hand-rolled 0.2.x single-media wrapper is no longer needed.

## Standalone preview: CmsVideoPlayer

The themed video player behind media previews is exported on its own - use it
when a management section or custom page needs to play a row's video outside
`CmsMediaEntry`. As of 0.3.0 it is backed by `media_kit` (not `video_player`) and
does not re-export any player package, so callers work in terms of the widget, not
a controller.

```dart
CmsVideoPlayer(
  url: row['video_url'] as String,
  previewOnly: false,                          // true = render only, no interaction
  playerBuilder: (naturalSize, player) =>      // optional: wrap the already-sized player
      FittedBox(fit: BoxFit.cover, child: SizedBox.fromSize(size: naturalSize, child: player)),
)
```

`playerBuilder` receives the video's natural `Size` and the `player` widget already sized to it
(handy for `FittedBox`-based cropping) - **not** a controller (the old `(controller, player)` /
`VideoProgressIndicator` shape no longer compiles). When omitted, the video shows at its own
aspect ratio. Play/pause overlay and focus-based auto-pause (it stops when focus is lost) come
built in; a loader shows until the player initializes.

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
