import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import 'alert_center_provider.dart';

// ─── Unread Badge Count Stream Provider ───────────────────────────────────────

/// Watches the unread alert count for the current user as a reactive stream.
///
/// Returns 0 if no user is logged in.
/// Auto-disposes when no longer watched (e.g., badge widget not visible).
final unreadBadgeCountProvider = StreamProvider.autoDispose<int>((ref) {
  final user = ref.watch(userProvider);
  if (user == null) return Stream.value(0);
  final repo = ref.watch(alertRepositoryProvider);
  return repo.watchUnreadCount(user.id);
});
