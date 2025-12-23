import 'package:firebase_auth/firebase_auth.dart';

String getCurrentUserId() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception("User not logged in");
  }
  return user.uid;
}
