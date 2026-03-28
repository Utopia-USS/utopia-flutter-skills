---
title: Async Patterns
impact: HIGH
tags: async, useSubmitState, useAutoComputedState, loading, error, forms
---

# Skill: Async Patterns

Async operations in utopia_hooks follow a **download / upload** mental model:

| Direction | Hook | Trigger | Examples |
|-----------|------|---------|----------|
| **Download** (read) | `useAutoComputedState` | Automatic (keys change) | Load screen data, fetch list, search results |
| **Upload** (write) | `useSubmitState` | Manual (user action) | Save, delete, send, create — any mutation |
| **Stream** (reactive) | `useMemoizedStream` | Continuous | Real-time updates, auth state, live data |

**Default rule:** reading → `useAutoComputedState`, writing → `useSubmitState`, reactive → `useMemoizedStream`.

## Quick Pattern

**Incorrect (manual loading flag):**
```dart
final isLoading = useState(false);
final error = useState<String?>(null);

Future<void> submit() async {
  isLoading.value = true;
  error.value = null;
  try {
    await service.save(data);
    navigateBack();
  } catch (e) {
    error.value = e.toString();
  } finally {
    isLoading.value = false;
  }
}
```

**Correct (useSubmitState):**
```dart
final submitState = useSubmitState();

void submit() => submitState.runSimple<void, AppError>(
  submit: () async => service.save(data),
  afterSubmit: (_) => navigateBack(),
  mapError: (e) => e is AppError ? e : null,
  afterKnownError: (e) => showSnackbar(e.message),
);

// In State output:
isSaving: submitState.inProgress,
saveButtonState: submitState.toButtonState(enabled: isFormValid, onTap: submit),
```

---

## useSubmitState — your default "upload" hook

The go-to hook for any write/mutation operation. Manages the full lifecycle: idle → in progress → success/error.

Built-in protections:
- **Blocks duplicate requests** — while `inProgress`, calling `run`/`runSimple` again is a no-op; `skipIfInProgress: true` silently drops
- **Retry support** — `isRetryable` flag for recoverable failures
- **Typed error routing** — `mapError` converts raw exception → typed `E`, `afterKnownError` handles it

### runSimple

Full signature:
```dart
Future<void> runSimple<T, E>({
  FutureOr<bool> Function()? shouldSubmit,       // pre-check, return false to abort
  FutureOr<void> Function()? beforeSubmit,        // runs before submit
  required Future<T> Function() submit,           // the async work
  FutureOr<void> Function(T)? afterSubmit,        // called on success with result
  FutureOr<E?> Function(Object)? mapError,        // convert raw error → typed E (null = unknown)
  FutureOr<void> Function(E)? afterKnownError,    // handle typed error
  FutureOr<void> Function()? afterError,          // handle any error (known or unknown)
  bool isRetryable = true,
  bool skipIfInProgress = false,                  // silently skip if already running
})
```

Example:
```dart
final saveState = useSubmitState();

void save() => saveState.runSimple<SaveResult, SaveError>(
  submit: () async {
    return await service.saveItem(data);
  },
  afterSubmit: (result) {
    // called after submit completes successfully
    navigateBack();
  },
  mapError: (e) => e is SaveError ? e : null,
  afterKnownError: (error) {
    // called when mapError returns non-null
    showErrorSnackbar(error.message);
  },
  afterError: () {
    // called after any error (known or unknown) — use for analytics, cleanup
    analytics.track('save_failed');
  },
);
```

### toButtonState

Converts `useSubmitState` into a `ButtonState` for `CrazySquashButton.withState`:

```dart
// In State class
final ButtonState saveButtonState;

// In State hook
saveButtonState: saveState.toButtonState(
  enabled: nameState.value.isNotEmpty && !saveState.inProgress,
  onTap: save,
),

// In View — button shows loading spinner automatically
CrazySquashButton.withState(
  state: state.saveButtonState,
  child: const Text("Save"),
)
```

### inProgress

```dart
// Show a loading indicator while saving
CrazyLoader(visible: saveState.inProgress)

// Disable other actions while submitting
onTap: saveState.inProgress ? null : onOtherAction,
```

### Multiple submit states

```dart
// One per independent async action
final saveState = useSubmitState();
final deleteState = useSubmitState();
final exportState = useSubmitState();

return PageState(
  isSaving: saveState.inProgress,
  isDeleting: deleteState.inProgress,
  isExporting: exportState.inProgress,
  onSave: () => saveState.runSimple(...),
  onDelete: () => deleteState.runSimple(...),
  onExport: () => exportState.runSimple(...),
);
```

---

## useAutoComputedState — your default "download" hook

The go-to hook for any read/load operation. Computes an async value automatically, re-fetches when `keys` change.
Returns a state with `isInitialized`, `valueOrNull`, and `value`.

