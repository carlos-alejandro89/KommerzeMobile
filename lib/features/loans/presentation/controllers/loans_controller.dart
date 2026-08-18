import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/loans/data/repositories/loans_repository.dart';
import 'package:kommerze_mobile/features/loans/domain/entities/customer_loan.dart';

final loansProvider = FutureProvider<List<CustomerLoan>>((ref) {
  return ref.read(loansRepositoryProvider).getAll();
});
