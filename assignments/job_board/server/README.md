# Job board – server

Back-end of the job board app ([`../app`](../app)). Written in Dart with
[shelf](https://pub.dev/packages/shelf), data in SQLite, CVs on disk.

## Run

```sh
cd ../app && flutter build web --release   # optional: lets the server serve the app
cd ../server
dart pub get
dart run bin/server.dart
```

The server listens on port 8080 on every interface and prints its addresses.
A phone on the same network can open `http://<computer-ip>:8080/`.

| Variable   | Default             | Purpose                         |
|------------|---------------------|---------------------------------|
| `PORT`     | `8080`              | listening port                  |
| `DATA_DIR` | `data`              | SQLite database and uploaded CVs |
| `WEB_DIR`  | `../app/build/web`  | Flutter web build to serve      |

## API

Authenticated endpoints need `Authorization: Bearer <token>`.
Errors are returned as `{"error": "<message>"}`.

| Method | Path                              | Auth | Description                          |
|--------|-----------------------------------|------|--------------------------------------|
| POST   | `/api/companies`                  |      | register a company                   |
| POST   | `/api/sessions`                   |      | log in, returns a token              |
| DELETE | `/api/sessions`                   | yes  | log out                              |
| GET    | `/api/me`                         | yes  | current company                      |
| GET    | `/api/jobs`                       |      | published jobs                       |
| GET    | `/api/jobs/{id}`                  |      | one job                              |
| POST   | `/api/jobs`                       | yes  | publish a job                        |
| GET    | `/api/my/jobs`                    | yes  | own jobs with application count      |
| POST   | `/api/jobs/{id}/applications`     |      | apply (multipart: `firstName`, `lastName`, `email`, `cv`) |
| GET    | `/api/jobs/{id}/applications`     | yes  | applications to an own job           |
| GET    | `/api/applications/{id}/cv`       | yes  | CV file (token also as `?token=`)    |

CVs must be PDF files of at most 5 MB. Passwords are stored as salted
PBKDF2-SHA256 hashes; session tokens are stored hashed.

## Test

```sh
dart test
```
