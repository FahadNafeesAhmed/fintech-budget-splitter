import 'transaction_model.dart';

class BudgetCalculator {
  // NOTE: Intentionally naive — does NOT round to 2 decimal places.
  // This will cause the unit test expecting $3.33 to fail with 3.3333333...
  static SplitResult calculate(Transaction transaction) {
    if (transaction.numberOfPeople <= 0) {
      throw ArgumentError('Number of people must be greater than zero.');
    }
    if (transaction.totalAmount < 0) {
      throw ArgumentError('Total amount cannot be negative.');
    }

    final amountPerPerson =
        transaction.totalAmount / transaction.numberOfPeople;

    return SplitResult(
      amountPerPerson: amountPerPerson,
      totalAmount: transaction.totalAmount,
      numberOfPeople: transaction.numberOfPeople,
    );
  }
}
