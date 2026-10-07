# Login System (Java / Spring Boot)

A small, self-contained login system: register, login, and a JWT-protected
endpoint. Uses an embedded H2 database, so there's nothing to install besides
Java and Maven.

## Stack

- Java 17
- Spring Boot 3.3 (Web, Security, Data JPA, Validation)
- H2 database (file-based, stored in `./data/`)
- JWT (jjwt) for stateless auth
- BCrypt for password hashing

## Run it

```bash
mvn spring-boot:run
```

The API starts on `http://localhost:8080`.

## Endpoints

### Register

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "hunter22!"}'
```

Returns a JWT token on success.

### Login

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "hunter22!"}'
```

Response:

```json
{ "token": "eyJhbGciOiJIUzI1NiJ9...", "username": "alice" }
```

### Access a protected endpoint

```bash
curl http://localhost:8080/api/auth/me \
  -H "Authorization: Bearer <token from login/register>"
```

Any endpoint other than `/api/auth/**` requires this header — add your own
protected routes and they'll automatically be covered by the same filter.

## How it works

- Passwords are hashed with **BCrypt** before being stored (`SecurityConfig`)
  — the plain-text password is never saved.
- Login authenticates via Spring Security's `AuthenticationManager`, which
  checks the submitted password against the stored hash.
- On success, `JwtUtil` issues a signed JWT (1 hour expiry by default) with
  the username as the subject.
- `JwtAuthFilter` runs on every request, reads the `Authorization: Bearer`
  header, validates the token, and sets the authenticated user in Spring
  Security's context so `@AuthenticationPrincipal` / `anyRequest().authenticated()`
  work as expected.
- Auth is **stateless** — no server-side sessions, no cookies. The client is
  responsible for storing the token (e.g. in memory or `httpOnly` storage on
  the frontend) and sending it on each request.

## Before deploying this for real

1. **Replace the JWT secret.** `application.properties` has a placeholder.
   Generate a real one and set it via an environment variable instead of
   committing it:
   ```bash
   export APP_JWT_SECRET=$(openssl rand -base64 48)
   ```
   then in `application.properties`: `app.jwt.secret=${APP_JWT_SECRET}`.
2. **Disable the H2 console** (`spring.h2.console.enabled=false`) and switch
   to a real database (Postgres/MySQL) for anything beyond local dev.
3. **Add HTTPS** in front of this (e.g. via a reverse proxy) — JWTs sent over
   plain HTTP can be intercepted.
4. **Add rate limiting** on `/api/auth/login` and `/api/auth/register` to
   slow down brute-force attempts.
5. Consider a refresh-token flow if you want sessions longer than the access
   token's lifetime without re-entering credentials.

## Project layout

```
src/main/java/com/example/login/
├── LoginApplication.java       # entry point
├── model/User.java             # JPA entity
├── repository/UserRepository.java
├── dto/                        # request/response bodies
├── service/UserDetailsServiceImpl.java
├── security/
│   ├── JwtUtil.java             # sign/verify tokens
│   ├── JwtAuthFilter.java       # per-request auth check
│   └── SecurityConfig.java      # security rules, password encoder
└── controller/
    ├── AuthController.java      # /register, /login, /me
    └── GlobalExceptionHandler.java
```
