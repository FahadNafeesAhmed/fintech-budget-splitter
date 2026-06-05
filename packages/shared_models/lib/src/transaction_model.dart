class Transaction {
  const Transaction({
    required this.totalAmount,
    required this.numberOfPeople,
    this.description = '',
  });

  final double totalAmount;
  final int numberOfPeople;
  final String description;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      totalAmount: (json['total_amount'] as num).toDouble(),
      numberOfPeople: json['number_of_people'] as int,
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'total_amount': totalAmount,
        'number_of_people': numberOfPeople,
        'description': description,
      };
}

class SplitResult {
  const SplitResult({
    required this.amountPerPerson,
    required this.totalAmount,
    required this.numberOfPeople,
  });

  final double amountPerPerson;
  final double totalAmount;
  final int numberOfPeople;

  factory SplitResult.fromJson(Map<String, dynamic> json) {
    return SplitResult(
      amountPerPerson: (json['amount_per_person'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      numberOfPeople: json['number_of_people'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'amount_per_person': amountPerPerson,
        'total_amount': totalAmount,
        'number_of_people': numberOfPeople,
      };
}
