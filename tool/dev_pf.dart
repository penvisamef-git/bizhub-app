// Dev only: portfolio themes (flutter build web -t tool/dev_pf.dart), ?theme=midnight
import 'package:flutter/material.dart';
import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/features/namecard/pf_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await T.load();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: _Gallery()));
}

class _Gallery extends StatelessWidget {
  const _Gallery();
  @override
  Widget build(BuildContext context) {
    final theme = Uri.base.queryParameters['theme'] ?? 'classic';
    final card = {'name': 'Sokha Chan', 'job_title': 'Owner', 'company': 'Sokha Coffee', 'color': '#E0581A', 'email': 'sokha@example.com', 'phone1': '012 345 678', 'website': 'https://sokha.coffee', 'telegram': '@sokha', 'address': 'Street 240, Phnom Penh', 'slug': 'sokha'};
    final data = {
      'theme': theme,
      'color': '',
      'headline': 'Coffee roaster · 8 years',
      'about': 'I roast and serve specialty coffee in Phnom Penh.',
      'skills': ['Roasting', 'Latte art', 'Team lead'],
      'experience': [
        {'title': 'Head barista', 'company': 'Brown Coffee', 'location': 'Phnom Penh', 'start': '2018', 'end': '', 'current': true, 'description': 'Trained 20 baristas.'},
        {'title': 'Barista', 'company': 'Café Lat', 'location': '', 'start': '2015', 'end': '2018', 'current': false, 'description': ''},
      ],
      'education': [
        {'school': 'RUPP', 'degree': 'BBA', 'field': 'Marketing', 'start': '2011', 'end': '2015', 'description': ''},
      ],
      'projects': [
        {'title': 'Sokha Coffee', 'link': 'https://sokha.coffee', 'description': 'My own café.'},
      ],
      'certifications': [
        {'name': 'SCA Barista', 'issuer': 'SCA', 'year': '2019', 'link': ''},
      ],
      'languages': [
        {'name': 'Khmer', 'level': 'Native'},
        {'name': 'English', 'level': 'Fluent'},
      ],
      'files': [],
    };
    return Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 390, child: PfView(data: data, card: card, t: T.of('en')))),
    );
  }
}
