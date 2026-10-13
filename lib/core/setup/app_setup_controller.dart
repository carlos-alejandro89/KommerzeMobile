import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/shared_prefs_provider.dart';

class AppSetupState {
  final String baseUrl;
  final bool onboardingComplete;
  final bool initialSyncComplete;

  const AppSetupState({
    required this.baseUrl,
    required this.onboardingComplete,
    required this.initialSyncComplete,
  });

  AppSetupState copyWith({
    String? baseUrl,
    bool? onboardingComplete,
    bool? initialSyncComplete,
  }) => AppSetupState(
    baseUrl: baseUrl ?? this.baseUrl,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    initialSyncComplete: initialSyncComplete ?? this.initialSyncComplete,
  );
}

class AppSetupController extends Notifier<AppSetupState> {
  static const _baseUrlKey = 'api_base_url';
  static const _onboardingKey = 'onboarding_complete';
  static const _initialSyncKey = 'initial_catalog_sync_complete';

  @override
  AppSetupState build() {
    final preferences = ref.read(sharedPrefsProvider);
    final baseUrl = preferences.getString(_baseUrlKey) ?? '';
    return AppSetupState(
      baseUrl: baseUrl,
      onboardingComplete:
          baseUrl.isNotEmpty && (preferences.getBool(_onboardingKey) ?? false),
      initialSyncComplete: preferences.getBool(_initialSyncKey) ?? false,
    );
  }

  Future<void> saveBaseUrl(String value) async {
    final normalized = normalizeBaseUrl(value);
    final changed = normalized != state.baseUrl;
    final preferences = ref.read(sharedPrefsProvider);
    await preferences.setString(_baseUrlKey, normalized);
    if (changed) await preferences.setBool(_initialSyncKey, false);
    state = state.copyWith(
      baseUrl: normalized,
      initialSyncComplete: changed ? false : state.initialSyncComplete,
    );
  }

  Future<void> completeOnboarding() async {
    await ref.read(sharedPrefsProvider).setBool(_onboardingKey, true);
    state = state.copyWith(onboardingComplete: true);
  }

  Future<void> completeInitialSync() async {
    await ref.read(sharedPrefsProvider).setBool(_initialSyncKey, true);
    state = state.copyWith(initialSyncComplete: true);
  }

  static String normalizeBaseUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.toLowerCase().endsWith('/pulse')) {
      normalized = normalized.substring(0, normalized.length - '/pulse'.length);
    }
    return normalized;
  }
}

final appSetupControllerProvider =
    NotifierProvider<AppSetupController, AppSetupState>(AppSetupController.new);
