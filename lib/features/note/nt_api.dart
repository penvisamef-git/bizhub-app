import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/api.dart';

// Digital Note — every owner call of /api/user/businesses/:id/note (the contract: bizhub-api/src/biz/note/NOTE_*.md,
// the routes in note.route.js are the truth). Answers are the API's { success, data, … } maps.
//
// Errors are ApiError: status + code (body['code']):
//   409 conflict (body['data'] = the newer note) · 402 locked (the year ended) · 402 coins (body price / balance)
//   403 need_style | need_sign | need_voice | need_ack | need_form | need_pdf | need_link | need_theme | need_telegram | need_group_icon
//   413 storage_full | file_too_big | too_large · 400 bad_pin | slug_* | need_name …
class NtApi {
  final Api api;
  final String id; // business id
  const NtApi(this.api, this.id);

  String get base => '${Api.user}/businesses/$id/note';
  String get bizBase => '${Api.user}/businesses/$id';

  // ---------------------------------------------------------------- book
  Future<Json> book() => api.get(base);

  // ---------------------------------------------------------------- notes
  Future<Json> notes({String q = '', String filter = 'all', String sort = 'updated', int page = 1}) => api.get('$base/notes', {'q': q, 'filter': filter, 'sort': sort, 'page': '$page'});
  Future<Json> create({String? template, String? myTemplate, String lang = 'en', String? shareLevel, String? title, List<Json>? blocks, String? color, String? paper}) => api.post('$base/notes', {
    'template': ?template,
    'my_template': ?myTemplate,
    'lang': lang,
    if (shareLevel != null && shareLevel.isNotEmpty) 'share_level': shareLevel,
    'title': ?title,
    'blocks': ?blocks,
    'color': ?color,
    'paper': ?paper,
  });
  Future<Json> note(String nid) => api.get('$base/notes/$nid');
  // { title, blocks, base_version } (content) and / or { color, pinned, tags, paper, theme, form } (no version needed)
  Future<Json> update(String nid, Json body) => api.put('$base/notes/$nid', body);
  Future<Json> remove(String nid) => api.delete('$base/notes/$nid');
  Future<Json> restore(String nid) => api.post('$base/notes/$nid/restore');
  Future<Json> forever(String nid) => api.delete('$base/notes/$nid/forever');
  Future<Json> duplicate(String nid) => api.post('$base/notes/$nid/duplicate');

  // ---------------------------------------------------------------- sharing
  // { level, pin ("" = remove), expires_at, opens_at, allow_files, show_entries, ask_name, hide_owner, no_copy, ack, slug }
  Future<Json> share(String nid, Json body) => api.put('$base/notes/$nid/share', body);
  Future<Json> newLink(String nid) => api.post('$base/notes/$nid/share/new-link');
  // custom links (note_link): is a name free? → { slug, ok, reason, dropped, suggestions, owned }
  Future<Json> linkCheck(String slug, {String kind = 'note', String id = ''}) => api.get('$base/link-check', {'slug': slug, 'kind': kind, 'id': id});
  Future<Json> linkUnlock() => api.post('$base/link/unlock');

