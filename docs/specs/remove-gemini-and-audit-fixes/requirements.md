# Requirements: Gemini Decommissioning & Mobile Audit Fixes

## 1. Introduction
With the successful on-device integration of the Level 3 Joint NLP ML model, the application no longer requires external API calls to Google Gemini for transaction parsing. This specification outlines the complete decommissioning of Gemini AI dependencies, removal of API key management forms, and remediation of the mobile audit issues (touch targets, haptics, theme consistency).

## 2. Gemini Decommissioning & Clean Up

### 2.1 Settings & UI Removal
- **Req 2.1.1**: The "AI & Gemini Settings" section and the Gemini API Key list tile MUST be removed from [profile_screen.dart](file:///c:/Codingg/duasaku_app/lib/features/profile/presentation/screens/profile_screen.dart).
- **Req 2.1.2**: The `_showGeminiKeyDialog` dialog method in [profile_screen.dart](file:///c:/Codingg/duasaku_app/lib/features/profile/presentation/screens/profile_screen.dart) MUST be deleted.
- **Req 2.1.3**: The scan receipt button (OCR scanner) in [home_screen.dart](file:///c:/Codingg/duasaku_app/lib/features/transactions/presentation/screens/home_screen.dart) (which uses Gemini's `scanReceipt`) MUST be removed, as the app is transitioning to 100% offline local transaction parsing.
- **Req 2.1.4**: Remove the AI Chat route (`/ai-chat`) and imports from [app_router.dart](file:///c:/Codingg/duasaku_app/lib/core/routing/app_router.dart), and delete the [ai_chat](file:///c:/Codingg/duasaku_app/lib/features/ai_chat) feature folder since it relies on Gemini APIs and is now obsolete.

### 2.2 Service & Provider Decommissioning
- **Req 2.2.1**: The `GeminiService` class in [gemini_service.dart](file:///c:/Codingg/duasaku_app/lib/services/gemini_service.dart) and its Riverpod provider `geminiServiceProvider` in [service_providers.dart](file:///c:/Codingg/duasaku_app/lib/services/service_providers.dart) MUST be deleted.
- **Req 2.2.2**: The references to `GeminiService` in [transaction_provider.dart](file:///c:/Codingg/duasaku_app/lib/features/transactions/providers/transaction_provider.dart) (including the `_geminiService` field, watcher injection in `build()`, and the `parseReceipt` method) MUST be removed or refactored out.
- **Req 2.2.3**: Remove `google_generative_ai` dependency from `pubspec.yaml` as it is no longer utilized.
- **Req 2.2.4**: Remove Gemini API key storage fields from [env.dart](file:///c:/Codingg/duasaku_app/lib/core/config/env.dart) (`geminiApiKey`, `setGeminiApiKey()`, and any user API key storage keys).

---

## 3. Mobile Audit & UX Remediations

### 3.1 Touch Targets
- **Req 3.1.1**: Touch targets in [main.dart](file:///c:/Codingg/duasaku_app/lib/main.dart) (e.g. `ElevatedButton` for NTP recheck) MUST meet the minimum height of 48dp on Android and 44pt on iOS. Use `minimumSize` or padding adjustment.
- **Req 3.1.2**: In [home_screen.dart](file:///c:/Codingg/duasaku_app/lib/features/transactions/presentation/screens/home_screen.dart) and [profile_screen.dart](file:///c:/Codingg/duasaku_app/lib/features/profile/presentation/screens/profile_screen.dart), review touchable elements (buttons, switches, toggles) to ensure active tap targets have minimum dimensions of 48dp / 44pt.

### 3.2 Haptic Feedback
- **Req 3.2.1**: Incorporate `HapticFeedback.lightImpact()` or `HapticFeedback.mediumImpact()` into primary transaction flows:
  - When saving a manual transaction in the transaction bottom sheet.
  - When a transfer is successfully created.
  - When a saving goal target is completed or updated.

### 3.3 Dynamic Dark Mode Theme
- **Req 3.3.1**: Eliminate hardcoded color hex values inside widgets.
- **Req 3.3.2**: Ensure all elements dynamically resolve color via `Theme.of(context).colorScheme` (such as `surface`, `onSurface`, `primary`, `error`).
