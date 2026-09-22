import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';

@freezed
abstract class Profile with _$Profile {
  const factory Profile({
    required String id,
    String? displayName,
    String? defaultCurrency,
    DateTime? onboardingCompletedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Profile;
}
