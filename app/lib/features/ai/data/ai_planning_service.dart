import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException, FunctionResponse, SupabaseClient;

import '../../../core/providers/core_providers.dart';

/// Client for the `ai-plan` Edge Function (Groq behind the scenes — the key
/// never reaches this app). The service only transports data; context is
/// built by the caller from LOCAL records, and nothing is applied without
/// the user's explicit approval in the UI.
class AiPlanningService {
  AiPlanningService(this._client);

  final SupabaseClient _client;

  Future<AiPlanResult> propose({
    required String mode,
    required Map<String, dynamic> context,
  }) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'ai-plan',
        body: <String, dynamic>{'mode': mode, 'context': context},
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final Map<String, dynamic>? proposal =
          (data['proposal'] as Map?)?.cast<String, dynamic>();
      if (proposal == null) {
        return AiPlanResult.error('The assistant returned no proposal.');
      }
      return AiPlanResult.ok(proposal);
    } on FunctionException catch (error) {
      if (error.status == 503) {
        return AiPlanResult.error(
          'AI planning is not configured yet. Add a GROQ_API_KEY to the '
          'backend to enable it.',
          notConfigured: true,
        );
      }
      return AiPlanResult.error(
        'The planning assistant is unavailable (HTTP ${error.status}).',
      );
    } on Object {
      return AiPlanResult.error(
        'Could not reach the planning assistant. Are you online?',
      );
    }
  }
}

class AiPlanResult {
  const AiPlanResult._(this.proposal, this.errorMessage, this.notConfigured);

  factory AiPlanResult.ok(Map<String, dynamic> proposal) =>
      AiPlanResult._(proposal, null, false);

  factory AiPlanResult.error(String message, {bool notConfigured = false}) =>
      AiPlanResult._(null, message, notConfigured);

  final Map<String, dynamic>? proposal;
  final String? errorMessage;
  final bool notConfigured;

  bool get isOk => proposal != null;
}

final Provider<AiPlanningService> aiPlanningServiceProvider =
    Provider<AiPlanningService>((Ref ref) {
  return AiPlanningService(ref.watch(supabaseClientProvider));
});
