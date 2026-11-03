import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'arcade.dart';
import 'leaderboard.dart';

class LeaderboardSheet extends StatefulWidget {
  const LeaderboardSheet({super.key, required this.initialSize, required this.watch});
  final int initialSize;
  final Stream<Standings> Function(int size) watch;

  @override
  State<LeaderboardSheet> createState() => _LeaderboardSheetState();
}

class _LeaderboardSheetState extends State<LeaderboardSheet> {
  late int _size;
  late Stream<Standings> _scores;

  @override
  void initState() {
    super.initState();
    _size = widget.initialSize;
    _scores = widget.watch(_size);
  }

  void _select(int n) => setState(() {
    _size = n;
    _scores = widget.watch(n);
  });

  Widget _notice(IconData icon, String title, String detail, {bool retry = false}) =>
    Center(child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: cyan, size: 26), const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: quiet)),
        if (retry) TextButton(onPressed: () => _select(_size), child: const Text('Retry')),
      ],
    )));

  @override
  Widget build(BuildContext context) => SafeArea(top: false, child: FractionallySizedBox(
    heightFactor: .87, child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(children: [
        Container(width: 38, height: 4, decoration: BoxDecoration(color: seam, borderRadius: BorderRadius.circular(2))),
        Row(children: [
          const Icon(Icons.emoji_events_outlined, color: amber), const SizedBox(width: 9),
          const Expanded(child: Text('Leaderboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 23))),
          IconButton(tooltip: 'Close leaderboard', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ]),
        GridSelector(value: _size, onChanged: (n) { if (n != _size) _select(n); }),
        const SizedBox(height: 10),
        Expanded(child: StreamBuilder<Standings>(key: ObjectKey(_scores), stream: _scores,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final error = snapshot.error;
              final offline = error is FirebaseException &&
                ['unavailable', 'network-request-failed', 'deadline-exceeded'].contains(error.code);
              return _notice(offline ? Icons.cloud_off : Icons.leaderboard_outlined,
                offline ? 'You’re offline' : 'Standings unavailable',
                offline ? 'Reconnect to see the latest scores.' : 'Try loading this board again.', retry: true);
            }
            final standings = snapshot.data;
            if (standings == null) {
              return const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading leaderboard'));
            }
            if (standings.entries.isEmpty) {
              return standings.cached
                ? _notice(Icons.cloud_off, 'Waiting for a connection', 'No scores are saved on this device.', retry: true)
                : _notice(Icons.grid_view_rounded, 'No scores yet', 'Finish a $_size×$_size puzzle to enter the rankings.');
            }
            return Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(4, 2, 4, 8), child: Row(children: [
                Expanded(child: Text(standings.cached ? 'SAVED STANDINGS' : 'RANK  /  PLAYER', style: caption)),
                const Text('SCORE', style: caption),
              ])),
              Expanded(child: ListView.separated(itemCount: standings.entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, i) {
                  final p = standings.entries[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: p.mine ? const Color(0xFF203650) : midnight,
                      borderRadius: BorderRadius.circular(10), border: Border.all(color: p.mine ? cyan : seam)),
                    child: Row(children: [
                      SizedBox(width: 32, child: Text('${i + 1}'.padLeft(2, '0'),
                        style: TextStyle(color: i == 0 ? amber : quiet, fontFeatures: figures,
                          fontWeight: FontWeight.bold))),
                      Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (p.mine) const Padding(padding: EdgeInsets.symmetric(horizontal: 7),
                        child: Text('YOU', style: TextStyle(color: cyan, fontSize: 10, fontWeight: FontWeight.w800))),
                      Text('${p.score}', textAlign: TextAlign.end,
                        style: const TextStyle(fontFeatures: figures, fontSize: 16, fontWeight: FontWeight.w800)),
                    ]),
                  );
                })),
            ]);
          })),
      ]),
    ),
  ));
}
