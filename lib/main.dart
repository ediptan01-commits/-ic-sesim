import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IcSesimApp());
}

const brand = Color(0xFF7857BA);
const paper = Color(0xFFFAF8FD);
const areas = ['Ruhsal denge', 'İş ve kariyer', 'Aile ve ilişkiler', 'Özgüven', 'Alışkanlıklar'];
const moodNames = ['Zorlanıyorum', 'Kaygılıyım', 'İdare eder', 'İyiyim', 'Harikayım'];
const moodFaces = ['😔', '😟', '😐', '🙂', '😄'];
const areaIcons = <IconData>[Icons.spa_outlined, Icons.work_outline, Icons.people_outline, Icons.auto_awesome_outlined, Icons.repeat_outlined];
const encouragement = [
  'Zor zamanlarda kendine anlayış göstermeyi unutma. Bugün düşüncelerini günlüğüne yazabilirsin.',
  'Bir nefes molası ver. İstersen bugün sadece küçük bir adıma odaklan.',
  'Her gün mükemmel geçmek zorunda değil. Küçük bir adım yeterli.',
  'İyi hissettiren bir anı yazmak ister misin?',
  'Enerjin yüksek! Kendine anlamlı ve ulaşılabilir bir hedef seçebilirsin.'
];
String dateKey() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
String dateLabel(String value) {
  final d = DateTime.tryParse(value);
  if (d == null) return value;
  return '${d.day}.${d.month}.${d.year}';
}

