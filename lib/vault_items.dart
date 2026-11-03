import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VaultTab {
  skins('✨ Tile Skins'), frames('🖼️ Board Frames'), trails('⚡ FX Trails'), sounds('🎵 Sounds');
  const VaultTab(this.label);
  final String label;
}

class VaultItem {
  const VaultItem(this.id, this.tab, this.name, this.description, this.sample,
      this.top, this.bottom, {this.rarity = '', this.price = 0, this.gems = false});
  final String id, name, description, sample, rarity;
  final Color top, bottom;
  final VaultTab tab;
  final int price;
  final bool gems;
}

const neon = Color(0xFF00E5FF);
const hotPink = Color(0xFFFF299C);
const mint = Color(0xFF00E99C);
const vaultPanel = Color(0xFF171736);
const vaultEdge = Color(0xFF323465);
const paper = Color(0xFFF5F4FF);

const catalog = [
  VaultItem('violet', VaultTab.skins, 'Cyberpunk Violet', 'Deep indigo base with neon cyan edge bevels', '#1',
    Color(0xFF5824DC), Color(0xFF24107B)),
  VaultItem('sunset', VaultTab.skins, 'Synthwave Sunset', 'Sunset gradients with hot gold numerals', '#8',
    Color(0xFFFF3166), Color(0xFFFFA000), rarity: 'Rare', price: 800),
  VaultItem('matrix', VaultTab.skins, 'Matrix Glitch', 'Emerald phosphor glow with CRT scanline FX', '#0',
    Color(0xFF16BD85), Color(0xFF004431), rarity: 'Epic', price: 45, gems: true),
  VaultItem('laser', VaultTab.skins, 'Laser Arcade Blue', 'Electric blue with an ice-blue edge', '#4',
    Color(0xFF1BBEEE), Color(0xFF153D99), rarity: 'Rare', price: 400),
  VaultItem('nova', VaultTab.skins, 'Pink Supernova', 'Hot pink highlights over plum', '#7',
    Color(0xFFDC369F), Color(0xFF4C125F), rarity: 'Epic', price: 65, gems: true),
  VaultItem('carbon', VaultTab.frames, 'Carbon Cabinet', 'Dark bezel with a fine cyan rim', '▣',
    Color(0xFF082533), Color(0xFF080B1A)),
  VaultItem('chrome', VaultTab.frames, 'Violet Chrome', 'A polished violet board surround', '▣',
    Color(0xFF674FD2), Color(0xFF252048), rarity: 'Rare', price: 250),
  VaultItem('gold', VaultTab.frames, 'Gold Circuit', 'Amber trim around the playfield', '▣',
    Color(0xFFBE8B32), Color(0xFF322510), rarity: 'Epic', price: 30, gems: true),
  VaultItem('ion', VaultTab.trails, 'Ion Trail', 'Icy cyan on the leading tile edge', 'ϟ', neon, Color(0xFF116784)),
  VaultItem('pulse', VaultTab.trails, 'Pink Pulse', 'A hot pink flash on landing', 'ϟ',
    hotPink, Color(0xFF5C1567), rarity: 'Rare', price: 200),
  VaultItem('quiet', VaultTab.trails, 'No Trail', 'Clean tile movement without a flash', '·', Colors.transparent, Color(0xFF242840)),
  VaultItem('click', VaultTab.sounds, 'Arcade Click', 'System click on each legal slide', '♫', neon, Color(0xFF18487D)),
  VaultItem('mute', VaultTab.sounds, 'Silent Cabinet', 'Mute tile movement sounds', '♪', Color(0xFF827ABB), Color(0xFF272448)),
];

VaultItem itemFor(String id) => catalog.firstWhere((i) => i.id == id);
const defaults = ['violet', 'carbon', 'ion', 'click'];

class PlayerProgress {
  int coins = 0, gems = 0, xp = 0, streak = 0;
  String lastWin = '';
  final owned = <String>{};
  final equipped = Map.of({for (final id in defaults) itemFor(id).tab.name: id});
  final bestTimes = <String, int>{};
  final dailyClaims = <String, String>{};

  static PlayerProgress read(SharedPreferences prefs) {
    final p = PlayerProgress();
    final raw = prefs.getString('arcade_progress_v1');
    if (raw == null) {
      p.coins = prefs.getInt('coins') ?? 0;
      if (!(prefs.getBool('sound') ?? true)) p.equipped['sounds'] = 'mute';
      return p;
    }
    final m = jsonDecode(raw) as Map<String, dynamic>;
    p.coins = m['coins'] as int;
    p.gems = m['gems'] as int;
    p.xp = m['xp'] as int;
    p.streak = m['streak'] as int;
    p.lastWin = m['lastWin'] as String;
    p.owned.addAll(List<String>.from(m['owned']));
    p.equipped.addAll(Map<String, String>.from(m['equipped']));
    p.bestTimes.addAll(Map<String, int>.from(m['bestTimes']));
    p.dailyClaims.addAll(Map<String, String>.from(m['dailyClaims']));
    return p;
  }

  VaultItem active(VaultTab tab) => itemFor(equipped[tab.name]!);
  bool owns(VaultItem i) => i.price == 0 || owned.contains(i.id);
  bool equip(VaultItem i) {
    if (!owns(i)) {
      if ((i.gems ? gems : coins) < i.price) return false;
      if (i.gems) { gems -= i.price; } else { coins -= i.price; }
      owned.add(i.id);
    }
    equipped[i.tab.name] = i.id;
    return true;
  }

  Future<bool> save(SharedPreferences prefs) => prefs.setString('arcade_progress_v1', jsonEncode({
    'coins': coins, 'gems': gems, 'xp': xp, 'streak': streak, 'lastWin': lastWin, 'owned': owned.toList(),
    'equipped': equipped, 'bestTimes': bestTimes, 'dailyClaims': dailyClaims,
  }));
}

TextStyle chunky(double size, [Color color = paper]) =>
    TextStyle(fontFamily: 'Lilita', fontSize: size, height: 1.08, color: color);

String grouped(int amount) => amount.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

BoxDecoration vaultBox(Color color, {Color edge = vaultEdge, double radius = 14, double width = 1}) =>
    BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), border: Border.all(color: edge, width: width));
