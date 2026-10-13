import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/auth/data/datasources/auth_local.dart';
import 'package:kommerze_mobile/features/collections/data/repositories/collections_repository.dart';
import 'package:kommerze_mobile/features/loans/data/datasources/loans_local_data_source.dart';
import 'package:kommerze_mobile/features/loans/data/datasources/loans_remote_data_source.dart';
import 'package:kommerze_mobile/features/loans/data/models/loan_sync_batch.dart';
import 'package:kommerze_mobile/features/loans/domain/entities/customer_loan.dart';

class LoansRepository {
  final LoansLocalDataSource local;
  final LoansRemoteDataSource remote;
  final CollectionsRepository collectionsRepository;
  final AuthLocal authLocal;

  const LoansRepository(
    this.local,
    this.remote,
    this.collectionsRepository,
    this.authLocal,
  );

  Future<List<CustomerLoan>> getAll() async {
    await _trySyncPending();
    return local.getAll();
  }

  Future<CustomerLoan> create(CustomerLoanDraft draft) async {
    final user = authLocal.readUser();
    if (user == null) {
      throw const LoansLocalException(
        'No fue posible identificar al usuario de la sesión.',
      );
    }
    final loan = await local.create(
      draft,
      userGuid: user.userGuid.isNotEmpty ? user.userGuid : user.id,
      userName: user.name,
    );
    await _trySyncPending();
    return loan;
  }

  Future<LoansSyncReport> syncPending() async {
    var pending = 0;
    var synchronized = 0;

    final loanBatch = await local.getPendingSyncBatch(
      includeApplications: false,
    );
    pending += loanBatch.length;
    if (!loanBatch.isEmpty) {
      final result = await remote.synchronize(loanBatch);
      await local.markSyncCompleted(result);
      synchronized += result.length;
    }

    // Las aplicaciones de préstamo referencian cobros; éstos deben existir
    // primero en Cloud junto con el detalle de sus formas de pago.
    await collectionsRepository.syncPending();

    final applicationBatch = await local.getPendingSyncBatch(
      includeLoans: false,
    );
    pending += applicationBatch.length;
    if (!applicationBatch.isEmpty) {
      final result = await remote.synchronize(applicationBatch);
      await local.markSyncCompleted(result);
      synchronized += result.length;
    }
    return LoansSyncReport(pending: pending, synchronized: synchronized);
  }

  Future<LoansRecoveryResult> recoverByActiveBranch() async {
    try {
      await syncPending();
    } catch (_) {
      // El merge conserva cualquier fila local que todavía tenga sync = 0.
    }
    try {
      await collectionsRepository.recoverByActiveBranch();
    } catch (_) {
      // Un cobro ya local basta para resolver las aplicaciones recuperadas.
    }
    final branchGuid = await local.getBranchGuid();
    final snapshot = await remote.recoverByBranch(branchGuid);
    return local.mergeCloudSnapshot(snapshot);
  }

  Future<void> _trySyncPending() async {
    try {
      await syncPending();
    } catch (_) {
      // Offline-first: los registros permanecen con sync = 0.
    }
  }
}

class LoansSyncReport {
  final int pending;
  final int synchronized;

  const LoansSyncReport({required this.pending, required this.synchronized});
}

final loansRepositoryProvider = Provider<LoansRepository>((ref) {
  return LoansRepository(
    ref.read(loansLocalDataSourceProvider),
    ref.watch(loansRemoteDataSourceProvider),
    ref.read(collectionsRepositoryProvider),
    ref.read(authLocalProvider),
  );
});
