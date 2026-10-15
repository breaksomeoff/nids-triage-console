import 'package:flutter/material.dart';

import 'src/data/mock_alerts.dart';
import 'src/screens/dashboard_screen.dart';

void main() {
  runApp(const NidsTriageConsoleApp());
}

class NidsTriageConsoleApp extends StatelessWidget {
  const NidsTriageConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NIDS Triage Console',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E7C86),
          brightness: Brightness.dark,
        ),
      ),
      home: DashboardScreen(analystName: 'Alessio Inglese', alerts: mockAlerts),
    );
  }
}
