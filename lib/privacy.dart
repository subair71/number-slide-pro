import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key, required this.policy});
  final String policy;

  static Future<void> open(BuildContext context) async {
    final text = await rootBundle.loadString('assets/privacy_policy.txt');
    if (!context.mounted) return;
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => PrivacyPage(policy: text)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(appBar: AppBar(title: const Text('Privacy & data')), body: SafeArea(child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FilledButton.icon(
          onPressed: uid == null ? null : () async {
            await Clipboard.setData(ClipboardData(text: uid));
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player ID copied')));
          },
          icon: const Icon(Icons.copy), label: Text(uid == null ? 'No signed-in player' : 'Copy my player ID'),
        ),
        const SizedBox(height: 18),
        SelectableText(policy, style: const TextStyle(height: 1.45, fontSize: 15)),
      ],
    )));
  }
}
