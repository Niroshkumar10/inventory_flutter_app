class Payment {
  final String id;
  final String partyId;
  final String partyType; // customer / supplier
  final double amount;
  final DateTime date;

  Payment({
    required this.id,
    required this.partyId,
    required this.partyType,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'partyId': partyId,
        'partyType': partyType,
        'amount': amount,
        'date': date,
      };

  factory Payment.fromMap(String id, Map<String, dynamic> map) {
    return Payment(
      id: id,
      partyId: map['partyId'],
      partyType: map['partyType'],
      amount: map['amount'],
      date: map['date'].toDate(),
    );
  }
}
