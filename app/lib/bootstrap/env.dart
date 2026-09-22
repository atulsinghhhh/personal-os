/// Reads Supabase connection details injected at build time via
/// `--dart-define-from-file=env/local.json`. No secrets are bundled into
/// source control; env/local.json is gitignored.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
