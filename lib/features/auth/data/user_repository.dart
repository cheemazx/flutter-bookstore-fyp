import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/core/models/user_model.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';

class UserRepository {
  final SupabaseClient _supabase;

  UserRepository(this._supabase);

  Future<void> saveUser(UserModel user) async {
    await _supabase.from('users').upsert(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final response = await _supabase.from('users').select().eq('id', uid).maybeSingle();
    if (response != null) {
      return UserModel.fromMap(response);
    }
    return null;
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(Supabase.instance.client);
});

final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return Supabase.instance.client
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', user.id)
          .map((data) => data.isNotEmpty ? UserModel.fromMap(data.first) : null);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});
