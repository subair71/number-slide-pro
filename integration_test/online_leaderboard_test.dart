import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:number_slide_pro/leaderboard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android signs in and reads the live board from the server', (_) async {
    await Firebase.initializeApp();
    const expectedProject = String.fromEnvironment('TEST_FIREBASE_PROJECT');
    expect(expectedProject, isNotEmpty);
    expect(Firebase.app().options.projectId, expectedProject);
    // This smoke test runs only on a fresh CI emulator.
    expect(FirebaseAuth.instance.currentUser, isNull);

    final leaderboard = Leaderboard();
    final user = await leaderboard.connect();
    try {
      expect(user.isAnonymous, isTrue);
      expect((await leaderboard.connect()).uid, user.uid);
      final server = await leaderboard.top(4).firstWhere((snapshot) => !snapshot.metadata.isFromCache)
          .timeout(const Duration(seconds: 60));
      expect(server.docs.length, lessThanOrEqualTo(50));
      for (final entry in server.docs) {
        expect(entry.data()['size'], 4);
      }
      // Exercise the authenticated server read even when the leaderboard is empty.
      await FirebaseFirestore.instance.collection('leaderboard').doc('${user.uid}_4')
          .get(const GetOptions(source: Source.server));
    } finally {
      await user.delete();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
