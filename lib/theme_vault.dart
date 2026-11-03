import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'vault_items.dart';

class ArcadeNav extends StatelessWidget {
  const ArcadeNav({super.key, required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;
  static const labels = ['Play', 'Events', 'Shop', 'Friends', 'Quests'];
  static const icons = ['🎮', '🏆', '🛍️', '👥', '🎯'];

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 4, 12, 6), padding: const EdgeInsets.all(4),
    decoration: vaultBox(const Color(0xFF151535), radius: 17),
    child: Row(children: List.generate(labels.length, (i) {
      final active = selected == i;
      return Expanded(child: Semantics(selected: active, button: true, label: labels[i],
        child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => onSelect(i),
          child: Container(height: 48, alignment: Alignment.center,
            decoration: active ? vaultBox(const Color(0xFF102C48), edge: const Color(0xFF08617C), radius: 12) : null,
            child: ExcludeSemantics(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(icons[i], style: const TextStyle(fontSize: 17)), const SizedBox(height: 2),
              Text(labels[i].toUpperCase(), style: chunky(10, active ? neon : const Color(0xFFA8A8C6))),
            ]))))));
    })));

}

class ThemeVault extends StatefulWidget {
  const ThemeVault({super.key, required this.progress, required this.onEquip,
    required this.onPreview, required this.onClose, this.initial});
  final PlayerProgress progress;
  final VaultItem? initial;
  final bool Function(VaultItem) onEquip;
  final ValueChanged<VaultItem> onPreview;
  final VoidCallback onClose;
  @override
  State<ThemeVault> createState() => _ThemeVaultState();
}

class _ThemeVaultState extends State<ThemeVault> {
  late VaultItem selected = widget.initial ?? widget.progress.active(VaultTab.skins);
  final scroll = ScrollController();
  @override
  void dispose() { scroll.dispose(); super.dispose(); }