  // ---------------------------------------------------------------- files
  Future<Json> uploadSign() => api.get('$base/upload-sign');
  // after a signed upload to Cloudinary: tell the API (sign: a signature PNG · voice: a voice clip)
  Future<Json> attach(String nid, {required String publicId, required String resourceType, String name = '', bool sign = false, bool voice = false}) =>
      api.post('$base/notes/$nid/files', {'public_id': publicId, 'resource_type': resourceType, 'name': name, if (sign) 'sign': true, if (voice) 'voice': true});
  // fallback: the file through our API (multipart "file")
  Future<Json> attachDirect(String nid, List<int> bytes, String name, {String? mime, bool sign = false, bool voice = false}) => api.post(
    '$base/notes/$nid/files/direct',
    FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: name, contentType: mime == null || mime.isEmpty ? null : DioMediaType.parse(mime)),
      if (sign) 'sign': 'true',
      if (voice) 'voice': 'true',
    }),
  );
  Future<Json> deleteFile(String nid, String fid) => api.delete('$base/notes/$nid/files/$fid');
  // a short-lived signed link → { url, name, expires_at } (PDFs can't be opened by their own url)
  Future<Json> download(String nid, String fid, {bool inline = false}) => api.get('$base/notes/$nid/files/$fid/download', {if (inline) 'inline': '1'});
  Future<Json> entryDownload(String eid, String fid, {bool inline = false}) => api.get('$base/entries/$eid/files/$fid/download', {if (inline) 'inline': '1'});

  // ---------------------------------------------------------------- replies, seen, history
  Future<Json> entries(String nid, {int page = 1}) => api.get('$base/notes/$nid/entries', {'page': '$page'});
  Future<Json> reply(String nid, String text) => api.post('$base/notes/$nid/entries', {'text': text});
  Future<Json> entryHide(String eid, bool hidden) => api.put('$base/entries/$eid', {'hidden': hidden});
  Future<Json> entryDelete(String eid) => api.delete('$base/entries/$eid');
  Future<Json> seen(String nid) => api.get('$base/notes/$nid/seen');
  Future<Json> history(String nid) => api.get('$base/notes/$nid/history');
  Future<Json> historyOne(String nid, String rid) => api.get('$base/notes/$nid/history/$rid');
  Future<Json> historyRestore(String nid, String rid) => api.post('$base/notes/$nid/history/$rid/restore');
  Future<Json> stats(String nid, {int days = 30}) => api.get('$base/notes/$nid/stats', {'days': '$days'});

  // ---------------------------------------------------------------- v4: acks, sign-up rows, people, templates, print
  Future<Json> acks(String nid) => api.get('$base/notes/$nid/acks');
  Future<String> acksCsv(String nid) => api.text('$base/notes/$nid/acks', {'format': 'csv'});
  Future<String> exportCsv(String nid) => api.text('$base/notes/$nid/entries/export', {'format': 'csv'});
  // { title, columns, rows } — the app builds the .xlsx (needs note_form)
  Future<Json> exportRows(String nid) => api.get('$base/notes/$nid/entries/export', {'format': 'xlsx'});
  Future<Json> people() => api.get('$base/people');
  Future<Json> templates() => api.get('$base/templates');
  Future<Json> templateSave(String nid, String name) => api.post('$base/templates', {'note_id': nid, 'name': name});
  Future<Json> templateRename(String tid, String name) => api.put('$base/templates/$tid', {'name': name});
  Future<Json> templateDelete(String tid) => api.delete('$base/templates/$tid');
  Future<Json> print(String nid) => api.get('$base/notes/$nid/print');

  // ---------------------------------------------------------------- storage packs (+5 GB, yearly slots)
  // key: one random id per purchase attempt — the same key again (a retry after a timeout) never pays twice
  Future<Json> buyStorage(int qty, {String? key}) => api.post('$base/storage', {'qty': qty, 'key': ?key});
  Future<Json> renewStorage(String item, Object? expect) => api.post('$base/storage', {'item': item, 'expect': expect});

  // ---------------------------------------------------------------- groups
  Future<Json> groups({String q = '', bool deleted = false}) => api.get('$base/groups', {'q': q, if (deleted) 'deleted': '1'});
  // pays the note_group price; key = one random id per create attempt (a repeat never pays twice)
  Future<Json> createGroup({required String name, String color = 'default', String icon = '', List<String> noteIds = const [], required String key}) =>
      api.post('$base/groups', {'name': name, 'color': color, if (icon.isNotEmpty) 'icon': icon, 'note_ids': noteIds, 'key': key});
  Future<Json> updateGroup(String gid, Json body) => api.put('$base/groups/$gid', body);
  Future<Json> groupAdd(String gid, String nid) => api.post('$base/groups/$gid/notes', {'note_id': nid});
  Future<Json> groupDrop(String gid, String nid) => api.delete('$base/groups/$gid/notes/$nid');
  Future<Json> groupShare(String gid, Json body) => api.put('$base/groups/$gid/share', body);
  Future<Json> groupNewLink(String gid) => api.post('$base/groups/$gid/share/new-link');
  Future<Json> groupDelete(String gid) => api.delete('$base/groups/$gid');
  Future<Json> groupRestore(String gid) => api.post('$base/groups/$gid/restore');
  Future<Json> groupSeen(String gid) => api.get('$base/groups/$gid/seen');
  Future<Json> groupStats(String gid, {int days = 30}) => api.get('$base/groups/$gid/stats', {'days': '$days'});
  Future<Json> groupFiles(String gid, {String q = '', String kind = 'all', String sort = 'date', int page = 1}) => api.get('$base/groups/$gid/files', {'q': q, 'kind': kind, 'sort': sort, 'page': '$page'});
  Future<Json> groupIconUnlock(String gid) => api.post('$base/groups/$gid/icon/unlock');
  Future<Json> groupIconUpload(String gid, List<int> bytes, String name, String mime) =>
      api.post('$base/groups/$gid/icon', FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: name, contentType: DioMediaType.parse(mime))}));
  Future<Json> groupIconDelete(String gid) => api.delete('$base/groups/$gid/icon');

  // ---------------------------------------------------------------- media manager (note_media)
  Future<Json> media({String sort = 'size', String kind = 'all', String q = '', int page = 1}) => api.get('$base/media', {'sort': sort, 'kind': kind, 'q': q, 'page': '$page'});
  // items: [{ where: note|entry, note_id, entry_id?, file_id }]
  Future<Json> mediaDelete(List<Json> items) => api.delete('$base/media', {'items': items});

  // ---------------------------------------------------------------- business profile
  Future<Json> rename(String name) => api.put(bizBase, {'name': name});
  Future<Json> logoUpload(List<int> bytes, String name, String mime) => api.post('$base/logo', FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: name, contentType: DioMediaType.parse(mime))}));
  Future<Json> logoDelete() => api.delete('$base/logo');

  // ---------------------------------------------------------------- themes (note_theme, item = key)
  Future<Json> themeUnlock(String key) => api.post('$base/themes/unlock', {'key': key});

  // ---------------------------------------------------------------- Telegram alerts (note_telegram)
  Future<Json> tgState() => api.get('$base/telegram'); // the state only (light, for polling)
  Future<Json> tgLink() => api.post('$base/telegram/link');
  Future<Json> tgTest() => api.post('$base/telegram/test');
  // { lang, replies, replies_batch, signups, edits, acks, daily, reminders }
  Future<Json> tgSave(Json body) => api.put('$base/telegram', body);
  Future<Json> tgOff() => api.delete('$base/telegram');

  // ---------------------------------------------------------------- licenses (the generic buy route)
  // digital_note · note_sign · note_style · note_media · note_telegram · note_ack · note_form · note_voice · note_pdf
  Future<Json> buy(String product, {Object? expect}) => api.post('$bizBase/licenses/$product', {'expect': expect});
}

