// Dev only: all name card themes side by side (flutter build web -t tool/dev_cards.dart)
import 'package:flutter/material.dart';
import 'package:bizhub_admin/features/namecard/nc_card.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: _Gallery()));

class _Gallery extends StatelessWidget {
  const _Gallery();
  @override
  Widget build(BuildContext context) {
    final theme = Uri.base.queryParameters['theme'] ?? 'classic';
    final card = {
      'theme': theme,
      'color': Uri.base.queryParameters['color'] ?? '#E0581A',
      'name': 'Sokha Chan',
      'job_title': 'Owner',
      'company': 'Sokha Coffee',
      'bio': 'Fresh coffee every morning in Phnom Penh.',
      'phone1': '012 345 678',
      'email': 'sokha@example.com',
      'website': 'https://sokha.coffee',
      'telegram': '@sokha',
      'address': 'Street 240, Phnom Penh',
      'extras': [
        {'label': 'Opening hours', 'value': '7am – 9pm'},
      ],
      'slug': 'sokha',
      'portfolio': true,
    };
    return Scaffold(
      backgroundColor: const Color(0xFFECEEF2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 380,
            child: NcCard(card: card, fieldLabels: const {'phone1': 'Phone', 'phone2': 'Phone', 'email': 'Email', 'website': 'Website', 'address': 'Address', 'telegram': 'Telegram', 'facebook': 'Facebook'}, viewPortfolio: 'View my portfolio'),
          ),
        ),
      ),
    );
  }
}
