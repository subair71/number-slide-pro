import 'package:flutter/material.dart';

const midnight = Color(0xFF080D24);
const panel = Color(0xFF121936);
const tileIndigo = Color(0xFF343C88);
const violet = Color(0xFF7856FF);
const cyan = Color(0xFF67E8F9);
const amber = Color(0xFFFFC857);
const quiet = Color(0xFFABB5D5);
const seam = Color(0xFF323C61);
const figures = [FontFeature.tabularFigures()];
const caption = TextStyle(fontSize: 10, letterSpacing: 1.55, fontWeight: FontWeight.w800, color: quiet);

class GridSelector extends StatelessWidget {
  const GridSelector({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: const Color(0xFF0C122D), borderRadius: BorderRadius.circular(14),
      border: Border.all(color: seam)),
    child: Row(children: [
      for (final n in [3, 4, 5])
        Expanded(child: Semantics(selected: value == n, button: true, label: '$n by $n grid',
          child: Material(
            color: n == value ? tileIndigo : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onChanged == null ? null : () => onChanged!(n),
              child: SizedBox(height: 48, child: Center(child: Text('$n×$n',
                style: TextStyle(fontSize: 16, fontFeatures: figures, fontWeight: FontWeight.w800,
                  color: n == value ? Colors.white : quiet)))),
            ),
          ),
        )),
    ]),
  );
}

class ArcadeBackdrop extends CustomPainter {
  const ArcadeBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = const RadialGradient(
      center: Alignment(-.75, -.85), radius: 1.4,
      colors: [Color(0xFF25244C), midnight],
    ).createShader(rect));
    final ink = Paint()..color = const Color(0x0C9AAED7);
    for (double y = 12; y < size.height; y += 20) {
      for (double x = 12; x < size.width; x += 20) {
        canvas.drawCircle(Offset(x, y), .85, ink);
      }
    }
  }

  @override
  bool shouldRepaint(ArcadeBackdrop oldDelegate) => false;
}
