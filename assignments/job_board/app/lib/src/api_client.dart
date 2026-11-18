import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Error to show to the user; [message] is already in Italian.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Client for the back-end REST API.
class ApiClient {
  ApiClient(this.baseUrl, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _http;

  /// Session token of the logged-in company, if any.
  String? token;

  /// Called when an authenticated request is rejected (expired session).
  VoidCallback? onUnauthorized;

  static const _timeout = Duration(seconds: 20);

  // Companies

  Future<Company> register({
    required String name,
    required String email,
    required String password,
  }) async => Company.fromJson(
    await _send(
      'POST',
      'api/companies',
      json: {'name': name, 'email': email, 'password': password},
    ),
  );

  Future<({String token, Company company})> login({
    required String email,
    required String password,
  }) async {
    final body = await _send(
      'POST',
      'api/sessions',
      json: {'email': email, 'password': password},
    );
    return (
      token: body['token'] as String,
      company: Company.fromJson(body['company'] as Map<String, dynamic>),
    );
  }

  /// Invalidates the token on the server.
  Future<void> logout() =>
      _send('DELETE', 'api/sessions', auth: true, reportUnauthorized: false);

  // Public board

  Future<List<Job>> jobs() async => [
    for (final j in await _send('GET', 'api/jobs') as List)
      Job.fromJson(j as Map<String, dynamic>),
  ];

  Future<JobApplication> apply({
    required int jobId,
    required String firstName,
    required String lastName,
    required String email,
    required PickedCv cv,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            baseUrl.resolve('api/jobs/$jobId/applications'),
          )
          ..fields.addAll({
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
          })
          ..files.add(
            http.MultipartFile.fromBytes('cv', cv.bytes, filename: cv.name),
          );
    return JobApplication.fromJson(await _execute(request));
  }

  // Reserved area

  Future<Job> createJob({
    required String title,
    required String description,
    required String location,
  }) async => Job.fromJson(
    await _send(
      'POST',
      'api/jobs',
      auth: true,
      json: {'title': title, 'description': description, 'location': location},
    ),
  );

  Future<List<Job>> myJobs() async => [
    for (final j in await _send('GET', 'api/my/jobs', auth: true) as List)
      Job.fromJson(j as Map<String, dynamic>),
  ];

  Future<List<JobApplication>> applications(int jobId) async => [
    for (final a in await _send(
      'GET',
      'api/jobs/$jobId/applications',
      auth: true,
    ) as List)
      JobApplication.fromJson(a as Map<String, dynamic>),
  ];

  /// Link to the CV, opened in the browser. The browser cannot send the
  /// Authorization header, so the token goes in the query string.
  Uri cvUrl(int applicationId) => baseUrl
      .resolve('api/applications/$applicationId/cv')
      .replace(queryParameters: {'token': token ?? ''});

  // Plumbing

  Future<dynamic> _send(
    String method,
    String path, {
    Object? json,
    bool auth = false,
    bool reportUnauthorized = true,
  }) {
    final request = http.Request(method, baseUrl.resolve(path));
    if (json != null) {
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(json);
    }
    if (auth && token != null) {
      request.headers['authorization'] = 'Bearer $token';
    }
    return _execute(request, reportUnauthorized: auth && reportUnauthorized);
  }

  Future<dynamic> _execute(
    http.BaseRequest request, {
    bool reportUnauthorized = false,
  }) async {
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw const ApiException(
        'Il server non risponde. Riprova tra qualche istante.',
      );
    } catch (_) {
      throw const ApiException(
        'Impossibile contattare il server. Controlla la connessione.',
      );
    }

    final status = response.statusCode;
    final text = utf8.decode(response.bodyBytes);
    if (status >= 200 && status < 300) {
      return text.isEmpty ? null : jsonDecode(text);
    }
    if (status == 401 && reportUnauthorized) onUnauthorized?.call();

    String? message;
    try {
      message = (jsonDecode(text) as Map<String, dynamic>)['error'] as String?;
    } catch (_) {}
    throw ApiException(
      message ?? 'Errore inatteso del server ($status).',
      statusCode: status,
    );
  }
}
