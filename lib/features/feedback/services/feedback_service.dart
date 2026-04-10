import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/feedback_model.dart';

class FeedbackService {
  final String userMobile;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FeedbackService(this.userMobile);

  // Get feedback collection reference for this user
  CollectionReference get _feedbackCollection {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('feedback');
  }

  // Add new feedback
  Future<String> addFeedback(FeedbackItem feedback) async {
    try {
      final docRef = await _feedbackCollection.add(feedback.toMap());
      return docRef.id;
    } catch (e) {
      print('❌ Error adding feedback: $e');
      throw Exception('Failed to add feedback: $e');
    }
  }

  // Update feedback status
  Future<void> updateFeedbackStatus(String id, FeedbackStatus status) async {
    try {
      await _feedbackCollection.doc(id).update({
        'status': status.index,
        'statusString': status == FeedbackStatus.resolved 
            ? 'Resolved' 
            : (status == FeedbackStatus.reviewed ? 'Reviewed' : 'Pending'),
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating feedback status: $e');
      throw Exception('Failed to update feedback status: $e');
    }
  }

  // Add response to feedback
  Future<void> addResponse(String id, String response) async {
    try {
      await _feedbackCollection.doc(id).update({
        'response': response,
        'status': FeedbackStatus.resolved.index,
        'statusString': 'Resolved',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error adding response: $e');
      throw Exception('Failed to add response: $e');
    }
  }

  // Get all feedback for this user
  // Stream<List<FeedbackItem>> getFeedback() {
  //   return _feedbackCollection
  //       .orderBy('createdAt', descending: true)
  //       .snapshots()
  //       .map((snapshot) {
  //     return snapshot.docs.map((doc) {
  //       return FeedbackItem.fromMap(
  //         doc.data() as Map<String, dynamic>,
  //         doc.id,
  //       );
  //     }).toList();
  //   });
  // }

  // Temporarily remove ordering to avoid index requirement
Stream<List<FeedbackItem>> getFeedback() {
  return _feedbackCollection
      // .orderBy('createdAt', descending: true) // Comment this temporarily
      .snapshots()
      .map((snapshot) {
    final items = snapshot.docs.map((doc) {
      return FeedbackItem.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    }).toList();
    
    // Sort manually in code
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  });
}

  // Get feedback by type
  Stream<List<FeedbackItem>> getFeedbackByType(FeedbackType type) {
    return _feedbackCollection
        .where('type', isEqualTo: type.index)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return FeedbackItem.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  // Get feedback by status
  Stream<List<FeedbackItem>> getFeedbackByStatus(FeedbackStatus status) {
    return _feedbackCollection
        .where('status', isEqualTo: status.index)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return FeedbackItem.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  // Get feedback stats
  Future<Map<String, int>> getFeedbackStats() async {
    try {
      final snapshot = await _feedbackCollection.get();
      final feedbacks = snapshot.docs.map((doc) {
        return FeedbackItem.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();

      return {
        'total': feedbacks.length,
        'pending': feedbacks.where((f) => f.status == FeedbackStatus.pending).length,
        'reviewed': feedbacks.where((f) => f.status == FeedbackStatus.reviewed).length,
        'resolved': feedbacks.where((f) => f.status == FeedbackStatus.resolved).length,
        'client': feedbacks.where((f) => f.type == FeedbackType.client).length,
        'supplier': feedbacks.where((f) => f.type == FeedbackType.supplier).length,
        'avgRating': feedbacks.isEmpty ? 0 : (feedbacks.map((f) => f.rating).reduce((a, b) => a + b) / feedbacks.length).round(),
      };
    } catch (e) {
      print('❌ Error getting feedback stats: $e');
      return {
        'total': 0,
        'pending': 0,
        'reviewed': 0,
        'resolved': 0,
        'client': 0,
        'supplier': 0,
        'avgRating': 0,
      };
    }
  }

  // Delete feedback
  Future<void> deleteFeedback(String id) async {
    try {
      await _feedbackCollection.doc(id).delete();
    } catch (e) {
      print('❌ Error deleting feedback: $e');
      throw Exception('Failed to delete feedback: $e');
    }
  }
}