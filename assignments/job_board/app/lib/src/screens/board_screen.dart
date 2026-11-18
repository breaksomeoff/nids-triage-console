import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'company_home_screen.dart';
import 'job_detail_screen.dart';
import 'login_screen.dart';

/// Public home: the list of published jobs (R5). Entry point to the company
/// area.
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> with ReloadOnReturn {
  Future<List<Job>>? _jobs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _jobs ??= AppScope.of(context).api.jobs();
  }

  @override
  void reload() {
    final jobs = AppScope.of(context).api.jobs();
    setState(() {
      _jobs = jobs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_outline),
            SizedBox(width: 10),
            Flexible(
              child: Text('Bacheca Lavoro', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: session,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: session.isLoggedIn
                  ? FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CompanyHomeScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.business),
                      label: const Text('Area azienda'),
                    )
                  : TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.login),
                      label: const Text('Aziende'),
                    ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          reload();
          await _jobs;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            AsyncList<Job>(
              future: _jobs,
              onRetry: reload,
              builder: (context, jobs) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeaderCard(
                    icon: Icons.travel_explore,
                    label: 'Offerte di lavoro',
                    title: jobs.length == 1
                        ? '1 annuncio'
                        : '${jobs.length} annunci',
                    subtitle: 'Scegli un annuncio e candidati in un minuto.',
                  ),
                  if (jobs.isEmpty)
                    const MessageView(
                      icon: Icons.inbox_outlined,
                      title: 'Ancora nessun annuncio',
                      message:
                          'Le aziende registrate possono pubblicare annunci '
                          'dall\'area aziende, in alto a destra.',
                    )
                  else ...[
                    const SectionTitle('Ultimi annunci'),
                    for (final job in jobs) JobCard(job: job),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary of a job in a list. Shows the application count when known.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, this.onTap});

  final Job job;

  /// Defaults to opening the public detail.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = job.applicationCount;
    return Card(
      child: InkWell(
        onTap:
            onTap ??
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => JobDetailScreen(job: job),
              ),
            ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatRelativeDate(job.createdAt),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  InfoLine(icon: Icons.business, text: job.companyName),
                  if (job.location.isNotEmpty)
                    InfoLine(icon: Icons.place_outlined, text: job.location),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                job.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (count != null) ...[
                const SizedBox(height: 12),
                _CountChip(count: count),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_alt_outlined,
            size: 16,
            color: active ? colors.onPrimaryContainer : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            count == 1 ? '1 candidatura' : '$count candidature',
            style: TextStyle(
              color: active
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
