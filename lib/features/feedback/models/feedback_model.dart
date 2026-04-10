import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';  // ✅ Add this import for Colors, IconData, Icons

enum FeedbackType {
  client,
  supplier,
}

enum FeedbackStatus {
  pending,
  reviewed,
  resolved,
  archived,
}

class FeedbackItem {
  final String id;
  final String userMobile;
  final FeedbackType type;
  final String name;
  final String? mobile;
  final String? email;
  final String message;
  final int rating;
  final FeedbackStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? response;
  final List<String>? tags;
  final bool isAnonymous;

  FeedbackItem({
    required this.id,
    required this.userMobile,
    required this.type,
    required this.name,
    this.mobile,
    this.email,
    required this.message,
    required this.rating,
    this.status = FeedbackStatus.pending,
    required this.createdAt,
    this.respondedAt,
    this.response,
    this.tags,
    this.isAnonymous = false,
  });

  // Helper getters
  String get typeString => type == FeedbackType.client ? 'Client' : 'Supplier';
  String get statusString {
    switch (status) {
      case FeedbackStatus.pending:
        return 'Pending';
      case FeedbackStatus.reviewed:
        return 'Reviewed';
      case FeedbackStatus.resolved:
        return 'Resolved';
      case FeedbackStatus.archived:
        return 'Archived';
    }
  }

  Color get statusColor {
    switch (status) {
      case FeedbackStatus.pending:
        return Colors.orange;
      case FeedbackStatus.reviewed:
        return Colors.blue;
      case FeedbackStatus.resolved:
        return Colors.green;
      case FeedbackStatus.archived:
        return Colors.grey;
    }
  }

  IconData get ratingIcon {
    if (rating >= 4) return Icons.sentiment_very_satisfied;
    if (rating >= 3) return Icons.sentiment_satisfied;
    if (rating >= 2) return Icons.sentiment_dissatisfied;
    return Icons.sentiment_very_dissatisfied;
  }

  Color get ratingColor {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }

  Map<String, dynamic> toMap() {
    return {
      'userMobile': userMobile,
      'type': type.index,
      'typeString': typeString,
      'name': name,
      'mobile': mobile,
      'email': email,
      'message': message,
      'rating': rating,
      'status': status.index,
      'statusString': statusString,
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'response': response,
      'tags': tags,
      'isAnonymous': isAnonymous,
    };
  }

  static FeedbackItem fromMap(Map<String, dynamic> map, String id) {
    return FeedbackItem(
      id: id,
      userMobile: map['userMobile'] ?? '',
      type: FeedbackType.values[map['type'] ?? 0],
      name: map['name'] ?? '',
      mobile: map['mobile'],
      email: map['email'],
      message: map['message'] ?? '',
      rating: map['rating'] ?? 0,
      status: FeedbackStatus.values[map['status'] ?? 0],
      createdAt: _parseDate(map['createdAt']),
      respondedAt: map['respondedAt'] != null ? _parseDate(map['respondedAt']) : null,
      response: map['response'],
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      isAnonymous: map['isAnonymous'] ?? false,
    );
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is Timestamp) return date.toDate();
    if (date is DateTime) return date;
    return DateTime.now();
  }

  FeedbackItem copyWith({
    String? id,
    String? userMobile,
    FeedbackType? type,
    String? name,
    String? mobile,
    String? email,
    String? message,
    int? rating,
    FeedbackStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? response,
    List<String>? tags,
    bool? isAnonymous,
  }) {
    return FeedbackItem(
      id: id ?? this.id,
      userMobile: userMobile ?? this.userMobile,
      type: type ?? this.type,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      message: message ?? this.message,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      response: response ?? this.response,
      tags: tags ?? this.tags,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }
}