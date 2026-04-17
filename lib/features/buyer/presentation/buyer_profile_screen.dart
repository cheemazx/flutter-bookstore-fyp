import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/user_repository.dart';

class BuyerProfileScreen extends ConsumerWidget {
  const BuyerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: user.profileImage.isNotEmpty ? NetworkImage(user.profileImage) : null,
                  child: user.profileImage.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                ),
                const SizedBox(height: 16),
                 Text(
                  user.name.isNotEmpty ? user.name : 'No Name Set',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                ),
                 const SizedBox(height: 32),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Edit Profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/edit-profile');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: const Text('Order History'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/order-history');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('My Wallet'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/buyer-wallet');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                     context.push('/buyer-settings');
                  },
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Logout', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
