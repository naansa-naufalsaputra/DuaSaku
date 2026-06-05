/// Abstract interface for profile data operations.
/// Follows the dependency inversion principle — presentation and provider layers
/// depend on this abstraction rather than a concrete ProfileRepository.
///
/// Note: The profile feature currently delegates to other repositories
/// (auth, gamification, backup). This interface serves as a placeholder
/// for future profile-specific data operations.
abstract class ProfileRepositoryInterface {
  // Reserved for future profile-specific data operations.
  // Currently, profile data is sourced from AuthRepository, GamificationNotifier,
  // and BackupService providers.
}
