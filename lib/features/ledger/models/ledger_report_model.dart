import 'package:flutter/material.dart';
import 'ledger_model.dart';

class LedgerReport {
  final String userMobile;
  final DateTime startDate;
  final DateTime endDate;
  final List<LedgerEntry> entries;
  final Map<String, double> summary;

  LedgerReport({
    required this.userMobile,
    required this.startDate,
    required this.endDate,
    required this.entries,
    required this.summary,
  });

  // Getters for summary
  double get totalDebit => summary['totalDebit'] ?? 0;
  double get totalCredit => summary['totalCredit'] ?? 0;
  double get netBalance => summary['netBalance'] ?? 0;

  // Helper methods
  Map<String, dynamic> toJson() {
    return {
      'userMobile': userMobile,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'entries': entries.map((e) => e.toMap()).toList(),
      'summary': summary,
    };
  }
}