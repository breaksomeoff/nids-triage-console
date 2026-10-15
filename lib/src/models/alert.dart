import 'package:flutter/material.dart';

/// Alert severity, ordered from most to least urgent.
enum Severity {
  critical('Critical', Color(0xFFE5484D)),
  high('High', Color(0xFFF76B15)),
  medium('Medium', Color(0xFFFFC53D)),
  low('Low', Color(0xFF3E9B4F));

  const Severity(this.label, this.color);

  final String label;
  final Color color;
}

/// Triage state of an alert in the analyst's queue.
enum AlertStatus { open, acknowledged, escalated, closed }

/// A network intrusion detection alert raised by a sensor on a single flow.
class Alert {
  const Alert({
    required this.id,
    required this.timestamp,
    required this.sensor,
    required this.category,
    required this.severity,
    required this.srcIp,
    required this.dstIp,
    required this.dstPort,
    required this.protocol,
    required this.attackTactic,
    this.status = AlertStatus.open,
  });

  final String id;
  final DateTime timestamp;
  final String sensor;
  final String category;
  final Severity severity;
  final String srcIp;
  final String dstIp;
  final int dstPort;
  final String protocol;

  /// MITRE ATT&CK tactic suggested for the alert.
  final String attackTactic;
  final AlertStatus status;
}
