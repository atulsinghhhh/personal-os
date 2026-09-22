/// Central table of every route path in the app. Feature code should
/// navigate via these constants (`context.go(RoutePaths.today)`) rather
/// than hand-typed strings, so a path rename is a one-line change.
abstract final class RoutePaths {
  static const String splash = '/splash';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String onboarding = '/onboarding';

  static const String today = '/today';
  static const String plan = '/plan';
  static const String future = '/future';
  static const String money = '/money';
  static const String review = '/review';
}
