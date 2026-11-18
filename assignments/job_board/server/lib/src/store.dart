import 'package:sqlite3/sqlite3.dart';

class Company {
  Company({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'email': email};
}

class Job {
  Job({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.title,
    required this.description,
    required this.location,
    required this.createdAt,
    this.applicationCount,
  });

  final int id;
  final int companyId;
  final String companyName;
  final String title;
  final String description;
  final String location;
  final String createdAt;

  /// Only filled in for the owning company's view.
  final int? applicationCount;

  Map<String, Object?> toJson() => {
    'id': id,
    'companyName': companyName,
    'title': title,
    'description': description,
    'location': location,
    'createdAt': createdAt,
    'applicationCount': ?applicationCount,
  };
}

class JobApplication {
  JobApplication({
    required this.id,
    required this.jobId,
    required this.companyId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.cvFilename,
    required this.cvStoredName,
    required this.cvSize,
    required this.createdAt,
  });

  final int id;
  final int jobId;

  /// Owner of the job, used for access checks.
  final int companyId;
  final String firstName;
  final String lastName;
  final String email;

  /// Original file name, as uploaded by the candidate.
  final String cvFilename;

  /// Name of the file on disk, inside the CV directory.
  final String cvStoredName;
  final int cvSize;
  final String createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'jobId': jobId,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'cvFilename': cvFilename,
    'cvSize': cvSize,
    'createdAt': createdAt,
  };
}

/// SQLite persistence for companies, sessions, jobs and applications.
class Store {
  Store._(this._db) {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute(_schema);
  }

  factory Store.open(String path) => Store._(sqlite3.open(path));
  factory Store.inMemory() => Store._(sqlite3.openInMemory());

  final Database _db;

  static const _schema = '''
    CREATE TABLE IF NOT EXISTS companies (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE COLLATE NOCASE,
      password_hash TEXT NOT NULL,
      password_salt TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS sessions (
      token_hash TEXT PRIMARY KEY,
      company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS jobs (
      id INTEGER PRIMARY KEY,
      company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      location TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS applications (
      id INTEGER PRIMARY KEY,
      job_id INTEGER NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
      first_name TEXT NOT NULL,
      last_name TEXT NOT NULL,
      email TEXT NOT NULL,
      cv_filename TEXT NOT NULL,
      cv_stored_name TEXT NOT NULL,
      cv_size INTEGER NOT NULL,
      created_at TEXT NOT NULL
    );
  ''';

  static String _now() => DateTime.now().toUtc().toIso8601String();

  void close() => _db.close();

  // Companies and sessions

  /// Returns null if the email is already registered.
  Company? createCompany({
    required String name,
    required String email,
    required String passwordHash,
    required String passwordSalt,
  }) {
    final existing = _db.select('SELECT 1 FROM companies WHERE email = ?', [
      email,
    ]);
    if (existing.isNotEmpty) return null;
    _db.execute(
      'INSERT INTO companies (name, email, password_hash, password_salt, '
      'created_at) VALUES (?, ?, ?, ?, ?)',
      [name, email, passwordHash, passwordSalt, _now()],
    );
    return Company(id: _db.lastInsertRowId, name: name, email: email);
  }

