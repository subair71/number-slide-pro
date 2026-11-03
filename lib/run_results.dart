import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'vault_items.dart';

enum RunAction { next, practice, hub }

class RunSummary {
  const RunSummary({required this.size, required this.moves, required this.score, required this.elapsedMs,
    required this.previousMs, required this.newBest, required this.daily, required this.practice,
    required this.coins, required this.gems, required this.xpEarned, required this.xp,
    required this.streak, required this.combo, required this.reversals, required this.hints});
  final int size, moves, score, elapsedMs, coins, gems, xpEarned, xp, streak, combo, reversals, hints;
  final int? previousMs;
  final bool newBest, daily, practice;
  double get efficiency => moves == 0 ? 0 : (moves - reversals) / moves;
  String get grade => hints == 0 && reversals == 0 ? 'S+' : efficiency >= .85 ? 'A' : efficiency >= .65 ? 'B' : 'C';
  String get time {
    final total = elapsedMs ~/ 1000;
    return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }
  String get mode => practice ? 'Practice' : daily ? 'Daily' : 'Classic';
}

Future<void> shareArcade(BuildContext context, String text) async {
  try {
    await const MethodChannel('com.bilvok.numberslidepro/share').invokeMethod<void>('share', text);
  } on Exception {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }
}

class RunResults extends StatelessWidget {
  const RunResults({super.key, required this.run, required this.rank});
  final RunSummary run;
  final Future<String> rank;

