import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  bool online = false;
  try {
    await Firebase.initializeApp();
    await FirebaseAuth.instance.signInAnonymously();
    online = FirebaseAuth.instance.currentUser != null;
  } catch (e) {
    debugPrint('Firebase not configured: $e');
  }
  runApp(PuzzleApp(online: online));
}

class PuzzleApp extends StatelessWidget {
  final bool online;
  const PuzzleApp({super.key, required this.online});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: PuzzlePage(online: online),
  );
}

class PuzzlePage extends StatefulWidget {
  final bool online;
  const PuzzlePage({super.key, required this.online});
  @override
  State<PuzzlePage> createState() => _PuzzlePageState();
}

class _PuzzlePageState extends State<PuzzlePage> {
  static const rewardedTestId = 'ca-app-pub-3940256099942544/5224354917';
  int size = 4, moves = 0, coins = 0, best = 0;
  bool daily = false, sound = true, busy = false;
  List<int> board = [];
  RewardedAd? rewarded;
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();
    _init();
    _loadAd();
  }

  Future<void> _init() async {
    prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      coins = prefs!.getInt('coins') ?? 0;
      sound = prefs!.getBool('sound') ?? true;
      best = prefs!.getInt('best_$size') ?? 0;
    });
    _newGame();
  }

  void _newGame({bool isDaily = false}) {
    final rng = isDaily
        ? Random(int.parse(DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '')) + size)
        : Random();
    final tiles = List<int>.generate(size * size, (i) => (i + 1) % (size * size));
    int empty = tiles.length - 1;
    int previous = -1;
    for (int i = 0; i < size * size * 35; i++) {
      final row = empty ~/ size, col = empty % size;
      final choices = <int>[];
      if (row > 0) choices.add(empty - size);
      if (row < size - 1) choices.add(empty + size);
      if (col > 0) choices.add(empty - 1);
      if (col < size - 1) choices.add(empty + 1);
      if (choices.length > 1) choices.remove(previous);
      final next = choices[rng.nextInt(choices.length)];
      tiles[empty] = tiles[next];
      tiles[next] = 0;
      previous = empty;
      empty = next;
    }
    if (!mounted) return;
    setState(() {
      board = tiles;
      moves = 0;
      daily = isDaily;
      busy = false;
      best = prefs?.getInt('best_$size') ?? 0;
    });
  }

  void _tap(int index) {
    if (busy || board.isEmpty || board[index] == 0) return;
    final empty = board.indexOf(0);
    final adjacent = (index ~/ size == empty ~/ size && (index - empty).abs() == 1)
        || (index % size == empty % size && (index - empty).abs() == size);
    if (!adjacent) return;
    if (sound) SystemSound.play(SystemSoundType.click);
    setState(() {
      board[empty] = board[index];
      board[index] = 0;
      moves++;
    });
    if (List.generate(size * size, (i) => (i + 1) % (size * size))
        .asMap().entries.every((e) => board[e.key] == e.value)) {
      _won();
    }
  }

  Future<void> _won() async {
    if (busy) return;
    setState(() => busy = true);
    final score = max(1, size * size * 100 - moves * 5);
    final rewardKey = 'daily_${DateTime.now().toIso8601String().substring(0, 10)}_$size';
    final canReward = !daily || !(prefs?.getBool(rewardKey) ?? false);
    if (canReward) {
      coins += daily ? 100 : 20;
      await prefs?.setInt('coins', coins);
      if (daily) await prefs?.setBool(rewardKey, true);
    }
    if (score > best) {
      best = score;
      await prefs?.setInt('best_$size', best);
    }
    if (widget.online) {
      try {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance.collection('leaderboard').doc(uid).set({
          'name': 'Player ${uid.substring(0, 6)}',
          'score': score,
          'size': size,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Leaderboard write failed: $e');
      }
    }
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Puzzle solved! 🎉'),
      content: Text('Moves: $moves • Score: $score\n${canReward ? "Coins earned!" : "Daily reward already claimed."}'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continue'))],
    ));
    _newGame(isDaily: daily);
  }

  void _loadAd() {
    RewardedAd.load(
      adUnitId: rewardedTestId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          rewarded?.dispose();
          rewarded = ad;
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (error) => debugPrint('Rewarded ad: $error'),
      ),
    );
  }

  Future<void> _showAd() async {
    final ad = rewarded;
    if (ad == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad not available yet')));
      _loadAd();
      return;
    }
    rewarded = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) { ad.dispose(); _loadAd(); },
      onAdFailedToShowFullScreenContent: (ad, error) { ad.dispose(); _loadAd(); },
    );
    await ad.show(onUserEarnedReward: (ad, reward) async {
      if (!mounted) return;
      setState(() => coins += 50);
      await prefs?.setInt('coins', coins);
    });
  }

  void _hint() {
    if (coins < 30 || board.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You need 30 coins')));
      return;
    }
    final empty = board.indexOf(0);
    final choices = <int>[];
    if (empty ~/ size > 0) choices.add(empty - size);
    if (empty ~/ size < size - 1) choices.add(empty + size);
    if (empty % size > 0) choices.add(empty - 1);
    if (empty % size < size - 1) choices.add(empty + 1);
    setState(() => coins -= 30);
    prefs?.setInt('coins', coins);
    _tap(choices.first);
  }

  void _leaderboard() {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (ctx) => SafeArea(
      child: SizedBox(height: MediaQuery.sizeOf(ctx).height * .65, child: Column(children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('🏆 Leaderboard', style: TextStyle(fontSize: 22))),
        if (!widget.online) const Padding(padding: EdgeInsets.all(16), child: Text('Configure Firebase to enable online leaderboard.'))
        else Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('leaderboard').orderBy('score', descending: true).limit(50).snapshots(),
          builder: (ctx, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Leaderboard unavailable'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            return ListView.builder(itemCount: snapshot.data!.docs.length, itemBuilder: (ctx, i) {
              final data = snapshot.data!.docs[i].data();
              return ListTile(leading: CircleAvatar(child: Text('${i + 1}')), title: Text('${data['name']}'), trailing: Text('${data['score']}'));
            });
          },
        )),
      ])),
    ));
  }

  @override
  void dispose() {
    rewarded?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Number Slide Pro'), actions: [
      IconButton(onPressed: _leaderboard, icon: const Icon(Icons.leaderboard)),
      IconButton(onPressed: () {
        setState(() => sound = !sound);
        prefs?.setBool('sound', sound);
      }, icon: Icon(sound ? Icons.volume_up : Icons.volume_off)),
    ]),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: ListView(padding: const EdgeInsets.all(18), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('🪙 $coins coins', style: Theme.of(context).textTheme.titleLarge),
          Text('Moves: $moves  •  Best: $best'),
        ]),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 3, label: Text('Easy')),
            ButtonSegment(value: 4, label: Text('Medium')),
            ButtonSegment(value: 5, label: Text('Hard')),
          ],
          selected: {size},
          onSelectionChanged: (selected) { setState(() => size = selected.first); _newGame(); },
        ),
        const SizedBox(height: 18),
        AspectRatio(aspectRatio: 1, child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: board.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: size, mainAxisSpacing: 5, crossAxisSpacing: 5),
          itemBuilder: (ctx, i) => board[i] == 0
              ? const DecoratedBox(decoration: BoxDecoration(color: Color(0xffeeeeff), borderRadius: BorderRadius.all(Radius.circular(12))))
              : FilledButton(
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => _tap(i),
                  child: Text('${board[i]}', style: TextStyle(fontSize: size == 5 ? 22 : 30, fontWeight: FontWeight.bold)),
                ),
        )),
        const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          FilledButton.tonal(onPressed: () => _newGame(), child: const Text('New Game')),
          FilledButton.tonal(onPressed: () => _newGame(isDaily: true), child: const Text('Daily Challenge')),
          FilledButton.tonal(onPressed: _hint, child: const Text('Hint • 30 🪙')),
          FilledButton(onPressed: _showAd, child: const Text('Watch Ad • +50 🪙')),
        ]),
        const SizedBox(height: 12),
        if (daily) const Center(child: Text('📅 Today’s daily puzzle')),
      ]),
    ))),
  );
}
