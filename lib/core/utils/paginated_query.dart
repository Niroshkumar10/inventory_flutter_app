import 'package:cloud_firestore/cloud_firestore.dart';

const int kDefaultPageSize = 20;

/// Holds one page of results plus the cursor for the next page.
class PaginatedResult<T> {
  final List<T> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const PaginatedResult({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
  });
}

/// Builds a Firestore query for the next page starting after [lastDocument].
Query<Object?> applyPagination(
  Query<Object?> base, {
  required int pageSize,
  DocumentSnapshot? lastDocument,
}) {
  Query<Object?> q = base.limit(pageSize);
  if (lastDocument != null) {
    q = q.startAfterDocument(lastDocument);
  }
  return q;
}
