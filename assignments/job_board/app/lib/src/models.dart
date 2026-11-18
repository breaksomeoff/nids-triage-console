class Company {
  const Company({required this.id, required this.name, required this.email});

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
  );

  final int id;
  final String name;
  final String email;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}

class Job {
  const Job({
    required this.id,
    required this.companyName,
    required this.title,
    required this.description,
    required this.location,
    required this.createdAt,
    this.applicationCount,
  });

  factory Job.fromJson(Map<String, dynamic> json) => Job(
    id: json['id'] as int,
    companyName: json['companyName'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    location: json['location'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    applicationCount: json['applicationCount'] as int?,
  );

  final int id;
  final String companyName;
  final String title;
  final String description;

  /// Empty when not specified.
  final String location;
  final DateTime createdAt;

  /// Only present in the company's own list.
  final int? applicationCount;
}

class JobApplication {
  const JobApplication({
    required this.id,
    required this.jobId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.cvFilename,
    required this.cvSize,
    required this.createdAt,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) => JobApplication(
    id: json['id'] as int,
    jobId: json['jobId'] as int,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    email: json['email'] as String,
    cvFilename: json['cvFilename'] as String,
    cvSize: json['cvSize'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final int id;
  final int jobId;
  final String firstName;
  final String lastName;
  final String email;
  final String cvFilename;
  final int cvSize;
  final DateTime createdAt;

  String get fullName => '$firstName $lastName';

  String get initials =>
      '${firstName.isEmpty ? '' : firstName[0]}'
              '${lastName.isEmpty ? '' : lastName[0]}'
          .toUpperCase();
}

/// A CV chosen by the candidate, not uploaded yet.
class PickedCv {
  const PickedCv({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}
