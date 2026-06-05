# Project Memory - DuaSaku Flutter

## Project Status & Vision
- **Project Name:** DuaSaku (Flutter Edition)
- **Framework:** Flutter (Dart)
- **Backend:** Supabase (PostgreSQL, RLS, Edge Functions, pg_cron)
- **AI Integration:** Gemini 1.5 Flash (via Supabase Edge Functions)
- **State Management:** Riverpod
- **Local Storage:** shared_preferences
- **Target Audience:** Students & Young Professionals (18-25 y/o)

## Key Technical Decisions
1. **Architecture:** Feature-first Clean Architecture (`lib/core/`, `lib/features/`, `lib/services/`).
2. **AI Integration:** Backend-only AI calls (via Edge Functions) to protect API Keys. AI used for transaction parsing, financial insights, and receipt scanning.
3. **Performance:** Enforcing 60/120 FPS using Impeller rendering.
4. **Caching Strategy:** 2-hour local caching for insights to save API quota.
5. **Offline Support:** App must remain usable and show cached data even without internet.

## User Context & Guidelines
- **UX Goal:** Casual, modern, and engaging (gamification via streak system).
- **Code Rules:** Strict Null Safety, use `flutter_riverpod` efficiently, avoid heavy client-side AI processing. All edge-functions are accessed via JWT.
