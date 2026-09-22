import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/core_providers.dart';

part 'auth_controller.g.dart';

/// Raw Supabase auth state stream (session restore, sign-in, sign-out,
/// token refresh). `profiles` auto-creates server-side via the
/// `handle_new_user` trigger on sign-up — nothing to do here beyond
/// forwarding auth events.
@riverpod
Stream<AuthState> authStateChanges(Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
}

/// The signed-in user, or null. Falls back to `auth.currentUser` so the
/// very first frame (before onAuthStateChange has emitted) still reflects
/// a restored session instead of flashing "signed out".
@riverpod
User? currentUser(Ref ref) {
  final AsyncValue<AuthState> state = ref.watch(authStateChangesProvider);
  return state.value?.session?.user ??
      ref.watch(supabaseClientProvider).auth.currentUser;
}

@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {}

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() async {
      await ref
          .read(supabaseClientProvider)
          .auth
          .signInWithPassword(email: email, password: password);
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() async {
      await ref
          .read(supabaseClientProvider)
          .auth
          .signUp(
            email: email,
            password: password,
            data: displayName == null ? null : <String, String>{
              'display_name': displayName,
            },
          );
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() async {
      await ref.read(supabaseClientProvider).auth.signOut();
    });
  }
}
