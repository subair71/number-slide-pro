import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'game_banner.dart';
import 'leaderboard.dart';
import 'arcade.dart';
import 'leaderboard_sheet.dart';
import 'puzzle_board.dart';
import 'theme_vault.dart';
import 'vault_items.dart';
import 'run_results.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const PuzzleApp());
}

class PuzzleApp extends StatelessWidget {
  const PuzzleApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, fontFamily: 'Outfit', brightness: Brightness.dark,
      textTheme: const TextTheme(bodyMedium: TextStyle(fontFamily: 'Outfit', fontVariations: [FontVariation('wght', 500)])),
      scaffoldBackgroundColor: midnight, colorScheme: ColorScheme.fromSeed(seedColor: violet,
        brightness: Brightness.dark).copyWith(primary: cyan, surface: panel)),
    title: 'Number Slide Pro',
    home: const PuzzlePage(),
  );
}

class PuzzlePage extends StatefulWidget {
  const PuzzlePage({super.key});
  @override
  State<PuzzlePage> createState() => _PuzzlePageState();
}

class _PuzzlePageState extends State<PuzzlePage> with SingleTickerProviderStateMixin {
  static const _rewardedUnitId = kReleaseMode
      ? String.fromEnvironment('ADMOB_ANDROID_REWARDED_UNIT_ID')
      : 'ca-app-pub-3940256099942544/5224354917';
  int size = 4, moves = 0, best = 0;
  PlayerProgress progress = PlayerProgress();
  int get coins => progress.coins;
  final _clock = Stopwatch();
  late final AppLifecycleListener _lifecycle;
  bool _shop = false, _overlay = false, _practice = false;
  int _combo = 0, _longestCombo = 0, _reversals = 0, _hints = 0, _lastMoveMs = 0;
  List<int> _opening = [];
  VaultItem? _preview;
  VaultItem _appearance(VaultTab tab) =>
      _preview?.tab == tab ? _preview! : progress.active(tab);

  Future<void> _save() async {
    if (prefs != null) await progress.save(prefs!);
  }

