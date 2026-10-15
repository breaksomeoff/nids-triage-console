import 'package:flutter/material.dart';

import '../models/alert.dart';

/// Home screen: who is on duty, queue overview by severity, latest alerts.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.analystName,
    required this.alerts,
  });

  final String analystName;
  final List<Alert> alerts;

  @override
  Widget build(BuildContext context) {
    final openAlerts = alerts
        .where((a) => a.status != AlertStatus.closed)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('NIDS Triage Console')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AnalystCard(name: analystName),
          const SizedBox(height: 24),
          Text('Open alerts', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _SeveritySummary(alerts: openAlerts),
          const SizedBox(height: 24),
          Text('Latest alerts', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final alert in alerts) _AlertTile(alert: alert),
        ],
      ),
    );
  }
}

class _AnalystCard extends StatelessWidget {
  const _AnalystCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.shield_outlined,
                size: 30,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analyst on duty', style: theme.textTheme.labelLarge),
                  Text(
                    name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeveritySummary extends StatelessWidget {
  const _SeveritySummary({required this.alerts});

  final List<Alert> alerts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final severity in Severity.values)
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Text(
                      '${alerts.where((a) => a.severity == severity).length}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: severity.color,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(severity.label),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final time =
        '${alert.timestamp.hour.toString().padLeft(2, '0')}:'
        '${alert.timestamp.minute.toString().padLeft(2, '0')}';
    final port = alert.dstPort == 0 ? '' : ':${alert.dstPort}';

    return Card(
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: alert.severity.color),
        title: Text(alert.category),
        subtitle: Text(
          '${alert.srcIp} → ${alert.dstIp}$port · ${alert.protocol}\n'
          '${alert.attackTactic} · ${alert.sensor}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(time),
            Text(
              alert.status.name,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
