import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'apply_screen.dart';

/// Public detail of a job, with the button to apply (R5, R6).
class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key, required this.job});

  final Job job;

  Future<void> _apply(BuildContext context) async {
    final sent = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => ApplyScreen(job: job)));
    if (sent == true && context.mounted) {
      showMessage(
        context,
        'Candidatura inviata a ${job.companyName}. In bocca al lupo!',
        icon: Icons.check_circle,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Annuncio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            job.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(job.companyName),
                  subtitle: const Text('Azienda'),
                ),
                if (job.location.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(job.location),
                    subtitle: const Text('Sede'),
                  ),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(formatDate(job.createdAt)),
                  subtitle: const Text('Pubblicato il'),
                ),
              ],
            ),
          ),
          const SectionTitle('Descrizione'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                job.description,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: () => _apply(context),
            icon: const Icon(Icons.send),
            label: const Text('Candidati'),
          ),
        ),
      ),
    );
  }
}
