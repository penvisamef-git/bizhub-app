import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

// Team access (v1.5): the API is bizhub-api/src/biz/team/team.route.js

String? _who(Ref ref) => ref.watch(sessionProvider.select((s) => s?.token));

// GET /api/user/team/shared → { businesses: [{ _id, name, category, logo_url, owner_name, role, member_id, team_on }], invites: [...] }
final sharedProvider = FutureProvider<Json>((ref) async {
  _who(ref);
  return obj((await ref.read(apiProvider).get('${Api.user}/team/shared'))['data']);
});

// GET /api/user/team/my-id → my BizHub ID (made the first time it's asked for); kept in the saved login too
final myIdProvider = FutureProvider<String>((ref) async {
  _who(ref);
  final id = str(obj((await ref.read(apiProvider).get('${Api.user}/team/my-id'))['data'])['bizhub_id']);
  final s = ref.read(sessionProvider);
  if (s != null && id.isNotEmpty && str(s.data['bizhub_id']) != id) await ref.read(sessionProvider.notifier).patch({'bizhub_id': id});
  return id;
});

// GET /api/user/businesses/:id/team (owner) → { business, license, price, members, links }
final teamProvider = FutureProvider.family<Json, String>((ref, id) async {
  _who(ref);
  return obj((await ref.read(apiProvider).get('${Api.user}/businesses/$id/team'))['data']);
});

// businesses I may only look at (a View only member): the screens grey out their buttons (ctx.readOnly), the API
// refuses changes anyway. Set by TeamFrame before the business screen builds.
final _viewOnly = <String>{};
bool teamViewOnly(String id) => _viewOnly.contains(id);
void markTeamViewOnly(String id, bool on) => on ? _viewOnly.add(id) : _viewOnly.remove(id);

// a business someone shared with me (and its Team is on), from the list above
Json? sharedOf(Json? shared, String id) {
  for (final b in objs(shared?['businesses'])) {
    if (str(b['_id']) == id && b['team_on'] == true) return b;
  }
  return null;
}

// the link people open to join: bizhubcambodia.com/app/join/AB12CD (opens the app when it's installed)
String joinUrl(String code) => '${Config.siteUrl}/app/join/$code';

// the code at the end of a pasted link, or the code itself
String? joinCodeOf(String input) {
  final m = RegExp(r'([A-Za-z0-9]{6})\s*/?\s*$').firstMatch(input.trim());
  return m?[1]?.toUpperCase();
}

Color roleBg(BuildContext context, String role) => switch (role) {
  'owner' => context.c.solid,
  'admin' => context.c.active,
  'view' => context.c.limeBg,
  _ => context.c.chip,
};
Color roleFg(BuildContext context, String role) => switch (role) {
  'owner' => context.c.onSolid,
  'admin' => context.c.brandInk,
  'view' => context.c.limeInk,
  _ => context.c.muted,
};
