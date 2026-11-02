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

  static const _bg = Color(0xFF070A1B);
  static const _gold = Color(0xFFFBBF24);
  static const _violet = Color(0xFF6366F1);
  static const _slate = Color(0xFF141B35);

  BoxDecoration _glass({double radius = 18}) => BoxDecoration(
    color: Colors.white.withValues(alpha: .045),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: .10)),
    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 20, offset: Offset(0, 8))],
  );

  Widget _action(String label, IconData icon, VoidCallback onTap,
      {bool primary = false, Color? iconColor}) {
    return SizedBox(
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: primary
                ? BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4338CA), Color(0xFF6366F1), Color(0xFF4338CA)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x886366F1)))
                : _glass(radius: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 17, color: iconColor ?? Colors.white),
              const SizedBox(width: 7),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tile(int index) {
    final number = board[index];
    if (number == 0) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xB8000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .04)),
          boxShadow: const [BoxShadow(color: Color(0xBB000000), blurRadius: 8, offset: Offset(0, 3), blurStyle: BlurStyle.inner)]),
        child: Center(child: Container(width: 6, height: 6,
          decoration: const BoxDecoration(color: Color(0xFF303650), shape: BoxShape.circle))),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _tap(index),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF3A4962), Color(0xFF202A42)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x8864758B)),
            boxShadow: const [
              BoxShadow(color: Color(0xB8000000), blurRadius: 9, offset: Offset(0, 5)),
              BoxShadow(color: Color(0x22FFFFFF), blurRadius: 2, offset: Offset(0, -1), blurStyle: BlurStyle.inner),
            ],
          ),
          child: Center(child: Text('$number', style: TextStyle(
              color: Colors.white, fontSize: size == 5 ? 19 : (size == 4 ? 24 : 30),
              fontWeight: FontWeight.w800))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final boardWidth = min(screen.width - 44, 380.0);
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        Positioned(top: -120, left: -60, right: -60, height: 400,
          child: IgnorePointer(child: Container(decoration: const BoxDecoration(
            gradient: RadialGradient(colors: [Color(0x444F46E5), Colors.transparent]))))),
        Positioned(bottom: -120, left: -130, width: 360, height: 360,
          child: IgnorePointer(child: Container(decoration: const BoxDecoration(
            gradient: RadialGradient(colors: [Color(0x2238BDF8), Colors.transparent]))))),
        Positioned(bottom: 50, right: -140, width: 320, height: 320,
          child: IgnorePointer(child: Container(decoration: const BoxDecoration(
            gradient: RadialGradient(colors: [Color(0x20F59E0B), Colors.transparent]))))),
        SafeArea(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: max(0, constraints.maxHeight - 36)),
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(children: [
                  Row(children: [
                    Container(width: 10, height: 10,
                      decoration: const BoxDecoration(color: _violet, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: _violet, blurRadius: 9)])),
                    const SizedBox(width: 9),
                    const Text('Number Slide', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                    const SizedBox(width: 7),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
                        borderRadius: BorderRadius.circular(6)),
                      child: const Text('PRO', style: TextStyle(color: _bg, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))),
                    const Spacer(),
                    _topIcon(Icons.bar_chart_rounded, _leaderboard),
                    const SizedBox(width: 8),
                    _topIcon(sound ? Icons.volume_up_outlined : Icons.volume_off_outlined, () {
                      setState(() => sound = !sound);
                      prefs?.setBool('sound', sound);
                    }),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: _glass(),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0x55FBBF24))),
                        child: Row(children: [
                          const Icon(Icons.monetization_on, size: 22, color: _gold),
                          const SizedBox(width: 5),
                          Text('$coins', style: const TextStyle(color: Color(0xFFFDE68A), fontWeight: FontWeight.w900)),
                          const Text(' coins', style: TextStyle(color: Color(0xFFDFC98B), fontSize: 10)),
                          const SizedBox(width: 5),
                          GestureDetector(onTap: _showAd, child: const Icon(Icons.add_circle_outline, color: _gold, size: 16)),
                        ]),
                      ),
                      const Spacer(),
                      const Text('Moves: ', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                      Text('$moves', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.circle, size: 4, color: Color(0xFF64748B))),
                      const Text('Best: ', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                      Text('$best', style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: const Color(0x77000000),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: .10))),
                    child: Row(children: [
                      for (final mode in [3, 4, 5])
                        Expanded(child: GestureDetector(
                          onTap: () { if (size != mode) { setState(() => size = mode); _newGame(); } },
                          child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                            height: 38,
                            decoration: size == mode
                              ? BoxDecoration(gradient: const LinearGradient(colors: [_violet, Color(0xFF4338CA)]),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0x886366F1)))
                              : BoxDecoration(borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              if (size == mode) const Padding(padding: EdgeInsets.only(right: 5),
                                child: Icon(Icons.check, color: Colors.white, size: 14)),
                              Text(mode == 3 ? 'Easy' : mode == 4 ? 'Medium' : 'Hard',
                                style: TextStyle(color: size == mode ? Colors.white : const Color(0xFF9CA3AF),
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                            ])),
                          ),
                        )),
                    ]),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Container(
                    width: boardWidth, height: boardWidth,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xBB11182D),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: .10)),
                      boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 26, offset: Offset(0, 12))]),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: board.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: size, mainAxisSpacing: 7, crossAxisSpacing: 7),
                      itemBuilder: (context, index) => _tile(index),
                    ),
                  ),
                ),
                Column(children: [
                  Row(children: [
                    Expanded(child: _action('New Game', Icons.restart_alt, () => _newGame())),
                    const SizedBox(width: 10),
                    Expanded(child: _action('Daily Challenge', Icons.calendar_month_outlined,
                        () => _newGame(isDaily: true), iconColor: _gold)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _action('Hint • 30 🪙', Icons.lightbulb,
                        _hint, iconColor: _gold)),
                    const SizedBox(width: 10),
                    Expanded(child: _action('Watch Ad • +50 🪙', Icons.smart_display,
                        _showAd, primary: true)),
                  ]),
                  if (daily) const Padding(padding: EdgeInsets.only(top: 10),
                    child: Text("TODAY'S DAILY CHALLENGE", style: TextStyle(
                      color: _gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5))),
                ]),
              ]),
            ),
          )),
        ))),
      ]),
    );
  }

  Widget _topIcon(IconData icon, VoidCallback onTap) => Container(
    width: 40, height: 40, decoration: _glass(radius: 12),
    child: IconButton(onPressed: onTap, icon: Icon(icon, color: const Color(0xFFCBD5E1), size: 20),
      padding: EdgeInsets.zero),
  );
}
