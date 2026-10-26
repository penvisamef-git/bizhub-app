import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../common/shell.dart';
import 'data.dart';
import 'home_page.dart' show BusinessList;

// The "Business" tab: every business of the owner (search, filter by type, add, open) — it was on the dashboard before.
class OwnerBusinessPage extends ConsumerStatefulWidget {
  const OwnerBusinessPage({super.key});
  @override
  ConsumerState<OwnerBusinessPage> createState() => _OwnerBusinessPageState();
}

class _OwnerBusinessPageState extends ConsumerState<OwnerBusinessPage> {
  final _q = TextEditingController();
  String _type = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    ref.invalidate(dashboardProvider);
    try {
      await ref.read(dashboardProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final data = ref.watch(dashboardProvider).valueOrNull;
    final sales = data == null ? null : (data['sales'] is Map ? obj(data['sales']) : null);
    return TabPage(
      onRefresh: _reload,
      children: [BusinessList(list: objs(data?['businesses']), sales: sales, t: t, q: _q, type: _type, onType: (v) => setState(() => _type = v), loading: data == null)],
    );
  }
}
