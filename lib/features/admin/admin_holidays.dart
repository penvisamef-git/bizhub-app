import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import '../mart/mart_kit.dart' show DayField;
import '../restaurant/rest_common.dart' show SwitchRow;

// Super admin: Cambodia's national holidays of each year — this year free, next year sold (HolidaysAdminPage.jsx)
List<(String, String, String)> _fixedDays(int y) => [
  ('$y-01-01', 'International New Year Day', 'ទិវាចូលឆ្នាំសកល'),
  ('$y-01-07', 'Victory over Genocide Day', 'ទិវាជ័យជម្នះលើរបបប្រល័យពូជសាសន៍'),
  ('$y-03-08', "International Women's Day", 'ទិវានារីអន្តរជាតិ'),
  ('$y-04-14', 'Khmer New Year', 'បុណ្យចូលឆ្នាំខ្មែរ'),
  ('$y-04-15', 'Khmer New Year', 'បុណ្យចូលឆ្នាំខ្មែរ'),
  ('$y-04-16', 'Khmer New Year', 'បុណ្យចូលឆ្នាំខ្មែរ'),
  ('$y-05-01', 'International Labour Day', 'ទិវាពលកម្មអន្តរជាតិ'),
  ('$y-05-14', "King's Birthday", 'ព្រះរាជពិធីបុណ្យចម្រើនព្រះជន្ម ព្រះមហាក្សត្រ'),
  ('$y-06-18', "Queen Mother's Birthday", 'ព្រះរាជពិធីបុណ្យចម្រើនព្រះជន្ម ព្រះវររាជមាតា'),
  ('$y-09-24', 'Constitution Day', 'ទិវាប្រកាសរដ្ឋធម្មនុញ្ញ'),
  ('$y-10-15', 'King Father Commemoration Day', 'ទិវាគោរពព្រះវិញ្ញាណក្ខន្ធ ព្រះបរមរតនកោដ្ឋ'),
  ('$y-10-29', 'Coronation Day', 'ព្រះរាជពិធីគ្រងព្រះបរមរាជសម្បត្តិ'),
  ('$y-11-09', 'Independence Day', 'ពិធីបុណ្យឯករាជ្យជាតិ'),
  ('$y-12-29', 'Peace Day in Cambodia', 'ទិវាសន្តិភាពនៅកម្ពុជា'),
];

class _Day {
  String day;
  final TextEditingController name, km;
  _Day(this.day, String n, String k) : name = TextEditingController(text: n), km = TextEditingController(text: k);
}

class AdminHolidaysPage extends ConsumerStatefulWidget {
  const AdminHolidaysPage({super.key});
  @override
  ConsumerState<AdminHolidaysPage> createState() => _AdminHolidaysPageState();
}

class _AdminHolidaysPageState extends ConsumerState<AdminHolidaysPage> {
  List<Json>? _years;
  int _thisYear = DateTime.now().year;
  int? _year;
  List<_Day> _days = [];
  bool _official = false, _saving = false;
  String _error = '';
  final _yearsScroll = ScrollController();

  @override
  void dispose() {
    _yearsScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load(first: true);
  }

