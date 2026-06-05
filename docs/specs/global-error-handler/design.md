# Design: Global Error Handler

## 1. Architecture Overview

```
                        [ Application Execution ]
                                   │
         ┌─────────────────────────┴─────────────────────────┐
         ▼                                                   ▼
  [ Widget Tree / Layout / Render ]                 [ Async Tasks / Background ]
         │                                                   │
         ▼ (Uncaught)                                        ▼ (Uncaught)
  FlutterError.onError                              PlatformDispatcher.instance.onError
         │                                                   │
         └─────────────────────────┬─────────────────────────┘
                                   ▼
                       [ _logGlobalError() Utility ]
                                   │
                         [ developer.log() ]
                                   │
                         (Only on Render Crash)
                                   ▼
                          ErrorWidget.builder
                                   │
                         [ FriendlyErrorWidget ]
```

## 2. Implementation Specifications

### 2.1 main.dart Modifications

We will insert error handling hooks at the beginning of `main()` right after `WidgetsFlutterBinding.ensureInitialized()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup Global Error Logging Interceptors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // Keeps standard console output & DevTools integration
    _logGlobalError(
      title: 'FLUTTER FRAMEWORK ERROR',
      emoji: '🚨',
      error: details.exceptionAsString(),
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _logGlobalError(
      title: 'UNCAUGHT ASYNCHRONOUS ERROR',
      emoji: '⚡',
      error: error,
      stackTrace: stack,
    );
    return true; // Mark error as handled so process doesn't crash abruptly
  };

  // Custom visual feedback for widget build/render failures
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return FriendlyErrorWidget(details: details);
  };

  await EasyLocalization.ensureInitialized();
  // ... rest of main() initialization
}
```

### 2.2 Helper Utility `_logGlobalError`

A specialized formatting function to render highly visible logs in the console:

```dart
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

void _logGlobalError({
  required String title,
  required String emoji,
  required Object error,
  required StackTrace? stackTrace,
}) {
  if (!kDebugMode) return; // Silent in release modes to prevent console clutter

  final buffer = StringBuffer();
  buffer.writeln('======================================================================');
  buffer.writeln('$emoji $title');
  buffer.writeln('----------------------------------------------------------------------');
  buffer.writeln('Error: $error');
  if (stackTrace != null) {
    buffer.writeln('----------------------------------------------------------------------');
    buffer.writeln('Stack Trace:');
    buffer.writeln(stackTrace.toString().split('\n').take(12).join('\n')); // Show top 12 frames for clarity
  }
  buffer.writeln('======================================================================');

  developer.log(
    buffer.toString(),
    name: 'DuaSakuError',
    error: error,
    stackTrace: stackTrace,
  );
}
```

### 2.3 Fallback UI `FriendlyErrorWidget`

A premium, glassmorphic layout conforming to the DuaSaku design language to replace the default red error page:

- **Structure**: Uses standard `Scaffold` and `SafeArea`.
- **Styling**: Leverages `Theme.of(context)` for background and text styling (fully dynamic dark/light theme aware).
- **Interactions**: Displays a concise description of the crash. In debug mode (`kDebugMode`), provides an expandable or scrollable box showing details of the exception so developers can troubleshoot without looking at the console.
