import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

// Shared pieces of the restaurant screens (the web's dashboard/client/restaurant/parts.jsx + text.js helpers).

// what every section gets from the restaurant page (the web's `ctx`)
class RestCtx {
  final String id;
  final Api api;
  final T t;
  final Json settings;
  final Json overview; // { business, setup, license, addons, limits, renew_price }
  final void Function(Json settings, [Json? setup]) setSettings;
  final Future<void> Function() reload;
  final void Function(String key) askBuy; // add-on key or "restaurant" (renew)
  final void Function(String tab) go;
  final void Function(String text) notify;
  final void Function(int unread)? setUnread; // website inbox badge
  const RestCtx({
    required this.id,
    required this.api,
    required this.t,
    required this.settings,
    required this.overview,
    required this.setSettings,
    required this.reload,
    required this.askBuy,
    required this.go,
    required this.notify,
    this.setUnread,
  });

  String get base => '${Api.user}/businesses/$id/restaurant';
  String get lang => t.lang;
  Json get license => obj(overview['license']);
  Json get limits => obj(overview['limits']);
  bool get readOnly => obj(overview['business'])['status'] == false || license['locked'] == true;
  List<Json> get addons => objs(overview['addons']);
  Json addon(String key) => addons.firstWhere((a) => a['key'] == key, orElse: () => {});
  bool addonOn(String key) => addon(key)['active'] == true;
  String get currency => str(settings['currency']).isEmpty ? 'USD' : str(settings['currency']);
  String r(String key, [Map<String, Object?> vars = const {}]) => t('rest.$key', vars);

  // API error → the web's words ("in use" when something still uses it); 402 = needs an add-on
  void fail(Object e) {
    if (e is ApiError && e.status == 402 && e.body['product'] != null) return askBuy(str(e.body['product']));
    if (e is ApiError) return notify(e.network ? t('app.offline') : (e.status == 409 ? r('inUse') : e.message));
    notify('$e');
  }
}

// name in the app language, the other one if empty (nameOf on the web)
String nameOf(Map x, String lang) {
  final km = str(x['name_km']), en = str(x['name_en']);
  final v = lang == 'km' ? (km.isNotEmpty ? km : en) : (en.isNotEmpty ? en : km);
  return v.isEmpty ? '—' : v;
}

String fmtMoney(num v, [String currency = 'USD']) => currency == 'KHR' ? '${fmt(v.round())}៛' : '\$${v.toStringAsFixed(2)}';
num toKhr(num usd, num rate, [num rounding = 100]) => ((usd * rate) / rounding).round() * rounding;

// ------------------------------------------------------------------------------------------- widgets
// title + small grey text on top of a card
class RestHead extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? trailing;
  const RestHead(this.title, {super.key, this.sub, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (sub != null && sub!.isNotEmpty) ...[const SizedBox(height: 4), Muted(sub!)],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    ),
  );
}

// a few choices side by side (the web's radio "Choice")
class Segmented<V> extends StatelessWidget {
  final V value;
  final List<(V, String)> options;
  final ValueChanged<V>? onChanged;
  const Segmented({super.key, required this.value, required this.options, this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // inside a Row (no width limit) the buttons take their own size; otherwise they share the width
    return LayoutBuilder(
      builder: (context, box) {
        final fill = box.maxWidth.isFinite;
        Widget item(V v, String label) => GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(vertical: 11, horizontal: fill ? 6 : 14),
            decoration: BoxDecoration(color: v == value ? c.card : Colors.transparent, borderRadius: BorderRadius.circular(11), boxShadow: v == value ? c.cardShadow : null),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: v == value ? c.ink : c.muted),
            ),
          ),
        );
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
          child: Row(
            mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
            children: [for (final (v, label) in options) fill ? Expanded(child: item(v, label)) : item(v, label)],
          ),
        );
      },
    );
  }
}