  ({Company company, String hash, String salt})? findCredentials(String email) {
    final rows = _db.select(
      'SELECT id, name, email, password_hash, password_salt FROM companies '
      'WHERE email = ?',
      [email],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (
      company: Company(id: r['id'], name: r['name'], email: r['email']),
      hash: r['password_hash'] as String,
      salt: r['password_salt'] as String,
    );
  }

  void createSession(String tokenHash, int companyId) => _db.execute(
    'INSERT INTO sessions (token_hash, company_id, created_at) VALUES (?, ?, ?)',
    [tokenHash, companyId, _now()],
  );

  Company? companyForSession(String tokenHash) {
    final rows = _db.select(
      'SELECT c.id, c.name, c.email FROM sessions s '
      'JOIN companies c ON c.id = s.company_id WHERE s.token_hash = ?',
      [tokenHash],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Company(id: r['id'], name: r['name'], email: r['email']);
  }

  void deleteSession(String tokenHash) =>
      _db.execute('DELETE FROM sessions WHERE token_hash = ?', [tokenHash]);

  // Jobs

  static const _jobColumns =
      'j.id, j.company_id, c.name AS company_name, j.title, j.description, '
      'j.location, j.created_at';

  Job _job(Row r) => Job(
    id: r['id'],
    companyId: r['company_id'],
    companyName: r['company_name'],
    title: r['title'],
    description: r['description'],
    location: r['location'],
    createdAt: r['created_at'],
    applicationCount: r.containsKey('application_count')
        ? r['application_count'] as int
        : null,
  );

  Job createJob({
    required int companyId,
    required String title,
    required String description,
    required String location,
  }) {
    _db.execute(
      'INSERT INTO jobs (company_id, title, description, location, created_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [companyId, title, description, location, _now()],
    );
    return findJob(_db.lastInsertRowId)!;
  }

  /// All published jobs, newest first.
  List<Job> listJobs() => _db
      .select(
        'SELECT $_jobColumns FROM jobs j JOIN companies c ON c.id = j.company_id '
        'ORDER BY j.created_at DESC, j.id DESC',
      )
      .map(_job)
      .toList();

  Job? findJob(int id) {
    final rows = _db.select(
      'SELECT $_jobColumns FROM jobs j JOIN companies c ON c.id = j.company_id '
      'WHERE j.id = ?',
      [id],
    );
    return rows.isEmpty ? null : _job(rows.first);
  }

  /// Jobs of one company, newest first, with their application count.
  List<Job> listJobsOfCompany(int companyId) => _db
      .select(
        'SELECT $_jobColumns, '
        '(SELECT COUNT(*) FROM applications a WHERE a.job_id = j.id) '
        'AS application_count '
        'FROM jobs j JOIN companies c ON c.id = j.company_id '
        'WHERE j.company_id = ? ORDER BY j.created_at DESC, j.id DESC',
        [companyId],
      )
      .map(_job)
      .toList();

  // Applications

  static const _applicationColumns =
      'a.id, a.job_id, j.company_id, a.first_name, a.last_name, a.email, '
      'a.cv_filename, a.cv_stored_name, a.cv_size, a.created_at';

  JobApplication _application(Row r) => JobApplication(
    id: r['id'],
    jobId: r['job_id'],
    companyId: r['company_id'],
    firstName: r['first_name'],
    lastName: r['last_name'],
    email: r['email'],
    cvFilename: r['cv_filename'],
    cvStoredName: r['cv_stored_name'],
    cvSize: r['cv_size'],
    createdAt: r['created_at'],
  );

  JobApplication createApplication({
    required int jobId,
    required String firstName,
    required String lastName,
    required String email,
    required String cvFilename,
    required String cvStoredName,
    required int cvSize,
  }) {
    _db.execute(
      'INSERT INTO applications (job_id, first_name, last_name, email, '
      'cv_filename, cv_stored_name, cv_size, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        jobId,
        firstName,
        lastName,
        email,
        cvFilename,
        cvStoredName,
        cvSize,
        _now(),
      ],
    );
    return findApplication(_db.lastInsertRowId)!;
  }

  /// Applications to one job, newest first.
  List<JobApplication> listApplications(int jobId) => _db
      .select(
        'SELECT $_applicationColumns FROM applications a '
        'JOIN jobs j ON j.id = a.job_id WHERE a.job_id = ? '
        'ORDER BY a.created_at DESC, a.id DESC',
        [jobId],
      )
      .map(_application)
      .toList();

  JobApplication? findApplication(int id) {
    final rows = _db.select(
      'SELECT $_applicationColumns FROM applications a '
      'JOIN jobs j ON j.id = a.job_id WHERE a.id = ?',
      [id],
    );
    return rows.isEmpty ? null : _application(rows.first);
  }
}
