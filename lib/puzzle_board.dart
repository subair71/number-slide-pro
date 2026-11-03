import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'arcade.dart';
import 'vault_items.dart';
import 'theme_vault.dart' show SlotOutline, tileFinish;

class PuzzleBoard extends StatelessWidget {
  const PuzzleBoard({
    super.key, required this.tiles, required this.size, required this.onTap,
    required this.moves, required this.lastTile, required this.direction,
    required this.sweep, required this.skin, required this.frame, required this.trail,
  });

  final List<int> tiles;
  final int size, moves;
  final int? lastTile;
  final Offset direction;
  final ValueChanged<int>? onTap;
  final Animation<double> sweep;
  final VaultItem skin, frame, trail;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return AspectRatio(aspectRatio: 1, child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [frame.top, frame.bottom]),
        borderRadius: BorderRadius.circular(22), border: Border.all(color: frame.id == 'carbon' ? const Color(0xFF0B637B) : frame.top),
        boxShadow: const [BoxShadow(color: Color(0x66010410), offset: Offset(0, 5), blurRadius: 10)],
      ),
      child: Stack(children: [
        for (final corner in [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight])
          Align(alignment: corner, child: const Padding(padding: EdgeInsets.all(6),
            child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF10152D), shape: BoxShape.circle),
              child: SizedBox.square(dimension: 4)))),
        Padding(padding: const EdgeInsets.all(12), child: LayoutBuilder(builder: (context, bounds) {
          const gap = 4.0;
          final side = (bounds.maxWidth - gap * (size - 1)) / size;
          final pitch = side + gap;
          return Stack(children: [
            for (int i = 0; i < size * size; i++)
              Positioned(left: (i % size) * pitch, top: (i ~/ size) * pitch, width: side, height: side,
                child: DecoratedBox(decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0xFF070C22), Color(0xFF171F3D)]),
                  border: Border.all(color: const Color(0xFF0A1026))),
                  child: CustomPaint(painter: const SlotOutline(neon),
                    child: Center(child: Text('✦', style: chunky(14, const Color(0xFF15546A))))))),
            for (int i = 0; i < tiles.length; i++)
              if (tiles[i] != 0)
                AnimatedPositioned(
                  key: ValueKey(tiles[i]), left: (i % size) * pitch, top: (i ~/ size) * pitch,
                  width: side, height: side, curve: Curves.easeOutCubic,
                  duration: still ? Duration.zero : const Duration(milliseconds: 150),
                  child: Semantics(button: true, label: 'Tile ${tiles[i]}', excludeSemantics: true,
                    onTap: onTap == null ? null : () => onTap!(i),
                    child: GestureDetector(onTap: onTap == null ? null : () => onTap!(i),
                      child: Stack(fit: StackFit.expand, children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF202554), borderRadius: BorderRadius.circular(9),
                            boxShadow: const [BoxShadow(color: Color(0x80030718), offset: Offset(0, 2), blurRadius: 2)]),
                          padding: const EdgeInsets.only(bottom: 3),
                          child: DecoratedBox(
                            decoration: tileFinish(skin),
                            child: Center(child: Text('${tiles[i]}', textScaler: TextScaler.noScaling,
                              style: TextStyle(fontFamily: 'Lilita', color: skin.id == 'sunset' ? const Color(0xFFFFE4A0) : Colors.white, fontSize: math.min(side * .43, 40.0),
                                fontFeatures: figures, height: 1, fontWeight: FontWeight.w800)))),
                        ),
                        if (!still && trail.id != 'quiet' && lastTile == tiles[i])
                          TweenAnimationBuilder<double>(
                            key: ValueKey('landing-$moves'), tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 300),
                            builder: (_, t, __) => IgnorePointer(child: CustomPaint(
                              painter: _LandingEdge(direction, math.sin(math.pi * t), trail.top))),
                          ),
                      ]),
                    ),
                  ),
                ),
            if (!still) Positioned.fill(child: IgnorePointer(child: CustomPaint(
              painter: _SolvedSweep(sweep, size, pitch, side)))),
          ]);
        })),
      ]),
    ));
  }
}

class _LandingEdge extends CustomPainter {
  const _LandingEdge(this.direction, this.strength, this.color);
  final Color color;
  final Offset direction;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= .01) return;
    final horizontal = direction.dx != 0;
    final x = direction.dx > 0 ? size.width - 2 : 2.0;
    final y = direction.dy > 0 ? size.height - 4 : 2.0;
    final from = horizontal ? Offset(x, 8) : Offset(8, y);
    final to = horizontal ? Offset(x, size.height - 9) : Offset(size.width - 8, y);
    canvas.drawLine(from, to, Paint()..color = color.withValues(alpha: strength * .9)
      ..strokeWidth = 2.5..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_LandingEdge old) => old.strength != strength || old.direction != direction;
}

class _SolvedSweep extends CustomPainter {
  _SolvedSweep(this.progress, this.rows, this.pitch, this.side) : super(repaint: progress);
  final Animation<double> progress;
  final int rows;
  final double pitch, side;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= .24 || t >= 1) return;
    final wave = (t - .24) / .76 * (rows + 1) - .5;
    for (int row = 0; row < rows; row++) {
      final alpha = (1 - (wave - row).abs()).clamp(0.0, 1.0);
      if (alpha == 0) continue;
      final rect = Rect.fromLTWH(0, row * pitch, size.width, side);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = cyan.withValues(alpha: alpha * .21));
    }
  }

  @override
  bool shouldRepaint(_SolvedSweep old) => old.rows != rows || old.pitch != pitch || old.progress != progress;
}