class IcSesimApp extends StatelessWidget {
  const IcSesimApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'İç Sesim',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: brand, surface: paper),
      scaffoldBackgroundColor: paper,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(backgroundColor: paper),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    home: const RootScreen(),
  );
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  SharedPreferences? store;
  bool loading = true;
  bool onboarded = false;
  String user = '';
  String area = areas.first;
  int tab = 0;
  int mood = 3;
  List<Map<String, dynamic>> moods = [];
  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> goals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _list(String? raw) {
    if (raw == null) return [];
    try {
      final parsed = jsonDecode(raw) as List<dynamic>;
      return parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      store = p;
      user = p.getString('user') ?? '';
      onboarded = p.getBool('onboarded') ?? false;
      area = p.getString('area') ?? areas.first;
      if (!areas.contains(area)) area = areas.first;
      moods = _list(p.getString('moods'));
      notes = _list(p.getString('notes'));
      goals = _list(p.getString('goals'));
      final today = moods.where((e) => e['date'] == dateKey());
      if (today.isNotEmpty) mood = (today.last['mood'] as num).toInt().clamp(0, 4);
      loading = false;
    });
  }

  Future<void> _save() async {
    final p = store;
    if (p == null) return;
    await Future.wait([
      p.setString('moods', jsonEncode(moods)),
      p.setString('notes', jsonEncode(notes)),
      p.setString('goals', jsonEncode(goals)),
      p.setString('area', area),
      p.setString('user', user),
      p.setBool('onboarded', onboarded),
    ]);
  }

  void _finish(String value) {
    setState(() {
      user = value.trim();
      onboarded = true;
    });
    _save();
  }

  void _recordMood(int value) {
    setState(() {
      mood = value;
      moods.removeWhere((e) => e['date'] == dateKey());
      moods.add({'date': dateKey(), 'mood': value});
    });
    _save();
  }

  void _addNote(String value) {
    final s = value.trim();
    if (s.isEmpty) return;
    setState(() => notes.insert(0, {'text': s, 'date': DateTime.now().toIso8601String()}));
    _save();
  }

  void _addGoal(String value, String chosenArea) {
    final s = value.trim();
    if (s.isEmpty) return;
    setState(() => goals.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': s, 'area': chosenArea, 'done': false
    }));
    _save();
  }

  Future<void> _askNote() async {
    final ctl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Günlüğüme yaz'),
        content: TextField(
          controller: ctl, maxLines: 5, maxLength: 2000,
          decoration: const InputDecoration(hintText: 'Bugün neler hissettin?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('Kaydet')),
        ],
      ),
    );
    if (value != null) _addNote(value);
    ctl.dispose();
  }

  Future<void> _askGoal() async {
    final ctl = TextEditingController();
    String chosen = area;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, refresh) => AlertDialog(
          title: const Text('Yeni hedef'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctl, maxLength: 140,
              decoration: const InputDecoration(labelText: 'Hedefim')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: chosen,
              isExpanded: true,
              items: areas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
              onChanged: (v) { if (v != null) refresh(() => chosen = v); },
              decoration: const InputDecoration(labelText: 'Yaşam alanı'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(c, {'title': ctl.text, 'area': chosen}),
              child: const Text('Ekle')),
          ],
        ),
      ),
    );
    if (result != null) _addGoal(result['title'] ?? '', result['area'] ?? area);
    ctl.dispose();
  }

  Widget _panel(Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );

  Widget _heading(String title, {String? subtitle}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
      if (subtitle != null) Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
      )
    ]),
  );

  Widget _welcome() {
    final ctl = TextEditingController();
    return Scaffold(
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Color(0xFFF0E8FA), shape: BoxShape.circle),
            child: const Icon(Icons.favorite_outline, color: brand, size: 64)),
          const SizedBox(height: 22),
          const Text('Kendine ait bir alan',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text('İç Sesim; duygularını takip edebileceğin, günlük tutabileceğin ve küçük hedeflerine odaklanabileceğin dijital yol arkadaşın.',
            textAlign: TextAlign.center, style: TextStyle(height: 1.5)),
          const SizedBox(height: 25),
          TextField(controller: ctl, maxLength: 40,
            decoration: const InputDecoration(labelText: 'Sana nasıl hitap edelim? (isteğe bağlı)')),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () => _finish(ctl.text),
            child: const Padding(padding: EdgeInsets.all(14), child: Text('Devam et')),
          )),
          const SizedBox(height: 20),
          Text('Bu uygulama terapi veya psikolojik teşhis hizmeti değildir. Acil tehlike durumunda 112’yi ara.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700), textAlign: TextAlign.center),
        ]),
      )),
    );
  }

  Widget _home() {
    final count = goals.where((g) => g['done'] == true).length;
    return ListView(padding: const EdgeInsets.all(18), children: [
      _heading('Merhaba${user.isEmpty ? '' : ', $user'} ☀️',
        subtitle: 'Bugün kendini nasıl hissediyorsun?'),
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ruh halim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 15),
        Row(children: List.generate(5, (i) => Expanded(child: InkWell(
          onTap: () => _recordMood(i),
          child: Container(margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: mood == i ? const Color(0xFFEFE6FA) : paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: mood == i ? brand : Colors.transparent),
            ),
            child: Column(children: [
              Text(moodFaces[i], style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 5),
              Text(moodNames[i].split(' ').first, style: const TextStyle(fontSize: 9),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        )))),
        const SizedBox(height: 18),
        Text(encouragement[mood], style: const TextStyle(height: 1.4)),
      ])),
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.auto_awesome, color: brand), SizedBox(width: 8),
          Text('Bugünün küçük adımı', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 12),
        const Text('Kendin için iyi gelecek tek bir şey belirle. Küçük adımlar da ilerlemedir.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _askGoal, icon: const Icon(Icons.add),
          label: const Text('Bir hedef belirle')),
      ])),
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Yolculuğum', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text('${moods.length} ruh hali kaydı  •  ${notes.length} günlük  •  $count tamamlanan hedef'),
      ])),
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Dijital arkadaşım', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Yapay zekâ sohbeti v0.2 sürümünde eklenecek. Şimdilik düşüncelerini güvenli biçimde günlüğüne yazabilirsin.'),
        TextButton.icon(onPressed: () => setState(() => tab = 1),
          icon: const Icon(Icons.book_outlined), label: const Text('Günlüğümü aç')),
      ])),
    ]);
  }

  Widget _journal() => ListView(padding: const EdgeInsets.all(18), children: [
    _heading('Günlüğüm', subtitle: 'Duygularına ve düşüncelerine kendin için yer aç.'),
    FilledButton.icon(onPressed: _askNote, icon: const Icon(Icons.edit_outlined),
      label: const Text('Yeni günlük kaydı')),
    const SizedBox(height: 16),
    if (notes.isEmpty) _panel(const Text('Henüz günlük kaydın yok. İlk notunu yazarak başlayabilirsin.')),
    for (final n in notes) _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(dateLabel(n['date']?.toString() ?? ''),
          style: const TextStyle(color: brand, fontWeight: FontWeight.bold))),
        IconButton(tooltip: 'Kaydı sil', icon: const Icon(Icons.delete_outline),
          onPressed: () { setState(() => notes.remove(n)); _save(); }),
      ]),
      const SizedBox(height: 7),
      Text(n['text']?.toString() ?? ''),
    ])),
  ]);

  Widget _goals() => ListView(padding: const EdgeInsets.all(18), children: [
    _heading('Hedeflerim', subtitle: 'Küçük adımlar, anlamlı ilerleme.'),
    FilledButton.icon(onPressed: _askGoal, icon: const Icon(Icons.add), label: const Text('Yeni hedef ekle')),
    const SizedBox(height: 16),
    if (goals.isEmpty) _panel(const Text('Henüz hedef eklemedin. Kendin için küçük bir başlangıç yap.')),
    for (final g in goals) _panel(Row(children: [
      Checkbox(value: g['done'] == true, onChanged: (v) {
        setState(() => g['done'] = v ?? false);
        _save();
      }),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(g['title']?.toString() ?? '', style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: g['done'] == true ? TextDecoration.lineThrough : null,
        )),
        Text(g['area']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: brand)),
      ])),
      IconButton(tooltip: 'Hedefi sil', icon: const Icon(Icons.delete_outline),
        onPressed: () { setState(() => goals.remove(g)); _save(); }),
    ])),
  ]);

  Widget _compass() => ListView(padding: const EdgeInsets.all(18), children: [
    _heading('Yaşam Pusulası', subtitle: 'Şu anda hayatının hangi alanına odaklanmak istersin?'),
    ...List.generate(areas.length, (i) {
      final a = areas[i];
      final selected = area == a;
      final count = goals.where((g) => g['area'] == a && g['done'] == true).length;
      return Card(
        margin: const EdgeInsets.only(bottom: 12), color: selected ? const Color(0xFFEFE6FA) : Colors.white,
        elevation: 0, child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          leading: Icon(areaIcons[i], color: brand, size: 30),
          title: Text(a, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('$count tamamlanan hedef'),
          trailing: Icon(selected ? Icons.check_circle : Icons.chevron_right, color: brand),
          onTap: () { setState(() => area = a); _save(); },
        ),
      );
    }),
    _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Odak alanım: $area', style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Buraya bir hedef ekleyerek kendi yolculuğunu başlatabilirsin.'),
      TextButton.icon(onPressed: _askGoal, icon: const Icon(Icons.add), label: const Text('Hedef ekle')),
    ])),
  ]);

  Future<void> _clear() async {
    final agreed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Kayıtları sil?'),
      content: const Text('Günlüklerin, ruh hali kayıtların ve hedeflerin silinecek. Bu işlem geri alınamaz.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
      ],
    ));
    if (agreed != true) return;
    setState(() { moods.clear(); notes.clear(); goals.clear(); mood = 3; });
    await _save();
  }

  Widget _profile() => ListView(padding: const EdgeInsets.all(18), children: [
    _heading('Benim alanım', subtitle: 'Kayıtların ve kişisel tercihlerinin kontrolü sende.'),
    _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Gizlilik', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Text('Bu sürümde bilgiler yalnızca cihazda saklanır. Hesap ya da sunucu bağlantısı yoktur. Telefonunu paylaşan kişiler cihaz verilerine erişebilir.'),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _clear, icon: const Icon(Icons.delete_forever_outlined),
        label: const Text('Kayıtlarımı sil')),
    ])),
    _panel(const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Önemli bilgilendirme', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 10),
      Text('İç Sesim bir psikolog değildir; teşhis veya terapi sunmaz. Acil durumlarda 112’yi ara, gerektiğinde uzman desteği al.'),
    ])),
    const Center(child: Text('İç Sesim v0.1.0', style: TextStyle(color: Colors.grey))),
  ]);

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!onboarded) return _welcome();
    final pages = [_home(), _journal(), _goals(), _compass(), _profile()];
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.favorite_rounded, color: brand),
          SizedBox(width: 8),
          Text('İç Sesim', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Ana sayfa'),
          NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'Günlük'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Hedefler'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Pusula'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Benim'),
        ],
      ),
    );
  }
}
