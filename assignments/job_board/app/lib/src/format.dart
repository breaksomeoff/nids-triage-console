String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

/// "oggi", "ieri", "3 giorni fa", then the date.
String formatRelativeDate(DateTime date, {DateTime? now}) {
  final today = _day(now ?? DateTime.now());
  final days = today.difference(_day(date)).inDays;
  if (days <= 0) return 'oggi';
  if (days == 1) return 'ieri';
  if (days < 7) return '$days giorni fa';
  return formatDate(date);
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateRequired(String? value, String message) =>
    (value == null || value.trim().isEmpty) ? message : null;

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'L\'email è obbligatoria';
  if (!_emailPattern.hasMatch(v)) return 'Inserisci un\'email valida';
  return null;
}
