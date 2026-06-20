import 'gamification_models.dart';

/// Abstract interface for gamification operations.
/// Follows the dependency inversion principle — presentation and provider layers
/// depend on this abstraction rather than the concrete GamificationNotifier.
abstract class GamificationServiceInterface {
  /// Returns the current gamification state (health score, streak, badges, etc.).
  GamificationState get currentState;

  /// Logs a daily activity to maintain or increment the user's streak.
  Future<void> logDailyActivity();
}