  Widget _label(String text, {double size = 15}) => Text(text, style: chunky(size));
  Widget _info(String title, String value, IconData icon) => Expanded(child: Row(children: [
    Icon(icon, color: paper, size: 18), const SizedBox(width: 9),
    Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(height: 5), Text(value, style: chunky(14)),
    ])),
  ]));
  Widget _section(Widget child, {double padding = 19}) => Container(
    width: double.infinity, margin: const EdgeInsets.only(top: 10),
    padding: EdgeInsets.all(padding), color: const Color(0x4D070717), child: child,
  );
  Widget _metric(String title, String value, String detail) => Expanded(child: Column(children: [
    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    const SizedBox(height: 9), Text(value, textAlign: TextAlign.center, style: chunky(18)),
    Text(detail, textAlign: TextAlign.center, style: chunky(12)),
  ]));

  Widget _control(BuildContext ctx, String label, IconData icon, RunAction? action) => TextButton.icon(
    onPressed: action == null
      ? () => shareArcade(ctx, 'Number Slide Pro · ${run.mode} ${run.size}×${run.size}: ${run.time}, ${run.moves} moves, ${run.score} points.')
      : () => Navigator.pop(ctx, action),
    icon: Icon(icon, size: 17), label: Text(label, style: chunky(14)),
    style: TextButton.styleFrom(foregroundColor: paper, minimumSize: const Size(48,48)),
  );

  @override
  Widget build(BuildContext context) {
    final delta = run.previousMs == null ? null : (run.elapsedMs - run.previousMs!) / 1000;
    final difference = delta != null ? '  ${delta <= 0 ? "" : "+"}${delta.toStringAsFixed(1)}s' : '';
    const levelSize = 5000;
    final progress = run.xp % levelSize, level = 1 + run.xp ~/ levelSize;
    final priorLevel = 1 + (run.xp - run.xpEarned) ~/ levelSize;
    return Scaffold(backgroundColor: const Color(0xFF0C0B1B),
      body: CustomPaint(painter: const ResultPattern(), child: SafeArea(child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(key: const Key('results-scroll'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 26), children: [
            Text(run.practice ? '✧ PRACTICE COMPLETE ✧' : run.newBest ? '✪ NEW PERSONAL BEST! ♨' : '✪ PUZZLE COMPLETE! ✧',
              textAlign: TextAlign.center, style: chunky(17).copyWith(letterSpacing: 1.4)),
            const SizedBox(height: 40),
            Text('${run.mode} ${run.size}×${run.size} Slider · Speedrun Blitz', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Icon(Icons.star_border_rounded, size: 33, color: paper), const SizedBox(width: 22),
              Column(children: [
                const Icon(Icons.star_border_rounded, color: paper, size: 52,
                  shadows: [Shadow(color: Color(0xAAFF2B95), blurRadius: 18)]),
                Text(run.grade == 'S+' ? 'FLAWLESS' : 'SOLVED', style: chunky(14).copyWith(letterSpacing: 1.2)),
              ]), const SizedBox(width: 22), const Icon(Icons.star_border_rounded, size: 33, color: paper),
            ]),
            const SizedBox(height: 16),
            _section(Row(children: [
              _info('TIME RECORD', '${run.time}$difference', Icons.timer_outlined),
              _info('TOTAL MOVES', '${run.moves}  ${(100 * run.efficiency).toStringAsFixed(1)}%', Icons.route_outlined),
            ])),
            _section(Column(children: [
              Row(children: [const Icon(Icons.check_circle_outline, size: 17), const SizedBox(width: 6),
                Expanded(child: _label('HARMONIC ALIGNMENT (${run.size}×${run.size})')),
                const SizedBox(width: 8), _label('Solved\nState', size: 13)]),
              const SizedBox(height: 12),
              AspectRatio(aspectRatio: 1.25, child: GridView.count(primary: false, padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(), crossAxisCount: run.size, childAspectRatio: 1.25,
                children: List.generate(run.size * run.size, (i) => Center(
                  child: i + 1 == run.size * run.size ? const Icon(Icons.lock_outline_rounded, size: 17) : _label('${i+1}'))))),
            ])),
            _section(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: _label('MATCH LOOT & BOUNTIES')),
                const SizedBox(width: 12), Flexible(child: _label(run.xpEarned > 0 ? 'Rewards Active' : run.practice ? 'Practice Run' : 'Already Claimed', size: 13))]),
              const SizedBox(height: 20),
              Row(children: [_info('Coins', '+${run.coins}', Icons.monetization_on_outlined),
                _info('Gems', '+${run.gems}', Icons.diamond_outlined)]),
              const SizedBox(height: 26),
              Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 4, children: [
                _label(priorLevel == level ? 'LEVEL $level' : 'LEVEL $priorLevel → Lvl $level'),
                _label('+${run.xpEarned} XP Earned', size: 13)]),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress / levelSize, color: neon, backgroundColor: const Color(0xFF18192D), minHeight: 3),
              const SizedBox(height: 9), Wrap(spacing: 16, runSpacing: 4,
                children: [_label('${grouped(progress)} / 5,000 XP', size: 13), _label('Only ${grouped(levelSize-progress)} XP remaining!', size: 12)]),
              const SizedBox(height: 24),
              Row(children: [_info('${run.streak}-Day Streak','Running',Icons.local_fire_department_outlined),
                _info(run.streak >= 5 ? '+20% XP' : '5-Day Goal', run.streak >= 5 ? 'BONUS' : '+20% XP', Icons.bolt_outlined)]),
            ])),
            _section(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('SPEEDRUN TELEMETRY'), const SizedBox(height: 20),
              FutureBuilder<String>(future: rank, builder: (_, state) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _metric('GLOBAL RANK', state.data ?? '…', 'Best score'),
                _metric('COMBO RUN', '${run.combo}×', 'Chained slides'),
                _metric('PATH RATING', run.grade, run.grade == 'S+' ? 'Flawless' : 'Slide accuracy'),
              ])),
              const SizedBox(height: 14), Center(child: _label('Score · ${run.score}', size: 12)),
            ])),
            const SizedBox(height: 18),
            FilledButton.icon(iconAlignment: IconAlignment.end, onPressed: () => Navigator.pop(context, RunAction.next),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF101022), foregroundColor: paper,
                minimumSize: const Size.fromHeight(50)), label: Text('Next Puzzle',style: chunky(16)),
              icon: const Icon(Icons.arrow_forward)),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _control(context, 'PRACTICE', Icons.replay, RunAction.practice),
              _control(context, 'SHARE RUN', Icons.ios_share_outlined, null),
            ]),
            _control(context, 'BACK TO ARCADE HUB', Icons.dashboard_outlined, RunAction.hub),
          ])),
      ))));
  }
}

class ResultPattern extends CustomPainter {
  const ResultPattern();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint();
    for (double y = 3; y < s.height; y += 22) {
      for (double x = 6; x < s.width; x += 25) {
        p.color = ((x + y).round() % 3 == 0 ? hotPink : neon).withValues(alpha: .11);
        c.drawCircle(Offset(x + (y.round().isEven ? 9 : 0), y), 1.35, p);
      }
    }
    final r = math.Random(19);
    for (int i = 0; i < 34; i++) {
      final at = Offset(r.nextDouble()*s.width, r.nextDouble()*s.height*.70);
      c.save(); c.translate(at.dx,at.dy); c.rotate(r.nextDouble()*2);
      final shape = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero,width: 3+r.nextDouble()*4,height: 6+r.nextDouble()*4), const Radius.circular(2));
      p.color = [neon, const Color(0xFFA09BFF), paper][i%3].withValues(alpha: i%5 == 0 ? .72 : .20);
      c.drawRRect(shape,p); c.restore();
    }
  }
  @override
  bool shouldRepaint(ResultPattern oldDelegate) => false;
}
