# Design: Gemini Decommissioning & Mobile Audit Fixes

## 1. Decommissioning Architecture

Removing Gemini simplifies the app's external integrations, making all transaction parsing 100% local and offline.

### 1.1 Deletion Plan
The following files and directories will be deleted completely:
- `lib/services/gemini_service.dart`
- `lib/features/ai_chat/` (directory containing `presentation/screens/ai_chat_screen.dart`, `providers/ai_chat_provider.dart`, `services/ai_client_service.dart`)

### 1.2 Class and File Updates

```
[Before]
  TransactionNotifier -> Watcher(geminiServiceProvider)
  ProfileScreen       -> Dialog(_showGeminiKeyDialog) + UI(ai_settings)
  HomeScreen          -> OCR Button (_scanReceipt)
  AppRouter           -> Route(/ai-chat)

[After]
  TransactionNotifier -> No Gemini references
  ProfileScreen       -> Removed Gemini API key tile & dialog
  HomeScreen          -> Removed OCR scanner button
  AppRouter           -> Removed /ai-chat route
```

#### `lib/services/service_providers.dart`
- Remove: `geminiServiceProvider` definition.
- Remove: `import 'gemini_service.dart';`.

#### `lib/features/transactions/providers/transaction_provider.dart`
- Remove: `import '../../../services/gemini_service.dart';`.
- Remove: `late GeminiService _geminiService;` field inside `TransactionNotifier`.
- Remove: `_geminiService = ref.watch(geminiServiceProvider);` line in `build()`.
- Remove: `parseReceipt(String base64Image, String mimeType)` method.

#### `lib/features/transactions/presentation/screens/home_screen.dart`
- Remove: OCR Button UI widget block (lines 574-606).
- Remove: `_scanReceipt()` method (lines 112-141).
- Remove: `import 'package:image_picker/image_picker.dart';` (if no longer used elsewhere in this screen).

#### `lib/features/profile/presentation/screens/profile_screen.dart`
- Remove: `_showGeminiKeyDialog()` method.
- Remove: "AI & Gemini Settings" group label and GlassCard tile block.

#### `lib/core/config/env.dart`
- Remove: `user_gemini_api_key` load logic.
- Remove: `geminiApiKey` static getter.
- Remove: `setGeminiApiKey` static method.

#### `lib/core/routing/app_router.dart`
- Remove: `/ai-chat` GoRoute.
- Remove: `import '../../features/ai_chat/presentation/screens/ai_chat_screen.dart';`.

---

## 2. Touch Target & UX Audit Remediations

### 2.1 Touch Target Adjustments
- **NTP Recheck Button in `main.dart`**:
  Update `ElevatedButton` style to specify `minimumSize: const Size(120, 48)` to guarantee 48dp height on Android and 44pt on iOS.
- **IconButton / Toggle Swappage**:
  Review switch controls and toggles. Ensure they have appropriate container bounds.

### 2.2 Haptic Feedback Implementation
- Import `import 'package:flutter/services.dart';` where required.
- Add `HapticFeedback.lightImpact()` or `HapticFeedback.mediumImpact()` in:
  - Transaction creation callback.
  - Transfer creation callback.
  - Savings goal completion/actions.
