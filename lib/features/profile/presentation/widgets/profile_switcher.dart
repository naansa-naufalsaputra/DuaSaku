import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/user_provider.dart';

/// Profile switcher bottom sheet
class ProfileSwitcher extends ConsumerWidget {
  const ProfileSwitcher({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const ProfileSwitcher(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final usersAsync = ref.watch(allUsersProvider);
    final activeUserId = ref.watch(activeUserIdProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'profile.switch_profile'.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Profiles list
          usersAsync.when(
            data: (users) {
              if (users.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'profile.no_profiles'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                );
              }

              return Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isActive = user.id == activeUserId;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: user.avatarPath != null
                            ? ClipOval(
                                child: Image.asset(
                                  user.avatarPath!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
                                user.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      title: Text(
                        user.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isActive ? FontWeight.bold : null,
                        ),
                      ),
                      subtitle: Text(user.email),
                      trailing: isActive
                          ? Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: isActive
                          ? null
                          : () async {
                              await ref
                                  .read(activeUserIdProvider.notifier)
                                  .switchUser(user.id);
                              if (context.mounted) {
                                Navigator.pop(context);
                                // Show snackbar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'profile.switched_to'.tr(
                                        args: [user.name],
                                      ),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                    );
                  },
                ),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'profile.error_loading_profiles'.tr(args: [error.toString()]),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),

          const Divider(),

          // Add new profile button
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(
                Icons.add,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(
              'profile.create_new_profile'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showCreateProfileDialog(context, ref);
            },
          ),
        ],
      ),
    );
  }

  void _showCreateProfileDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile.create_new_profile'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'profile.name'.tr(),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'profile.email'.tr(),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('profile.btn_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();

              if (name.isEmpty || email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('profile.please_fill_fields'.tr())),
                );
                return;
              }

              try {
                await ref
                    .read(userManagementProvider)
                    .createProfile(name: name, email: email);

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('profile.profile_created'.tr(args: [name])),
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'profile.error_prefix'.tr(args: [e.toString()]),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text('profile.btn_create'.tr()),
          ),
        ],
      ),
    );
  }
}
