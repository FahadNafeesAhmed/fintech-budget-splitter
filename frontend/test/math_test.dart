import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  group('BudgetCalculator', () {
    test('splits \$10.00 by 3 people and returns exactly \$3.33', () {
      const transaction = Transaction(
        totalAmount: 10.00,
        numberOfPeople: 3,
        description: 'Dinner',
      );

      final result = BudgetCalculator.calculate(transaction);

      // This will FAIL with naive division: 10.0 / 3 = 3.3333333...
      // The fix: round to 2 decimal places using (x * 100).round() / 100
      expect(result.amountPerPerson, equals(3.33));
    });

    test('splits \$100.00 by 4 people and returns exactly \$25.00', () {
      const transaction = Transaction(
        totalAmount: 100.00,
        numberOfPeople: 4,
      );

      final result = BudgetCalculator.calculate(transaction);

      expect(result.amountPerPerson, equals(25.00));
    });

    test('throws when numberOfPeople is zero', () {
      const transaction = Transaction(
        totalAmount: 50.00,
        numberOfPeople: 0,
      );

      expect(() => BudgetCalculator.calculate(transaction), throwsArgumentError);
    });

    test('throws when totalAmount is negative', () {
      const transaction = Transaction(
        totalAmount: -10.00,
        numberOfPeople: 2,
      );

      expect(() => BudgetCalculator.calculate(transaction), throwsArgumentError);
    });

    test('splits \$0.00 by 2 people and returns \$0.00', () {
      const transaction = Transaction(
        totalAmount: 0.00,
        numberOfPeople: 2,
      );

      final result = BudgetCalculator.calculate(transaction);

      expect(result.amountPerPerson, equals(0.00));
    });
  });
}