// a select box: shows the chosen label, opens a list sheet
class SelectField<V> extends StatelessWidget {
  final String? label;
  final V value;
  final List<(V, String)> options;
  final ValueChanged<V>? onChanged;
  final String? hint;
  const SelectField({super.key, this.label, required this.value, required this.options, this.onChanged, this.hint});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final current = options.where((o) => o.$1 == value).map((o) => o.$2).firstOrNull ?? '';
    final box = InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onChanged == null
          ? null
          : () async {
              final picked = await showModalBottomSheet<(V,)>(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => SafeArea(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .7),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        if (label != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                            child: Text(label!, style: Theme.of(ctx).textTheme.titleMedium),
                          ),
                        for (final (v, l) in options)
                          ListTile(
                            title: Text(l, style: TextStyle(fontWeight: v == value ? FontWeight.w800 : FontWeight.w500)),
                            trailing: v == value ? Icon(LucideIcons.check, color: c.brand) : null,
                            onTap: () => Navigator.pop(ctx, (v,)),
                          ),
                      ],
                    ),
                  ),
                ),
              );
              if (picked != null) onChanged!(picked.$1);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                current,
                style: TextStyle(fontSize: 16, color: onChanged == null ? c.muted : c.ink, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 18, color: c.muted),
          ],
        ),
      ),
    );
    if (label == null) return box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            label!,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: c.ink),
          ),
        ),
        box,
        if (hint != null && hint!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Muted(hint!)),
      ],
    );
  }
}

// a switch with a title (+ small text)
class SwitchRow extends StatelessWidget {
  final String title;
  final String? sub;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const SwitchRow({super.key, required this.title, this.sub, required this.value, this.onChanged});
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    value: value,
    onChanged: onChanged,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: sub == null ? null : Text(sub!, style: TextStyle(color: context.c.muted, fontSize: 12.5)),
  );
}

// "Unsaved changes · undo · Save" at the bottom (SaveBar on the web)
class RestSaveBar extends StatelessWidget {
  final bool dirty, saving, disabled;
  final VoidCallback onSave, onUndo;
  final RestCtx ctx;
  const RestSaveBar({super.key, required this.ctx, required this.dirty, required this.saving, required this.onSave, required this.onUndo, this.disabled = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Icon(dirty ? LucideIcons.pencil : LucideIcons.check, size: 16, color: dirty ? c.brandInk : c.good),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dirty ? ctx.r('unsaved') : ctx.r('allSaved'),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: dirty ? c.ink : c.muted),
                ),
              ),
              if (dirty) ...[RoundBtn(LucideIcons.rotateCcw, size: 40, tip: ctx.r('cancel'), onTap: saving ? null : onUndo), const SizedBox(width: 8)],
              Btn(saving ? ctx.r('saving') : ctx.r('save'), small: true, busy: saving, onTap: dirty && !saving && !disabled ? onSave : null),
            ],
          ),
        ),
      ),
    );
  }
}

// "This needs an add-on" with a buy button (AddonPrompt on the web)
class AddonPrompt extends StatelessWidget {
  final RestCtx ctx;
  final String addonKey;
  final String? title, sub;
  const AddonPrompt({super.key, required this.ctx, required this.addonKey, this.title, this.sub});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon(addonKey);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: [const Color(0xFFFFC53D).withValues(alpha: .16), c.brand.withValues(alpha: .06)]),
        border: Border.all(color: const Color(0xFFFFC53D).withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xFFFFC53D), borderRadius: BorderRadius.circular(13)),
                child: Icon(addonIcon(addonKey), size: 20, color: const Color(0xFF5B3A00)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title ?? ctx.r('lockedFeature', {'name': ctx.r('addonNames.$addonKey')}), style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(sub ?? ctx.r('addonWhat.$addonKey'), style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          if (a.isNotEmpty && a['soon'] != true) ...[
            const SizedBox(height: 12),
            Btn(
              '${ctx.r('buy', {'coins': fmt(n(a['price']))})}${n(a['days']) > 0 ? ' ${ctx.r('perYear')}' : ''}',
              lead: const CoinIcon(size: 16),
              small: true,
              onTap: ctx.readOnly ? null : () => ctx.askBuy(addonKey),
            ),
          ],
        ],
      ),
    );
  }
}

IconData addonIcon(String key) => switch (key) {
  'rest_website' => LucideIcons.globe,
  'rest_telegram' => LucideIcons.send,
  'rest_display' => LucideIcons.monitorUp,
  'rest_promos' => LucideIcons.badgePercent,
  'rest_app' => LucideIcons.smartphone,
  'rest_printer' => LucideIcons.printer,
  'rest_kitchen' => LucideIcons.chefHat,
  'rest_qr_menu' => LucideIcons.qrCode,
  'rest_payments' => LucideIcons.creditCard,
  'rest_staff' => LucideIcons.users,
  'rest_history' => LucideIcons.history,
  'rest_stock' => LucideIcons.package,
  'rest_table_order' => LucideIcons.handPlatter,
  'rest_rewards' => LucideIcons.gift,
  'rest_branches' => LucideIcons.network,
  _ => LucideIcons.lock,
};

