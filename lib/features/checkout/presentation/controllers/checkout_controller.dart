import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/checkout/domain/entities/sale_payment.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';
import 'package:uuid/uuid.dart';

class CheckoutState {
  final Client? client;
  final List<SalePayment> payments;
  final bool isSubmitting;

  const CheckoutState({
    this.client,
    this.payments = const [],
    this.isSubmitting = false,
  });

  double get paid => payments.fold(0, (sum, payment) => sum + payment.amount);

  CheckoutState copyWith({
    Client? client,
    bool clearClient = false,
    List<SalePayment>? payments,
    bool? isSubmitting,
  }) => CheckoutState(
    client: clearClient ? null : client ?? this.client,
    payments: payments ?? this.payments,
    isSubmitting: isSubmitting ?? this.isSubmitting,
  );
}

class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutState();

  void selectClient(Client client) => state = state.copyWith(client: client);

  void addPayment({
    required PaymentMethod method,
    required double amount,
    required String reference,
  }) {
    state = state.copyWith(
      payments: [
        ...state.payments,
        SalePayment(
          id: const Uuid().v4(),
          method: method,
          amount: amount,
          reference: reference.trim(),
          createdAt: DateTime.now(),
        ),
      ],
    );
  }

  void removePayment(String id) => state = state.copyWith(
    payments: state.payments
        .where((payment) => payment.id != id)
        .toList(growable: false),
  );
  void clearPayments() => state = state.copyWith(payments: const []);
  void setSubmitting(bool value) => state = state.copyWith(isSubmitting: value);
  void reset() => state = const CheckoutState();
}

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);
