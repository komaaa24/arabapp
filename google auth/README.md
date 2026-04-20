# Google Auth Backend (NestJS + PostgreSQL)

Production-ready Google Sign-In backend using NestJS, PostgreSQL, and JWT.

## Features

- Google ID token verification on backend
- PostgreSQL user persistence (TypeORM)
- JWT access token generation
- Protected endpoint (`GET /auth/me`)
- Strict DTO validation and environment validation

## 1. Setup

```bash
cp .env.example .env
npm install
```

If you need PostgreSQL quickly:

```bash
docker compose up -d
```

## 2. Run

```bash
npm run start:dev
```

Server starts on `http://localhost:3000`.

## 3. API

### `POST /auth/google`

Body:

```json
{
  "token": "GOOGLE_ID_TOKEN"
}
```

Response:

```json
{
  "access_token": "JWT_TOKEN",
  "token_type": "Bearer",
  "expires_in": "15m",
  "user": {
    "id": 1,
    "email": "user@gmail.com",
    "name": "Ali",
    "avatar": "https://...",
    "created_at": "2026-04-09T10:00:00.000Z"
  }
}
```

### `GET /auth/me`

Headers:

```http
Authorization: Bearer JWT_TOKEN
```

Returns current user profile.

## Security Notes

- Never trust Google token on frontend only; verify in backend.
- Use long random `JWT_SECRET` in production.
- Set `TYPEORM_SYNC=false` in production and use migrations.
- Use HTTPS in production.
