import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/sync/data/datasources/users_api.dart';
import 'package:kommerze_mobile/features/sync/data/datasources/users_local_data_source.dart';

class UsersSyncResult {
  final int records;
  final DateTime synchronizedAt;
  const UsersSyncResult({required this.records, required this.synchronizedAt});
}

class UsersLocalStatus {
  final int records;
  final DateTime? synchronizedAt;
  const UsersLocalStatus({required this.records, required this.synchronizedAt});
}

class UsersRepository {
  final UsersApi api;
  final UsersLocalDataSource local;
  const UsersRepository(this.api, this.local);

  Future<UsersSyncResult> synchronize() async {
    final users = await api.getAll();
    final now = DateTime.now();
    await local.replaceAll(users, now);
    return UsersSyncResult(records: users.length, synchronizedAt: now);
  }

  Future<UsersLocalStatus> localStatus() async => UsersLocalStatus(
    records: await local.count(),
    synchronizedAt: await local.lastSynchronization(),
  );
}

final usersRepositoryProvider = Provider<UsersRepository>(
  (ref) => UsersRepository(
    ref.read(usersApiProvider),
    ref.read(usersLocalDataSourceProvider),
  ),
);
