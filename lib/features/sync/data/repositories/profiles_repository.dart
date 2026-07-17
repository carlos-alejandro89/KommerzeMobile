import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/sync/data/datasources/profiles_api.dart';
import 'package:kommerze_mobile/features/sync/data/datasources/profiles_local_data_source.dart';

class ProfilesSyncResult {
  final int records;
  final DateTime synchronizedAt;
  const ProfilesSyncResult({
    required this.records,
    required this.synchronizedAt,
  });
}

class ProfilesLocalStatus {
  final int records;
  final DateTime? synchronizedAt;
  const ProfilesLocalStatus({
    required this.records,
    required this.synchronizedAt,
  });
}

class ProfilesRepository {
  final ProfilesApi api;
  final ProfilesLocalDataSource local;
  const ProfilesRepository(this.api, this.local);

  Future<ProfilesSyncResult> synchronize() async {
    final items = await api.getAll();
    final now = DateTime.now();
    await local.replaceAll(items, now);
    return ProfilesSyncResult(records: items.length, synchronizedAt: now);
  }

  Future<ProfilesLocalStatus> localStatus() async => ProfilesLocalStatus(
    records: await local.count(),
    synchronizedAt: await local.lastSynchronization(),
  );
}

final profilesRepositoryProvider = Provider<ProfilesRepository>(
  (ref) => ProfilesRepository(
    ref.read(profilesApiProvider),
    ref.read(profilesLocalDataSourceProvider),
  ),
);
