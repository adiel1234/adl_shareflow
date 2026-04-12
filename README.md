# ADL ShareFlow

Split expenses with your group — smart, fast, multi-currency.

---

## Quick Start

### Backend (Docker Compose)

```bash
cd "ADL ShareFlow"

# Copy env file
cp backend/.env.example backend/.env
# Edit backend/.env with your credentials

# Start DB + Backend
docker-compose up --build

# Backend runs on: http://localhost:5050
# Health check:    http://localhost:5050/health
```

### Without Docker (local Python)

```bash
cd backend

# Create virtualenv
python3.12 -m venv venv
source venv/bin/activate

pip install -r requirements.txt

# Create DB
createdb shareflow

# Copy + configure env
cp .env.example .env

# Run migrations
flask db upgrade

# Start server
python run.py
```

### Flutter App

> Requires Flutter 3.19+ installed.

```bash
cd mobile

# Install dependencies
flutter pub get

# Generate code (l10n, freezed, etc.)
flutter pub run build_runner build --delete-conflicting-outputs

# Generate app icons
flutter pub run flutter_launcher_icons

# Run on device/emulator
flutter run
```

---

## Project Structure

```
ADL ShareFlow/
├── backend/              Python/Flask API
│   ├── app/
│   │   ├── auth/         JWT + Google + Apple auth
│   │   ├── users/        User profile
│   │   ├── groups/       Group management + invite links
│   │   ├── expenses/     Expense CRUD + split logic
│   │   ├── balances/     Balance engine + settlement plan
│   │   ├── settlements/  Confirm/cancel settlements
│   │   ├── notifications/In-app notifications
│   │   ├── ocr/          Google Vision receipt scanning
│   │   ├── currency/     Exchange rates
│   │   └── dashboard/    ADL admin API
│   └── tests/            Unit + integration tests
├── mobile/               Flutter app
│   └── lib/
│       ├── core/         Config, network, storage
│       ├── features/     Auth, groups, expenses, balances, OCR
│       ├── theme/        Design system (colors, typography)
│       └── l10n/         Hebrew + English
├── adl_platform_module/  ADL Dashboard integration
└── docker-compose.yml
```

---

## API

Base URL (dev): `http://localhost:5050/api`

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /auth/register | Register with email |
| POST | /auth/login | Login with email |
| POST | /auth/google | Google Sign-In |
| POST | /auth/apple | Apple Sign-In |
| POST | /auth/refresh | Refresh access token |
| GET | /users/me | Get current user |
| GET | /groups | List my groups |
| POST | /groups | Create group |
| GET | /groups/{id}/balances | Get balances |
| GET | /groups/{id}/balances/settlements-plan | Get settlement plan |
| POST | /ocr/scan | Scan receipt (multipart) |
| GET | /currency/rates | Exchange rates |

---

## ADL Dashboard Integration

1. Add to `adl_control` DB:
   ```sql
   INSERT INTO systems (name, code, status, url) 
   VALUES ('ADL ShareFlow', 'shareflow', 'active', 'http://localhost:5050');
   ```

2. Register blueprint in garage_system:
   ```python
   from adl_shareflow.adl_platform_module.shareflow.routes import shareflow_bp
   app.register_blueprint(shareflow_bp, url_prefix='/shareflow')
   ```

3. Set env var: `SHAREFLOW_API_URL=http://localhost:5050/api`

---

## Environment Variables

See `backend/.env.example` for full list.

Key variables:
- `DATABASE_URL` — PostgreSQL connection string
- `JWT_SECRET_KEY` — Secret for JWT signing
- `GOOGLE_CLIENT_ID` — For Google Sign-In
- `GOOGLE_APPLICATION_CREDENTIALS` — For OCR (Google Vision JSON file)
- `FIREBASE_CREDENTIALS_PATH` — For push notifications
- `ADL_ADMIN_KEY` — Shared key for ADL Dashboard API

---

## Tests

```bash
cd backend
pytest tests/unit/ -v
```

---

## Phase Roadmap

| Phase | Status | Description |
|-------|--------|-------------|
| 1 | ✅ Done | Backend + DB + Auth + Flutter skeleton + Design System |
| 2 | 🔜 Next | Groups + Expenses + Balance Engine UI |
| 3 | ⏳ | OCR + Multi-currency UI + Settlements UI |
| 4 | ⏳ | Push notifications + WhatsApp share + Deep links |
| 5 | ⏳ | Free/Pro plans + ADL Dashboard module + App Store release |