### Basic usage

```dart
// Load data once
final product = useAutoComputedState(
  () async => productService.load(productId),
);

// Re-load when productId changes
final product = useAutoComputedState(
  () async => productService.load(productId),
  keys: [productId],
);

// Only compute when a prerequisite is ready
final orderHistory = useAutoComputedState(
  () async => orderService.loadHistory(userId),
  keys: [userId],
  shouldCompute: authState.isInitialized && userId != null,
);
```

### Reading the result

```dart
product.isInitialized   // false while loading
product.valueOrNull     // null while loading, T after
product.value           // T, throws StateError if not initialized

// Typical usage in State hook
return ProductPageState(
  isLoading: !product.isInitialized,
  product: product.valueOrNull,
);
```

### Loading guard in View

```dart
// View pattern for optional data
Widget build(BuildContext context) {
  if (state.isLoading) return const CrazyLoader();
  if (state.product == null) return const EmptyState();
  return _buildContent(state.product!);
}
```

### useAutoComputedState vs useMemoizedStream

| | `useAutoComputedState` | `useMemoizedStream` |
|---|---|---|
| Use for | One-shot `Future<T>` | Ongoing `Stream<T>` |
| Re-triggers on | `keys` change + `shouldCompute` | `keys` change (re-subscribes) |
| Returns | `ComputedState<T>` | `AsyncSnapshot<T>` |
| Initialized when | future completes | `connectionState == active` |

---

## useMemoizedStream

Subscribes to a `Stream<T>`. Builds `AsyncSnapshot<T>` — re-renders on every emitted value.

```dart
// Single stream
final notificationsSnap = useMemoizedStream(notificationService.stream);

// Re-subscribe when userId changes
final messagesSnap = useMemoizedStream(
  () => messageService.stream(userId),
  keys: [userId],
);

// Reading
final notifications = notificationsSnap.data;           // T? — null before first event
final isConnected = notificationsSnap.connectionState == ConnectionState.active;
final hasError = notificationsSnap.hasError;
```

### isInitialized pattern for global state

```dart
class NotificationsState extends HasInitialized {
  final IList<Notification>? items;
  const NotificationsState({required super.isInitialized, required this.items});
}

NotificationsState useNotificationsState() {
  final snap = useMemoizedStream(notificationService.stream);
  return NotificationsState(
    isInitialized: snap.connectionState == ConnectionState.active,
    items: snap.data,
  );
}
```

---

## Form Validation Pattern

```dart
// State hook
final emailState = useFieldState(initialValue: user?.email ?? '');
final passwordState = useFieldState();
final submitState = useSubmitState();

bool get isFormValid =>
  !emailState.hasError &&
  !passwordState.hasError &&
  emailState.value.isNotEmpty &&
  passwordState.value.isNotEmpty;

void validateAndSubmit() {
  // .validate() runs validator and sets .errorMessage automatically
  emailState.validate((v) => isValidEmail(v) ? null : (context) => 'Invalid email');
  passwordState.validate((v) => v.length >= 8 ? null : (context) => 'Minimum 8 characters');

  if (!isFormValid) return;

  submitState.runSimple<void, AppError>(
    submit: () async => authService.login(
      email: emailState.value,
      password: passwordState.value,
    ),
    afterSubmit: (_) => navigateToHome(),
    mapError: (e) => e is AppError ? e : null,
    afterKnownError: (e) => showSnackbar(e.message),
  );
}

return LoginPageState(
  email: emailState,
  password: passwordState,
  loginButtonState: submitState.toButtonState(
    enabled: isFormValid,
    onTap: validateAndSubmit,
  ),
);

// View — just wire up state
CrazyTextField(state: state.email, label: const Text("Email"))
CrazyTextField(state: state.password, label: const Text("Password"), obscureText: true)
CrazySquashButton.withState(state: state.loginButtonState, child: const Text("Login"))
```

---

## Common Pitfalls

- **Multiple `useSubmitState` for the same action** — one per action, don't reuse across different operations
- **Not propagating errors to UI** — always handle `mapError` + `afterKnownError` and surface the message via snackbar or field error
- **`useAutoComputedState` without `shouldCompute`** — if prerequisites (like `userId`) may be null, guard with `shouldCompute: userId != null` or the future will run with null
- **Reading `.value` before `isInitialized`** — `.value` throws `StateError`; use `.valueOrNull` for safe access
- **Using `useSubmitState` for streaming** — `useSubmitState` is for one-shot operations; use `useMemoizedStream` for ongoing streams

## Related Skills

- [hooks-reference.md](./hooks-reference.md) — useSubmitState, useAutoComputedState, useMemoizedStream in context
- [page-state-view.md](./page-state-view.md) — where async state is exposed (State class) and consumed (View)
- [global-state.md](./global-state.md) — HasInitialized for global async state