  Future<void> _equip() async {
    final item = selected;
    if (!widget.progress.owns(item)) {
      final currency = item.gems ? 'gems' : 'coins';
      if ((item.gems ? widget.progress.gems : widget.progress.coins) < item.price) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You need ${item.price} $currency for ${item.name}.')));
        return;
      }
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text('Unlock ${item.name}?'), content: Text('Spend ${item.price} $currency and equip it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unlock & Equip')),
        ]));
      if (ok != true || !mounted) return;
    }
    if (widget.onEquip(item)) setState(() {});
  }

  Widget _wallet() => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: vaultBox(const Color(0xFF08091B), radius: 20),
    child: Text.rich(TextSpan(children: [
      TextSpan(text: '🪙  ${grouped(widget.progress.coins)}', style: chunky(11, const Color(0xFFFFC426))),
      const TextSpan(text: '  |  ', style: TextStyle(color: vaultEdge)),
      TextSpan(text: '💎  ${grouped(widget.progress.gems)}', style: chunky(11, neon)),
    ])));

  Widget _tabs() => SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
    for (final t in VaultTab.values) Padding(padding: const EdgeInsets.only(right: 6),
      child: Semantics(selected: selected.tab == t, button: true, child: InkWell(
        onTap: () { setState(() => selected = widget.progress.active(t)); if (scroll.hasClients) scroll.jumpTo(0); },
        child: Container(alignment: Alignment.center, constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: selected.tab == t
            ? BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: const LinearGradient(
                colors: [Color(0xFF9829C2), hotPink]), border: Border.all(color: const Color(0xFFFE67BB)))
            : vaultBox(vaultPanel, radius: 8),
          child: Text(t.label, style: chunky(12, selected.tab == t ? paper : const Color(0xFFBABAD4))),
        )))),
  ]));

  Widget _preview(double width) {
    final skin = selected.tab == VaultTab.skins ? selected : widget.progress.active(VaultTab.skins);
    final frame = selected.tab == VaultTab.frames ? selected : widget.progress.active(VaultTab.frames);
    final trail = selected.tab == VaultTab.trails ? selected : widget.progress.active(VaultTab.trails);
    return Container(padding: const EdgeInsets.all(10),
      decoration: vaultBox(const Color(0xFF0C0D23), radius: 17),
      child: Column(children: [
        Row(children: [
          Text('●  LIVE PREVIEW', style: chunky(11, mint)), const Spacer(), const SizedBox(width: 4),
          Flexible(flex: 15, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: vaultBox(vaultPanel, radius: 16),
            child: Text('Selected: ${selected.name}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: chunky(10, neon)))),
        ]),
        const SizedBox(height: 10),
        Container(width: math.min(width * .56, 192), padding: const EdgeInsets.all(7),
          decoration: vaultBox(frame.bottom, edge: frame.id == 'carbon' ? const Color(0xFF095B70) : frame.top, radius: 12),
          child: AspectRatio(aspectRatio: 1, child: GridView.count(primary: false, padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, mainAxisSpacing: 5, crossAxisSpacing: 5,
            children: List.generate(9, (i) {
              if (i == 8) {
                return CustomPaint(painter: SlotOutline(trail.top), child: Center(
                  child: Text('✦', style: chunky(15, trail.top.withValues(alpha: .4)))));
              }
              return DecoratedBox(decoration: tileFinish(skin), child: CustomPaint(
                foregroundPainter: skin.id == 'matrix' ? const Scanlines() : null,
                child: Center(child: Text('${i+1}', style: chunky(16, skin.id == 'sunset' ? const Color(0xFFFFE4A0) : paper)))));
            }))),
        ),
      ]),
    );
  }

  Widget _card(VaultItem item) {
    final equipped = widget.progress.active(item.tab).id == item.id;
    final picked = item.id == selected.id;
    final owned = widget.progress.owns(item);
    final badge = equipped ? 'EQUIPPED' : item.rarity;
    final color = equipped ? neon : item.gems ? mint : const Color(0xFFFFC857);
    return Padding(padding: const EdgeInsets.only(top: 8), child: InkWell(
      onTap: () => setState(() => selected = item),
      child: Container(padding: const EdgeInsets.all(9),
        decoration: vaultBox(picked ? const Color(0xFF1D1D41) : vaultPanel,
          edge: picked ? neon : vaultEdge, radius: 17, width: picked ? 2 : 1),
        child: Row(children: [
          Container(width: 44, height: 44, alignment: Alignment.center, decoration: tileFinish(item),
            child: Text(item.sample, style: chunky(18, item.id == 'violet' ? neon : paper))),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 5, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(item.name, style: chunky(14)),
              if (badge.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: vaultBox(color.withValues(alpha: .13), edge: color.withValues(alpha: .55), radius: 4),
                child: Text(badge, style: chunky(9, color))),
            ]),
            const SizedBox(height: 3), Text(item.description, style: const TextStyle(fontSize: 11, height: 1.14, color: Color(0xFFD5D7E9))),
          ])),
          const SizedBox(width: 5),
          InkWell(onTap: () { setState(() => selected = item); if (!equipped) _equip(); },
            child: Container(constraints: const BoxConstraints(minHeight: 34), alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: vaultBox(owned ? const Color(0xFF0D1028) : item.gems ? mint : const Color(0xFFBD20C2),
                edge: owned ? const Color(0xFF087089) : Colors.transparent, radius: 12),
              child: Text(equipped ? 'In Use' : owned ? 'Equip' : '${item.gems ? "💎" : "🪙"} ${item.price}',
                style: chunky(11, owned ? neon : item.gems ? vaultPanel : paper)))),
        ]))));
  }

  @override
  Widget build(BuildContext context) {
    final items = catalog.where((item) => item.tab == selected.tab).toList();
    final noun = ['SKINS', 'FRAMES', 'TRAILS', 'SOUNDS'][selected.tab.index];
    return ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: ColoredBox(color: const Color(0xCC02020A), child: SafeArea(child: LayoutBuilder(builder: (context, bounds) {
        final width = math.min(bounds.maxWidth - 16, 460.0);
        final height = math.min(bounds.maxHeight, math.min(width * 1.95, bounds.maxHeight * (bounds.maxHeight < 620 ? .97 : .86)));
        return Align(alignment: Alignment.bottomCenter, child: Container(width: width, height: height,
          clipBehavior: Clip.antiAlias,
          decoration: vaultBox(const Color(0xFF141532), edge: const Color(0xFF136178), radius: 22, width: 2),
          child: Column(children: [
            Container(color: vaultPanel, padding: const EdgeInsets.fromLTRB(12, 8, 6, 0), child: Row(children: [
              Container(width: 32, height: 32, alignment: Alignment.center, decoration: vaultBox(const Color(0xFF101428), edge: hotPink, radius: 10),
                child: const Text('🎨', style: TextStyle(fontSize: 17))),
              const SizedBox(width: 6), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ShaderMask(shaderCallback: (r) => const LinearGradient(colors: [paper, paper, neon]).createShader(r),
                  child: Text('THEME VAULT', style: chunky(15))), const Text('Personalize Tile FX & Glow', style: TextStyle(color: Color(0xFFB6B8D0), fontSize: 10)),
              ])), _wallet(),
              IconButton(tooltip: 'Close vault', onPressed: widget.onClose, icon: const Icon(Icons.close, size: 19)),
            ])),
            Container(width: double.infinity, color: vaultPanel, padding: const EdgeInsets.fromLTRB(12, 6, 6, 9), child: _tabs()),
            const Divider(height: 1, color: vaultEdge),
            Expanded(child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(12, 12, 12, 10), children: [
              _preview(width),
              Padding(padding: const EdgeInsets.only(top: 15), child: Row(children: [
                Expanded(child: Text('FEATURED $noun', style: chunky(13))),
                Text('${items.length} Items Available', style: chunky(11, hotPink)),
              ])),
              for (final item in items) _card(item),
            ])),
            const Divider(height: 1, color: vaultEdge),
            Padding(padding: const EdgeInsets.all(9), child: Row(children: [
              Expanded(child: VaultButton('Preview on Board', () => widget.onPreview(selected))),
              const SizedBox(width: 7), Expanded(child: VaultButton('Equip Theme ✓', _equip, bright: true)),
            ])),
          ]),
        ));
      })))));
  }
}

