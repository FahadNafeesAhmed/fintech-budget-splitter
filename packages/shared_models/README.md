# shared_models

Standalone Dart package containing all shared business logic and data models used by both the frontend and backend.

## Contents

| File | Purpose |
|------|---------|
| `lib/src/transaction_model.dart` | `Transaction` and `SplitResult` DTOs with JSON serialization |
| `lib/src/budget_calculator.dart` | Math logic — **intentionally uses naive division (bug)** |

## The Bug

```dart
// Current (broken): returns 3.3333... for $10 / 3 people
final amountPerPerson = transaction.totalAmount / transaction.numberOfPeople;

// Fix: round to 2 decimal places
final amountPerPerson = (transaction.totalAmount / transaction.numberOfPeople * 100).round() / 100;
```

## Usage

```dart
import 'package:shared_models/shared_models.dart';

final result = BudgetCalculator.calculate(
  Transaction(totalAmount: 90.00, numberOfPeople: 3),
);
print(result.amountPerPerson); // 30.0
```