  Future<void> _load({bool first = false}) async {
    try {
      final r = await ref.read(apiProvider).get('${Api.admin}/holiday-years');
      setState(() {
        _years = objs(r['data']);
        _thisYear = n(r['this_year']).toInt();
        if (first || _year == null) _year = _thisYear + 1;
        _error = '';
      });
      if (first) {
        _pick(_year!);
        // show the chosen year (next year is on the right)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final i = _years!.indexWhere((x) => n(x['year']) == _year);
          if (i > 0 && _yearsScroll.hasClients) _yearsScroll.jumpTo((i * 160.0 - 80).clamp(0, _yearsScroll.position.maxScrollExtent));
        });
      }
    } on ApiError catch (e) {
      setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : e.message);
    }
  }

  void _pick(int y) {
    final info = _years?.where((x) => n(x['year']) == y).firstOrNull ?? const {};
    setState(() {
      _year = y;
      _days = [for (final d in objs(info['days'])) _Day(str(d['day']), str(d['name']), str(d['km']))];
      _official = info['official'] == true;
    });
  }

  void _addFixed() {
    final have = {for (final d in _days) d.day};
    setState(() {
      _days = [
        ..._days,
        for (final f in _fixedDays(_year!))
          if (!have.contains(f.$1)) _Day(f.$1, f.$2, f.$3),
      ]..sort((a, b) => a.day.compareTo(b.day));
    });
  }

  Future<void> _save() async {
    final t = ref.read(tProvider);
    setState(() => _saving = true);
    try {
      final r = await ref.read(apiProvider).put('${Api.admin}/holiday-years/$_year', {
        'days': [
          for (final d in _days)
            if (d.day.isNotEmpty || d.name.text.trim().isNotEmpty) {'day': d.day, 'name': d.name.text.trim(), 'km': d.km.text.trim()},
        ],
        'official': _official,
      });
      if (mounted) toast(context, t('ah.saved', {'n': r['synced'] ?? 0}));
      await _load();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    String status(Json y) => y['free'] == true ? (n(y['year']) == _thisYear ? 'free' : 'past') : (y['sellable'] == true ? 'onSale' : 'notYet');
    final info = _years?.where((x) => n(x['year']) == _year).firstOrNull ?? const <String, dynamic>{};
    return SubPage(
      title: t('messages.navHolidays'),
      onRefresh: _load,
      bottom: _years == null ? null : Btn(_saving ? t('ah.saving') : t('ah.save'), icon: LucideIcons.save, busy: _saving, expand: true, onTap: _save),
      children: [
        Muted(t('ah.sub')),
        const SizedBox(height: 14),
        if (_error.isNotEmpty) Alert(_error),
        if (_years == null && _error.isEmpty) const Panel(child: SkelList()),
        if (_years != null) ...[
          SizedBox(
            height: 112,
            child: ListView(
              controller: _yearsScroll,
              scrollDirection: Axis.horizontal,
              children: [
                for (final y in _years!)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => _pick(n(y['year']).toInt()),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 150,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: n(y['year']) == _year ? c.active : c.card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: n(y['year']) == _year ? c.brand : c.line, width: n(y['year']) == _year ? 1.6 : 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('${y['year']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                const Spacer(),
                                if (y['official'] == true) Icon(LucideIcons.badgeCheck, size: 16, color: c.good),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Chip2(
                              t('ah.${status(y)}'),
                              tone: switch (status(y)) {
                                'free' => Tone.good,
                                'onSale' => Tone.brand,
                                'past' => Tone.muted,
                                _ => Tone.warn,
                              },
                            ),
                            const Spacer(),
                            Text(
                              '${t('ah.days', {'n': objs(y['days']).length})}${y['free'] == true ? '' : ' · ${t('ah.buyers', {'n': y['buyers'] ?? 0})}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Panel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.calendarHeart, color: c.brandInk),
                    const SizedBox(width: 8),
                    Text('$_year', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(width: 10),
                    Chip2(info['official'] == true ? t('ah.official') : t('ah.draft'), tone: info['official'] == true ? Tone.good : Tone.muted),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 4),
                Muted(t('ah.using', {'n': info['using'] ?? 0})),
                const SizedBox(height: 12),
                if (_days.isEmpty) Muted(t('ah.empty')),
                for (var i = 0; i < _days.length; i++) _row(i, t, c),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Btn(t('ah.addRow'), icon: LucideIcons.plus, kind: BtnKind.ghost, small: true, onTap: () => setState(() => _days.add(_Day('', '', '')))),
                    Btn(t('ah.fixed'), icon: LucideIcons.calendarPlus, kind: BtnKind.ghost, small: true, onTap: _addFixed),
                  ],
                ),
                const SizedBox(height: 8),
                Text(t('ah.fixedHint'), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                SwitchRow(title: t('ah.isOfficial'), sub: t('ah.officialHint'), value: _official, onChanged: (v) => setState(() => _official = v)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(int i, dynamic t, C c) {
    final d = _days[i];
    return Container(
      key: ObjectKey(d),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg2.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DayField(value: d.day, onChanged: (v) => setState(() => d.day = v), first: DateTime(_year!), last: DateTime(_year!, 12, 31), hint: t('ah.date')),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _days.removeAt(i)),
                tooltip: t('ah.remove'),
                icon: Icon(LucideIcons.trash2, size: 18, color: c.danger),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Field(controller: d.name, hint: t('ah.en'), maxLength: 80),
          const SizedBox(height: 8),
          Field(controller: d.km, hint: t('ah.km'), maxLength: 120),
        ],
      ),
    );
  }
}