// a picture with Upload / Change / Remove (ImagePick on the web). Resizes like the web (maxSize px).
class ImagePickRow extends StatelessWidget {
  final RestCtx ctx;
  final String url;
  final bool busy, round, wide, disabled;
  final int maxSize;
  final Future<void> Function(List<int> bytes, String name) onPick;
  final VoidCallback? onRemove;
  const ImagePickRow({
    super.key,
    required this.ctx,
    required this.url,
    required this.busy,
    required this.onPick,
    this.onRemove,
    this.round = false,
    this.wide = false,
    this.disabled = false,
    this.maxSize = 1000,
  });

  Future<void> _choose(BuildContext context) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx2) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(LucideIcons.image), title: Text(ctx.r('upload')), onTap: () => Navigator.pop(ctx2, ImageSource.gallery)),
            ListTile(leading: const Icon(LucideIcons.camera), title: Text(ctx.t('app.takePhoto')), onTap: () => Navigator.pop(ctx2, ImageSource.camera)),
          ],
        ),
      ),
    );
    if (src == null) return;
    final f = await ImagePicker().pickImage(source: src, maxWidth: maxSize.toDouble(), maxHeight: maxSize.toDouble(), imageQuality: 88);
    if (f == null) return;
    await onPick(await f.readAsBytes(), 'photo.jpg');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Container(
          width: wide ? 96 : 60,
          height: 60,
          decoration: BoxDecoration(
            color: c.bg2,
            shape: round ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: round ? null : BorderRadius.circular(14),
            border: Border.all(color: c.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: url.isNotEmpty ? Image(image: netImage(url), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.imagePlus, size: 22, color: c.muted),
        ),
        const SizedBox(width: 12),
        Btn(
          busy ? ctx.r('uploading') : (url.isNotEmpty ? ctx.r('change') : ctx.r('upload')),
          icon: LucideIcons.imagePlus,
          kind: BtnKind.ghost,
          small: true,
          busy: busy,
          onTap: busy || disabled ? null : () => _choose(context),
        ),
        if (url.isNotEmpty && !busy && onRemove != null) ...[const SizedBox(width: 6), RoundBtn(LucideIcons.trash2, size: 38, tip: ctx.r('remove'), fg: c.danger, onTap: disabled ? null : onRemove)],
      ],
    );
  }
}

FormData imageForm(List<int> bytes, String name, [Map<String, String> fields = const {}]) => FormData.fromMap({...fields, 'file': MultipartFile.fromBytes(bytes, filename: name)});

// "Remove" → "Delete?" (DeleteButton on the web)
class DeleteConfirm extends StatefulWidget {
  final RestCtx ctx;
  final VoidCallback? onDelete;
  const DeleteConfirm({super.key, required this.ctx, this.onDelete});
  @override
  State<DeleteConfirm> createState() => _DeleteConfirmState();
}

class _DeleteConfirmState extends State<DeleteConfirm> {
  bool _sure = false;
  @override
  Widget build(BuildContext context) => _sure
      ? Btn(widget.ctx.r('confirmDelete'), kind: BtnKind.danger, small: true, onTap: widget.onDelete)
      : Btn(widget.ctx.r('remove'), icon: LucideIcons.trash2, kind: BtnKind.ghost, small: true, onTap: widget.onDelete == null ? null : () => setState(() => _sure = true));
}

// bottom sheet editor (the web's Modal): title, form, footer (delete · cancel · save)
Future<R?> showEditor<R>(BuildContext context, {required WidgetBuilder builder}) =>
    showModalBottomSheet<R>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: builder);

class EditorFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? delete;
  final String cancel, save;
  final bool busy, canSave;
  final VoidCallback onSave;
  const EditorFrame({super.key, required this.title, required this.children, this.delete, required this.cancel, required this.save, required this.busy, required this.canSave, required this.onSave});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                ?delete,
                const Spacer(),
                Btn(cancel, kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Btn(busy ? '…' : save, small: true, busy: busy, onTap: busy || !canSave ? null : onSave),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const gap14 = SizedBox(height: 14);
