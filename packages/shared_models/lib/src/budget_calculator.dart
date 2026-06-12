import 'transaction_model.dart';

class BudgetCalculator {
  static SplitResult calculate(Transaction transaction) {
    if (transaction.numberOfPeople <= 0) {
      throw ArgumentError('Number of people must be greater than zero.');
    }
    if (transaction.totalAmount < 0) {
      throw ArgumentError('Total amount cannot be negative.');
    }

    final raw = transaction.totalAmount / transaction.numberOfPeople;
    final amountPerPerson = (raw * 100).round() / 100;

    return SplitResult(
      amountPerPerson: amountPerPerson,
      totalAmount: transaction.totalAmount,
      numberOfPeople: transaction.numberOfPeople,
    );
  }
}