// ---------------------------------------------------------------- uploads straight to Cloudinary
// signed by our API (GET /upload-sign → upload_url ends with /auto/upload, any file type) → { public_id, resource_type, … }
class NtUploadError implements Exception {
  final String message;
  final String code; // timeout | network | storage_full | file_too_big | failed
  const NtUploadError(this.message, this.code);
  @override
  String toString() => message;
}

Future<Json> ntUploadSigned(Json sign, List<int> bytes, String name, {void Function(double p)? onProgress, Duration timeout = const Duration(minutes: 2), CancelToken? cancel}) async {
  final form = FormData.fromMap({
    for (final k in ['api_key', 'timestamp', 'signature', 'folder'])
      if (sign[k] != null) k: '${sign[k]}',
    'file': MultipartFile.fromBytes(bytes, filename: name),
  });
  final url = str(sign['upload_url']).replaceFirst('/image/upload', '/auto/upload');
  // the upload really stops when the time is up (not just the waiting): nothing half-sent keeps going
  final tok = cancel ?? CancelToken();
  final stop = Timer(timeout + const Duration(seconds: 10), () {
    if (!tok.isCancelled) tok.cancel('timeout');
  });
  try {
    final r = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 20), sendTimeout: timeout, receiveTimeout: timeout)).post<Map<String, dynamic>>(
      url,
      data: form,
      cancelToken: tok,
      options: Options(validateStatus: (_) => true),
      onSendProgress: (a, b) {
        if (b > 0) onProgress?.call(a / b);
      },
    );
    final up = r.data ?? const {};
    if ((r.statusCode ?? 0) >= 300 || up['public_id'] == null) {
      final msg = str(obj(up['error'])['message']);
      throw NtUploadError(msg.isNotEmpty ? msg : 'Upload failed (${r.statusCode})', 'failed');
    }
    return Map<String, dynamic>.from(up);
  } on DioException catch (e) {
    if (e.type == DioExceptionType.cancel || e.type == DioExceptionType.sendTimeout || e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.connectionTimeout) {
      throw const NtUploadError('timeout', 'timeout');
    }
    throw NtUploadError(e.message ?? 'network', 'network');
  } finally {
    stop.cancel();
  }
}

