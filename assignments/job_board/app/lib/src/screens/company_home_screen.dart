import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'applications_screen.dart';
import 'board_screen.dart';
import 'new_job_screen.dart';

/// Reserved area of the logged-in company: its jobs with the number of
/// applications, publishing (R4) and logout (R3).
class CompanyHomeScreen extends StatefulWidget {
  const CompanyHomeScreen({super.key});

  @override
  State<CompanyHomeScreen> createState() => _CompanyHomeScreenState();
}

class _CompanyHomeScreenState extends State<CompanyHomeScreen>
    with ReloadOnReturn {
  Future<List<Job>>? _jobs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _jobs ??= AppScope.of(context).api.myJobs();
  }

  @override
  void reload() {
    final jobs = AppScope.of(context).api.myJobs();
    setState(() {
      _jobs = jobs;
    });
  }

  Future<void> _newJob() async {
    final job = await Navigator.of(context)
        .push<Job>(MaterialPageRoute(builder: (_) => const NewJobScreen()));
    if (job == null || !mounted) return;
    showMessage(
      context,
      '"${job.title}" è pubblicato in bacheca.',
      icon: Icons.campaign,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final company = scope.session.company;
    // Logged out meanwhile: the app is already going back to the board.
    if (company == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Area azienda'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: scope.session.logout,
              icon: const Icon(Icons.logout),
              label: const Text('Esci'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newJob,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo annuncio'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          reload();
          await _jobs;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            HeaderCard(
              icon: Icons.business,
              label: 'Account aziendale',
              title: company.name,
              subtitle: company.email,
            ),
            AsyncList<Job>(
              future: _jobs,
              onRetry: reload,
              builder: (context, jobs) {
                final total = jobs.fold<int>(
                  0,
                  (sum, j) => sum + (j.applicationCount ?? 0),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            value: jobs.length,
                            label: 'Annunci',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            value: total,
                            label: 'Candidature',
                            color: Brand.amber,
                          ),
                        ),
                      ],
                    ),
                    const SectionTitle('I miei annunci'),
                    if (jobs.isEmpty)
                      const MessageView(
                        icon: Icons.post_add,
                        title: 'Nessun annuncio',
                        message:
                            'Tocca "Nuovo annuncio" per pubblicare la tua '
                            'prima offerta in bacheca.',
                      )
                    else
                      for (final job in jobs)
                        JobCard(
                          job: job,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ApplicationsScreen(job: job),
                            ),
                          ),
                        ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
