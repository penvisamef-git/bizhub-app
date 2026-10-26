import 'package:flutter/foundation.dart';

import 'nt_addons.dart';
import 'nt_alerts.dart';
import 'nt_groups.dart';
import 'nt_media.dart';
import 'nt_page.dart' show ntSetSection;
import 'nt_profile.dart';
import 'nt_storage.dart';

// Phase 2a: dashboard sections (groups, storage & plan, media, Telegram alerts, business profile, add-ons).
// Registers its screens with ntSetSection(...). Called once from NotePage.
void ntRegisterSections() {
  ntSetSection('groups', (ctx, nav) => GroupsSection(key: const ValueKey('groups'), ctx: ctx, nav: nav));
  ntSetSection('storage', (ctx, nav) => StorageSection(key: const ValueKey('storage'), ctx: ctx, nav: nav));
  ntSetSection('media', (ctx, nav) => MediaSection(key: const ValueKey('media'), ctx: ctx, nav: nav));
  ntSetSection('alerts', (ctx, nav) => AlertsSection(key: const ValueKey('alerts'), ctx: ctx, nav: nav));
  ntSetSection('profile', (ctx, nav) => ProfileSection(key: const ValueKey('profile'), ctx: ctx, nav: nav));
  ntSetSection('addons', (ctx, nav) => AddonsSection(key: const ValueKey('addons'), ctx: ctx, nav: nav));
}