// a file attached to a note, in 3 steps (sign → Cloudinary → tell the API). Checks the size first.
// onStep: 'prepare' | 'upload' (with p 0..1) | 'attach'
// No outer time limits that only stop waiting: every request has its own (Dio's connect / receive timeouts, the
// upload's cancel token), so nothing keeps running unseen. When telling the API failed on the way (no answer), the
// note is asked whether the file got there anyway — a file is never left in the note without its block.
Future<Json> ntAttachFile(NtApi a, String nid, List<int> bytes, String name, {bool sign = false, bool voice = false, void Function(String step, double p)? onStep, num? fileLimit}) async {
  onStep?.call('prepare', 0);
  final Json s;
  try {
    s = obj((await a.uploadSign())['data']);
  } on ApiError catch (e) {
    if (e.network) throw const NtUploadError('network', 'network');
    rethrow;
  }
  final limit = n(s['file_limit']) > 0 ? n(s['file_limit']) : (fileLimit ?? 0);
  if (limit > 0 && bytes.length > limit) throw const NtUploadError('file_too_big', 'file_too_big');
  if (s['storage_left'] != null && bytes.length > n(s['storage_left'])) throw const NtUploadError('storage_full', 'storage_full');
  onStep?.call('upload', 0);
  Json up;
  try {
    up = await ntUploadSigned(s, bytes, name, onProgress: (p) => onStep?.call('upload', p));
  } on NtUploadError catch (e) {
    // Cloudinary can't be reached from here: a small file can still go through our API (Vercel takes up to ~4 MB)
    if ((e.code == 'network' || e.code == 'failed') && bytes.length <= 4 * 1048576) {
      onStep?.call('attach', 1);
      try {
        return obj((await a.attachDirect(nid, bytes, name, mime: ntMimeOf(name), sign: sign, voice: voice))['data']);
      } on ApiError catch (d) {
        if (d.network) throw e; // no way through at all: say the first reason
        rethrow;
      }
    }
    rethrow;
  }
  onStep?.call('attach', 1);
  final publicId = str(up['public_id']);
  try {
    final r = await a.attach(nid, publicId: publicId, resourceType: str(up['resource_type']).isEmpty ? 'image' : str(up['resource_type']), name: name, sign: sign, voice: voice);
    return obj(r['data']);
  } on ApiError catch (e) {
    if (!e.network) rethrow;
    // no answer: it may have been added anyway — look before giving up
    try {
      final note = obj(obj((await a.note(nid))['data'])['note']);
      final got = objs(note['files']).where((f) => str(f['public_id']) == publicId).firstOrNull;
      if (got != null) return got;
    } catch (_) {}
    throw const NtUploadError('network', 'network');
  }
}

// a file's type from its name (the direct upload tells the API)
String ntMimeOf(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'pdf' => 'application/pdf',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'mp3' => 'audio/mpeg',
    'webm' => 'audio/webm',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'doc' => 'application/msword',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
}

// the API error code of anything thrown ('' when none)
String ntCode(Object e) => e is ApiError ? str(e.body['code']).isNotEmpty ? str(e.body['code']) : (e.code ?? '') : (e is NtUploadError ? e.code : '');