  void _resumeClock() {
    if (moves > 0 && !busy && !_shop && !_overlay &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _clock.start();
    }
  }
  bool daily = false, sound = true, busy = false;
  List<int> board = [];
  RewardedAd? rewarded;
  SharedPreferences? prefs;
  final leaderboard = Leaderboard();
  late final AnimationController _sweep;
  int _round = 0;
  int? _lastTile;
  Offset _direction = Offset.zero;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onPause: _clock.stop, onInactive: _clock.stop, onResume: _resumeClock);
    _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 610));
    _init();
    _loadAd();
  }

  Future<void> _init() async {
    prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      progress = PlayerProgress.read(prefs!);
      sound = progress.active(VaultTab.sounds).id != 'mute';
      best = prefs!.getInt('best_$size') ?? 0;
    });
    _newGame();
    unawaited(_syncBest(size, best));
  }

  Future<void> _syncBest(int boardSize, int score) async {
    try {
      await leaderboard.submitBest(boardSize, score);
    } catch (error) {
      debugPrint('Leaderboard sync deferred: $error');
    }
  }

  List<int> _shuffle(bool isDaily) {
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
    return tiles;
  }

  void _newGame({bool isDaily = false, List<int>? practiceBoard}) {
    if (!mounted || busy) return;
    final tiles = practiceBoard == null ? _shuffle(isDaily) : List.of(practiceBoard);
    _clock.stop();
    _clock.reset();
    setState(() {
      _opening = List.of(tiles);
      _practice = practiceBoard != null;
      _combo = _longestCombo = _reversals = _hints = _lastMoveMs = 0;
      _round++;
      _lastTile = null;
      _sweep.reset();
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
    if (_appearance(VaultTab.sounds).id != 'mute') SystemSound.play(SystemSoundType.click);
    _clock.start();
    final ms = _clock.elapsedMilliseconds;
    _combo = moves == 0 || ms - _lastMoveMs > 2000 ? 1 : _combo + 1;
    _longestCombo = max(_longestCombo, _combo);
    _lastMoveMs = ms;
    if (_lastTile == board[index]) _reversals++;
    setState(() {
      _lastTile = board[index];
      _direction = Offset((empty % size - index % size).toDouble(), (empty ~/ size - index ~/ size).toDouble());
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
    _clock.stop();
    final elapsed = _clock.elapsedMilliseconds;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final yesterday = DateTime.utc(int.parse(today.substring(0, 4)), int.parse(today.substring(5, 7)),
        int.parse(today.substring(8))).subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    final claimed = progress.dailyClaims['${today}_$size'] == today || progress.dailyClaims['$size'] == today || (prefs?.getBool('daily_${today}_$size') ?? false);
    final canReward = !_practice && (!daily || !claimed);
    final earned = canReward ? (daily ? 100 : 20) : 0;
    final gems = canReward ? (daily ? 25 : 5) : 0;
    final previousMs = progress.bestTimes['$size'];
    final record = !_practice && score > best;
    if (!_practice && (previousMs == null || elapsed < previousMs)) progress.bestTimes['$size'] = elapsed;
    if (canReward && progress.lastWin != today) {
      progress.streak = progress.lastWin == yesterday ? progress.streak + 1 : 1;
      progress.lastWin = today;
    }
    final xp = canReward ? ((daily ? 300 : 100) * (progress.streak >= 5 ? 1.2 : 1)).round() : 0;
    progress.coins += earned;
    progress.gems += gems;
    progress.xp += xp;
    if (daily && canReward) progress.dailyClaims['${today}_$size'] = today;
    await _save();
    if (record) {
      best = score;
      await prefs?.setInt('best_$size', best);
    }
    final saved = _practice ? Future<void>.value() : _syncBest(size, best);
    if (!mounted) return;
    final still = MediaQuery.disableAnimationsOf(context);
    if (!still) {
      try {
        await _sweep.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    final summary = RunSummary(size: size, moves: moves, score: score, elapsedMs: elapsed, previousMs: previousMs,
      newBest: record, daily: daily, practice: _practice, coins: earned, gems: gems, xpEarned: xp,
      xp: progress.xp, streak: progress.streak, combo: _longestCombo, reversals: _reversals, hints: _hints);
    final rank = _rankAfter(saved, size);
    final action = await Navigator.of(context).push<RunAction>(PageRouteBuilder<RunAction>(
      transitionDuration: still ? Duration.zero : const Duration(milliseconds: 180),
      reverseTransitionDuration: still ? Duration.zero : const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) => RunResults(run: summary, rank: rank),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    ));
    if (!mounted) return;
    busy = false;
    // A practice replay uses the exact starting board and never changes the wallet or records.
    _newGame(isDaily: action == RunAction.practice && daily,
      practiceBoard: action == RunAction.practice ? _opening : null);
  }

  Future<String> _rankAfter(Future<void> submission, int boardSize) async {
    try {
      final rank = await submission.then((_) => leaderboard.bestRank(boardSize)).timeout(const Duration(seconds: 8));
      return rank == null ? 'Unranked' : '#$rank';
    } catch (_) {
      return 'Unavailable';
    }
  }

  void _loadAd() {
    if (!mounted || _rewardedUnitId.isEmpty) return;
    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          rewarded?.dispose();
          setState(() => rewarded = ad);
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
      setState(() => progress.coins += 50);
      await _save();
    });
  }

  void _hint() {
    if (busy) return;
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
    setState(() { progress.coins -= 30; _hints++; });
    unawaited(_save());
    _tap(choices.first);
  }

  Future<void> _leaderboard() async {
    _clock.stop();
    _overlay = true;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => LeaderboardSheet(initialSize: size, watch: (n) {
        unawaited(_syncBest(n, prefs?.getInt('best_$n') ?? 0));
        return leaderboard.standings(n);
      }),
    );
    if (mounted) { _overlay = false; _resumeClock(); }
  }

  void _closeVault() {
    setState(() { _shop = false; _preview = null; });
    _resumeClock();
  }

  Future<void> _navigate(int index) async {
    if (busy) return;
    if (index == 0) { _closeVault(); return; }
    if (index == 2) {
      _clock.stop();
      setState(() => _shop = true);
      return;
    }
    setState(() { _shop = false; _preview = null; });
    _clock.stop();
    _overlay = true;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final done = progress.dailyClaims['${today}_$size'] == today || progress.dailyClaims['$size'] == today || (prefs?.getBool('daily_${today}_$size') ?? false);
    final selected = await showModalBottomSheet<String>(context: context, backgroundColor: vaultPanel,
      builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ArcadeNav.labels[index].toUpperCase(), style: chunky(22)),
          const SizedBox(height: 10),
          Text(index == 3 ? 'Share a puzzle challenge or view the community standings.' :
            index == 1 ? 'Daily Challenge · $size×$size · $today' :
            done ? 'Daily $size×$size completed · Reward claimed' : 'Solve today’s $size×$size puzzle to collect 100 coins.'),
          const SizedBox(height: 12),
          if (index == 3) ...[
            TextButton(onPressed: () => shareArcade(ctx, 'Can you beat my $size×$size best score of $best in Number Slide Pro?'),
              child: const Text('Share challenge')),
            VaultButton('Community leaderboard', () => Navigator.pop(ctx, 'rank'), bright: true),
          ] else VaultButton(done ? 'Replay daily puzzle' : 'Play daily puzzle', () => Navigator.pop(ctx, 'daily'), bright: true),
        ]))));
    if (!mounted) return;
    _overlay = false;
    if (selected == 'daily') { _newGame(isDaily: true); }
    else if (selected == 'rank') { await _leaderboard(); }
    else { _resumeClock(); }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _sweep.dispose();
    rewarded?.dispose();
    super.dispose();
  }

  Widget _header() => Row(children: [
    Container(width: 36, height: 36, alignment: Alignment.center,
      decoration: BoxDecoration(color: tileIndigo, border: Border.all(color: const Color(0xFF6872AF)),
        borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.dashboard_rounded, color: cyan, size: 22)),
    const SizedBox(width: 9),
    Expanded(child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('POCKET ARCADE', style: TextStyle(color: cyan, fontSize: 9, letterSpacing: 1.7,
          fontWeight: FontWeight.w800)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Number Slide', style: TextStyle(color: Colors.white, fontSize: 24, height: 1.14,
            letterSpacing: -.8, fontWeight: FontWeight.w900)),
          const SizedBox(width: 5),
          DecoratedBox(decoration: BoxDecoration(color: amber, borderRadius: BorderRadius.circular(4)),
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text('PRO', style: TextStyle(color: midnight, fontSize: 9, fontWeight: FontWeight.w900)))),
        ]),
      ])))),
    const SizedBox(width: 6),
    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 84),
      child: Semantics(label: '$coins coins', hint: _rewardedUnitId.isEmpty ? null : 'Watch an ad to earn 50 coins',
        button: _rewardedUnitId.isNotEmpty, excludeSemantics: true,
        child: InkWell(onTap: _rewardedUnitId.isEmpty || busy ? null : _showAd,
          borderRadius: BorderRadius.circular(18),
          child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48),
            child: Center(heightFactor: 1, child: DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFF312B2B), borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF6C5740))),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.toll_rounded, color: amber, size: 16), const SizedBox(width: 4),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text('$coins',
              style: const TextStyle(color: amber, fontFeatures: figures, fontWeight: FontWeight.w800)))),
          ])))))))),
    IconButton(tooltip: sound ? 'Mute sound' : 'Enable sound',
      onPressed: () {
        setState(() { sound = !sound; progress.equip(itemFor(sound ? 'click' : 'mute')); });
        unawaited(_save());
      }, icon: Icon(sound ? Icons.volume_up_outlined : Icons.volume_off_outlined, color: quiet)),
  ]);

  Widget _stat(String label, String value) => Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: caption),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 23, height: 1.12,
          fontWeight: FontWeight.w800, fontFeatures: figures)),
    ],
  ));

  Widget _instruments() => Column(mainAxisSize: MainAxisSize.min, children: [
    _header(), const SizedBox(height: 12),
    GridSelector(value: size, onChanged: busy ? null : (n) {
      if (size != n) { size = n; _newGame(); }
    }),
    const SizedBox(height: 10),
    Container(padding: const EdgeInsets.fromLTRB(16, 5, 5, 5),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: seam)),
      child: Row(children: [
        _stat('MOVES', moves.toString().padLeft(2, '0')),
        Container(width: 1, height: 30, margin: const EdgeInsets.only(right: 14), color: seam),
        _stat('BEST SCORE', '$best'),
        IconButton(tooltip: 'Leaderboard', onPressed: busy ? null : _leaderboard,
          icon: const Icon(Icons.leaderboard_outlined, color: cyan)),
      ]),
    ),
  ]);

  Widget _action(String label, IconData icon, VoidCallback callback, {bool primary = false, Color accent = quiet}) {
    final fill = primary ? violet : panel;
    return Semantics(button: true, child: Material(color: fill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primary ? const Color(0xFFAD94FF) : seam)),
      clipBehavior: Clip.antiAlias, child: InkWell(onTap: busy ? null : callback,
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: primary ? Colors.white : accent), const SizedBox(width: 6),
              Flexible(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(
                color: Colors.white, fontSize: 13, height: 1.14, fontWeight: FontWeight.w700))),
            ]))))));
  }

  Widget _controls() => Column(children: [
    Row(children: [
      Expanded(child: _action('New Game', Icons.replay_rounded, () => _newGame(), primary: true)),
      const SizedBox(width: 8),
      Expanded(child: _action('Daily Challenge', Icons.calendar_today_outlined, () => _newGame(isDaily: true),
        accent: daily ? amber : quiet)),
    ]),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: _action('Hint · 30 coins', Icons.lightbulb_outline, _hint, accent: amber)),
      if (_rewardedUnitId.isNotEmpty) ...[
        const SizedBox(width: 8),
        Expanded(child: _action('Watch Ad · +50 coins', Icons.play_circle_outline, _showAd, accent: amber)),
      ],
    ]),
  ]);

  Widget _playfield(double side) => SizedBox(width: side, child: Column(mainAxisSize: MainAxisSize.min, children: [
    Row(children: [
      const Text('PLAYFIELD', style: caption), const Spacer(),
      Icon(daily ? Icons.calendar_today : Icons.circle, size: daily ? 12 : 7, color: daily ? amber : cyan),
      const SizedBox(width: 5), Text(_practice ? 'Practice' : daily ? 'Daily challenge' : 'Classic',
        style: TextStyle(color: daily ? amber : cyan, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
    const SizedBox(height: 7),
    PuzzleBoard(key: ValueKey('round-$_round'), tiles: board, size: size, onTap: busy ? null : _tap,
      lastTile: _lastTile, direction: _direction, moves: moves, sweep: _sweep,
      skin: _appearance(VaultTab.skins), frame: _appearance(VaultTab.frames), trail: _appearance(VaultTab.trails)),
  ]));

  @override
  Widget build(BuildContext context) {
    final bannerWidth = (MediaQuery.sizeOf(context).width - MediaQuery.paddingOf(context).horizontal).floor();
    return PopScope(canPop: !_shop && _preview == null, onPopInvokedWithResult: (popped, _) {
      if (!popped && (_shop || _preview != null)) _closeVault();
    }, child: Scaffold(
      bottomNavigationBar: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        ArcadeNav(selected: _shop ? 2 : 0, onSelect: _navigate),
        if (!_shop) GameBanner(key: ValueKey((bannerWidth, MediaQuery.orientationOf(context))), width: bannerWidth),
      ])),
      body: Stack(fit: StackFit.expand, children: [
        ExcludeSemantics(excluding: _shop, child: IgnorePointer(ignoring: _shop, child: CustomPaint(painter: const ArcadeBackdrop(), child: SafeArea(child: LayoutBuilder(
        builder: (context, bounds) {
          if (bounds.maxWidth >= 600 && bounds.maxWidth > bounds.maxHeight * 1.25) {
            final half = min(450.0, (bounds.maxWidth - 48) * .5);
            final minBoard = min(half, size * 48.0 + (size - 1) * 4 + 24);
            final side = (bounds.maxHeight - 48).clamp(minBoard, half).toDouble();
            return Center(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _playfield(side), const SizedBox(width: 16),
                SizedBox(width: half, child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _instruments(), const SizedBox(height: 14), _controls(),
                ])),
              ])));
          }
          final side = min(428.0, max(0.0, bounds.maxWidth - 32));
          return Center(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: SizedBox(width: side, child: Column(mainAxisSize: MainAxisSize.min, children: [
              _instruments(), const SizedBox(height: 16), _playfield(side),
              const SizedBox(height: 16), _controls(),
            ]))));
        },
      ))))),
      if (!_shop && _preview != null) Align(alignment: Alignment.topCenter, child: SafeArea(
        child: ActionChip(label: Text('Preview · ${_preview!.name}  /  Back to vault'), onPressed: () => _navigate(2)))),
      if (_shop) ThemeVault(progress: progress, initial: _preview, onClose: _closeVault,
        onPreview: (item) { setState(() { _preview = item; _shop = false; }); _resumeClock(); },
        onEquip: (item) {
          if (!progress.equip(item)) return false;
          setState(() { sound = progress.active(VaultTab.sounds).id != 'mute'; _preview = null; });
          unawaited(_save());
          return true;
        }),
      ]),
    ));
  }
}