BoxDecoration tileFinish(VaultItem item) => BoxDecoration(
  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [item.top, item.bottom]),
  borderRadius: BorderRadius.circular(9), border: Border(top: BorderSide(color: item.tab == VaultTab.skins ? neon : item.top)));

class SlotOutline extends CustomPainter {
  const SlotOutline(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(1.5), const Radius.circular(8)));
    final ink = Paint()..color = color.withValues(alpha: .45)..style = PaintingStyle.stroke..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      for (double t = 0; t < metric.length; t += 10) {
        canvas.drawPath(metric.extractPath(t, t + 6), ink);
      }
    }
  }
  @override
  bool shouldRepaint(SlotOutline old) => old.color != color;
}

class VaultButton extends StatelessWidget {
  const VaultButton(this.label, this.tap, {super.key, this.bright = false});
  final String label;
  final VoidCallback tap;
  final bool bright;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent, child: Ink(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(colors: bright ? [neon, const Color(0xFF285CEB)] : [const Color(0xFF23244C), const Color(0xFF1A1B41)]),
        border: Border.all(color: bright ? neon.withValues(alpha: .3) : vaultEdge)),
      child: InkWell(onTap: tap, borderRadius: BorderRadius.circular(12), child: Container(
        constraints: const BoxConstraints(minHeight: 42), alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Text(label, textAlign: TextAlign.center, style: chunky(13, bright ? const Color(0xFF070B20) : paper))))));
}

class Scanlines extends CustomPainter {
  const Scanlines();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(9)));
    final ink = Paint()..color = const Color(0x2200110C);
    for (double y = 3; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), ink);
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(Scanlines old) => false;
}
