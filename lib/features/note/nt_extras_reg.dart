import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import 'nt_blocks.dart';
import 'nt_common.dart';
import 'nt_draw.dart';
import 'nt_due.dart';
import 'nt_editor.dart';
import 'nt_form.dart';
import 'nt_groups.dart' show ntGroupLookHook;
import 'nt_look.dart';
import 'nt_pdf.dart';
import 'nt_style.dart';
import 'nt_tabs.dart';
import 'nt_voice.dart';

// Phase 2b: editor extras + note tabs (style pack, stickers, emoji, draw, voice, due/who, form fields,
// replies, confirmed, seen + views, files, history, look, PDF, save as template).
// Registers with ntRegisterTool / ntRegisterNoteAction / ntRegisterBlock / ntSetNoteTab / ntBlockBelow. Called once from NotePage.
bool _done = false;

void ntRegisterExtras() {
  if (_done) return;
  _done = true;

  // ---------------------------------------------------------------- block looks
  ntRegisterBlock(NtBlockKind(type: 'check', icon: LucideIcons.squareCheck, label: 'types.check', inTypeBar: true, view: ntCheckView));
  ntRegisterBlock(NtBlockKind(type: 'audio', icon: LucideIcons.mic, label: 'voiceBtn', textual: false, needs: 'note_voice', view: (v) => NtAudioBlock(view: v)));
  ntBlockBelow.add(ntDueBelow);
  ntEditorBackdrops.add(ntPaperBackdrop);

  // ---------------------------------------------------------------- the toolbar (after "attach")
  ntRegisterTool(NtToolAction(key: 'style', icon: LucideIcons.type, label: 'stStyle', needs: 'note_style', run: ntStyleSheet));
  ntRegisterTool(NtToolAction(key: 'emoji', icon: LucideIcons.smile, label: 'stEmoji', needs: 'note_style', run: ntEmojiTool));
  ntRegisterTool(NtToolAction(key: 'sticker', icon: LucideIcons.stickyNote, label: 'stSticker', needs: 'note_style', run: ntStickerSheet));
  ntRegisterTool(NtToolAction(key: 'callout', icon: LucideIcons.messageSquareWarning, label: 'stCallout', needs: 'note_style', run: (ed) async => ntAddCallout(ed)));
  ntRegisterTool(NtToolAction(key: 'divider', icon: LucideIcons.minus, label: 'stDivider', needs: 'note_style', run: (ed) async => ntAddDivider(ed)));
  ntRegisterTool(NtToolAction(key: 'draw', icon: LucideIcons.signature, label: 'drawBtn', needs: 'note_sign', run: ntDrawTool));
  ntRegisterTool(NtToolAction(key: 'voice', icon: LucideIcons.mic, label: 'voiceBtn', needs: 'note_voice', run: ntVoiceTool));
  ntRegisterTool(NtToolAction(key: 'due', icon: LucideIcons.calendarClock, label: 'dueTitle', visible: (ed) => ed.currentBlock?.t == 'check', run: ntDueTool));

  // ---------------------------------------------------------------- the ⋯ menu
  ntRegisterNoteAction(NtNoteAction(key: 'look', icon: LucideIcons.palette, label: 'lookTitle', run: ntLookTool));
  ntRegisterNoteAction(NtNoteAction(key: 'paper', icon: LucideIcons.scrollText, label: 'paperTitle', needs: 'note_style', run: ntPaperSheet));
  ntRegisterNoteAction(NtNoteAction(key: 'form', icon: LucideIcons.listChecks, label: 'fxTitle', visible: (ed) => obj(ed.note['share'])['level'] == 'collect', run: ntFormTool));
  ntRegisterNoteAction(NtNoteAction(key: 'template', icon: LucideIcons.layoutTemplate, label: 'tplSaveTitle', run: _saveTemplate));
  ntRegisterNoteAction(NtNoteAction(key: 'pdf', icon: LucideIcons.fileDown, label: 'pdfTitle', needs: 'note_pdf', run: ntPdfTool));

  // ---------------------------------------------------------------- a group's page look (Look button on its page)
  ntGroupLookHook = (context, ctx, group) async {
    Json? saved;
    await ntLookSheet(
      context,
      ctx,
      theme: obj(group['theme']),
      title: str(group['name']),
      save: (theme) async {
        final r = await ctx.run(() => ctx.a.updateGroup(str(group['_id']), {'theme': theme}));
        if (r == null) return false;
        saved = {...group, ...obj(r['data']), 'theme': theme};
        return true;
      },
    );
    return saved;
  };

  // ---------------------------------------------------------------- the tabs of a note
  ntSetNoteTab('entries', (ed) => NtEntriesTab(key: ValueKey('entries-${ed.nid}'), ed: ed));
  ntSetNoteTab('acks', (ed) => NtAcksTab(key: ValueKey('acks-${ed.nid}'), ed: ed));
  ntSetNoteTab('seen', (ed) => NtSeenTab(key: ValueKey('seen-${ed.nid}'), ed: ed));
  ntSetNoteTab('files', (ed) => NtFilesTab(key: ValueKey('files-${ed.nid}'), ed: ed));
  ntSetNoteTab('history', (ed) => NtHistoryTab(key: ValueKey('history-${ed.nid}'), ed: ed));
}

// ---------------------------------------------------------------- save the note as one of my templates
Future<void> _saveTemplate(NtEditorApi ed) async {
  final ctx = ed.ctx;
  final name = await ntAskTemplateName(ed.context, ctx, str(ed.note['title']));
  if (name == null) return;
  await ed.flush(); // the template is made from the server copy: send the latest typing first
  await ctx.run(() => ctx.a.templateSave(ed.nid, name), ctx.m('tplSaved'));
}

Future<String?> ntAskTemplateName(BuildContext context, NtCtx ctx, String start, {String? title}) {
  final ctl = TextEditingController(text: start.length > 60 ? start.substring(0, 60) : start);
  return showDialog<String>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: Text(title ?? ctx.m('tplSaveTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title == null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(ctx.m('tplSaveSub'))),
            TextField(
              controller: ctl,
              autofocus: true,
              maxLength: 60,
              onChanged: (_) => set(() {}),
              decoration: InputDecoration(hintText: ctx.m('tplNamePh'), counterText: ''),
              onSubmitted: (v) => v.trim().isEmpty ? null : Navigator.pop(d, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(ctx.m('cancel'))),
          FilledButton(onPressed: ctl.text.trim().isEmpty ? null : () => Navigator.pop(d, ctl.text.trim()), child: Text(ctx.m('save'))),
        ],
      ),
    ),
  ).whenComplete(ctl.dispose);
}
