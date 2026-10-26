import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'web_page.dart';

// Open one business: types rebuilt in the app open their own screens, the others still open the web screen.
const nativeTypes = {'namecard', 'restaurant', 'mart', 'guest_house', 'attendance', 'debt_book', 'qr_gen', 'website', 'flipbook', 'menu_qr', 'stamp_card', 'event', 'digital_note', 'tg_store'};

void openBusiness(BuildContext context, {required String id, required String name, String category = '', String tab = ''}) {
  if (category == 'restaurant') {
    context.push(Uri(path: '/biz/restaurant/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  if (category == 'guest_house') {
    context.push(Uri(path: '/biz/guesthouse/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  if (category == 'debt_book') {
    context.push(Uri(path: '/biz/debt/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  if (category == 'digital_note') {
    context.push(Uri(path: '/biz/note/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  if (category == 'tg_store') {
    context.push(Uri(path: '/biz/tgstore/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  if (category == 'event') {
    context.push(Uri(path: '/biz/event/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  if (category == 'stamp_card') {
    context.push(Uri(path: '/biz/stamp/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  if (category == 'menu_qr') {
    context.push(Uri(path: '/biz/menuqr/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  if (category == 'flipbook') {
    context.push(Uri(path: '/biz/flipbook/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  if (category == 'website') {
    context.push(Uri(path: '/biz/website/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  if (category == 'qr_gen') {
    context.push(Uri(path: '/biz/qrgen/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  if (category == 'attendance') {
    context.push(Uri(path: '/biz/attendance/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  if (category == 'mart') {
    context.push(Uri(path: '/biz/mart/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  if (category == 'namecard') {
    context.push(Uri(path: '/biz/namecard/$id', queryParameters: {'name': name, if (tab.isNotEmpty) 'tab': tab}).toString());
    return;
  }
  openWeb(context, '/app/business/$id${tab.isNotEmpty ? '?tab=$tab' : ''}', name);
}
