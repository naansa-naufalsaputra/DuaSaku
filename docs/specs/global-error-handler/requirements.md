# Requirements: Global Error Handler

## 1. Introduction
To improve the reliability and troubleshooting experience of the DuaSaku application, this feature introduces a robust, unified, and clean Global Error Handler. It will capture all unhandled Flutter-framework exceptions and root-level asynchronous Dart zone errors. It will structure and output these errors with category emoji tags in the Debug Console and render a premium fallback UI when runtime rendering crashes occur.

## 2. Requirements

### 2.1 Exception Interception
- **Req 2.1.1**: Intercept all Flutter widget/framework-level layout and state exceptions using `FlutterError.onError`.
- **Req 2.1.2**: Intercept all unhandled asynchronous root-level zone errors (e.g., failed async API calls, database read/write faults in background streams) using `PlatformDispatcher.instance.onError`.
- **Req 2.1.3**: The error interception MUST NOT obstruct standard framework logging in debug mode; it should augment logs with a clear format.

### 2.2 Console Log Formatting
- **Req 2.2.1**: Outputted logs in the Debug Console MUST be clear and visually distinguished using emoji tags:
  - Framework exceptions: `🚨 [FLUTTER FRAMEWORK ERROR]`
  - Asynchronous exceptions: `⚡ [UNCAUGHT ASYNCHRONOUS ERROR]`
- **Req 2.2.2**: Log content MUST print:
  - Error/Exception type and message.
  - Formatted stack trace (limited to key frames or human-readable format).
  - Component boundary (if extractable).

### 2.3 User-Friendly Fallback Error Screen
- **Req 2.3.1**: Override `ErrorWidget.builder` with a premium fallback error widget (`FriendlyErrorWidget`) instead of the default red screen of death.
- **Req 2.3.2**: The fallback widget MUST support bilingual system look-and-feel (simple bilingual text fallback, e.g. "Ooops! Something went wrong / Terjadi kesalahan sistem").
- **Req 2.3.3**: The fallback widget MUST adapt dynamically to the active `ThemePresets` (using the system context theme color scheme).
- **Req 2.3.4**: In debug mode (`kDebugMode`), the exception message/stack detail MUST also be displayed inside a scrollable box for immediate visual developer feedback.
