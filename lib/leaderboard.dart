import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class Leaderboard {
  Future<User>? _signIn;
  bool _emulatorsConnected = false;

  Future<User> connect() => _signIn ??= _connect().whenComplete(() {
    _signIn = null;
  });

  Future<User> _connect() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    final auth = FirebaseAuth.instance;
    if (const bool.fromEnvironment('FIREBASE_EMULATORS') && !_emulatorsConnected) {
      await auth.useAuthEmulator('10.0.2.2', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
      _emulatorsConnected = true;
    }
    final existing = auth.currentUser;
    if (existing != null) return existing;
    final credential = await auth.signInAnonymously();
    return credential.user!;
  }

  Future<void> submitBest(int size, int score) async {
    final player = await connect();
    if (score <= 0) return;
    final db = FirebaseFirestore.instance;
    final entry = db.collection('leaderboard').doc('${player.uid}_$size');
    await db.runTransaction((transaction) async {
      final current = await transaction.get(entry);
      final previous = current.data()?['score'] as int? ?? 0;
      if (score <= previous) return;
      transaction.set(entry, {
        'uid': player.uid,
        'name': 'Player ${player.uid.substring(0, 6)}',
        'size': size,
        'score': score,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> top(int size) =>
      FirebaseFirestore.instance.collection('leaderboard')
          .where('size', isEqualTo: size)
          .orderBy('score', descending: true)
          .limit(50)
          .snapshots();
}
