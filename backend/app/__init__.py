from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager
from flask_cors import CORS

db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()

# Scheduler is initialized lazily to avoid import cycles
_scheduler_started = False


def create_app(config=None):
    app = Flask(__name__)

    # Config
    if config is None:
        from config import get_config
        app.config.from_object(get_config())
    else:
        app.config.from_object(config)

    # Extensions
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    import re
    cors_origins = app.config.get('CORS_ORIGINS', [])
    # localhost + public IP תמיד מותרים, production origins מה-env
    CORS(app,
         origins=[
             re.compile(r'http://localhost:\d+'),
             re.compile(r'http://79\.181\.158\.30:\d+'),
             re.compile(r'https://.*\.ngrok-free\.dev'),
             re.compile(r'https://.*\.ngrok\.io'),
             *cors_origins,
         ],
         supports_credentials=True)

    # JWT error handlers
    _register_jwt_handlers(jwt)

    # Import models so Alembic detects them
    with app.app_context():
        from app import models  # noqa: F401
        _seed_feature_flags()

    # Blueprints
    _register_blueprints(app)

    # APScheduler — automatic reminders
    _start_scheduler(app)

    # Health check
    @app.get('/health')
    def health():
        return {'status': 'ok', 'service': 'ADL ShareFlow API'}

    # Smart join link — opens app if installed, otherwise shows download page
    @app.get('/join/<invite_code>')
    def join_redirect(invite_code):
        from flask import request, redirect, Response
        ANDROID_APK = 'https://github.com/adiel1234/adl_shareflow/releases/latest/download/app-release.apk'
        TESTFLIGHT  = 'https://testflight.apple.com/join/PLACEHOLDER'
        deep_link   = f'shareflow://join/{invite_code}'

        ua = request.headers.get('User-Agent', '')
        is_ios     = any(k in ua for k in ('iPhone', 'iPad', 'iPod'))
        is_android = 'Android' in ua

        html = f'''<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>הצטרף ל-ADL ShareFlow</title>
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: linear-gradient(135deg, #6C63FF 0%, #3B37C8 100%);
      min-height: 100vh; display: flex; align-items: center;
      justify-content: center; padding: 24px;
    }}
    .card {{
      background: white; border-radius: 24px; padding: 48px 40px;
      max-width: 440px; width: 100%; text-align: center;
      box-shadow: 0 20px 60px rgba(0,0,0,0.2);
    }}
    .logo {{ font-size: 52px; margin-bottom: 16px; }}
    h1 {{ font-size: 24px; font-weight: 700; color: #1a1a2e; margin-bottom: 8px; }}
    .subtitle {{ color: #666; font-size: 15px; margin-bottom: 32px; line-height: 1.5; }}
    .btn {{
      display: flex; align-items: center; justify-content: center; gap: 12px;
      width: 100%; padding: 16px 24px; border-radius: 14px;
      font-size: 16px; font-weight: 600; text-decoration: none;
      margin-bottom: 14px; transition: opacity 0.2s;
    }}
    .btn:hover {{ opacity: 0.88; }}
    .btn-primary {{ background: #6C63FF; color: white; }}
    .btn-android {{ background: #3DDC84; color: #1a1a2e; }}
    .btn-ios {{ background: #1a1a2e; color: white; }}
    .divider {{ margin: 20px 0; color: #bbb; font-size: 13px; }}
    .code {{ font-family: monospace; font-size: 22px; font-weight: 700;
             letter-spacing: 4px; color: #6C63FF; margin: 16px 0; }}
  </style>
  <script>
    window.onload = function() {{
      // Try to open app
      window.location = '{deep_link}';
    }};
  </script>
</head>
<body>
  <div class="card">
    <div class="logo">💸</div>
    <h1>הוזמנת ל-ADL ShareFlow</h1>
    <p class="subtitle">לחץ על הכפתור כדי להצטרף לקבוצה</p>
    <div class="code">{invite_code}</div>
    <a class="btn btn-primary" href="{deep_link}">פתח באפליקציה</a>
    <div class="divider">— אין לך את האפליקציה עדיין? —</div>
    {'<a class="btn btn-android" href="' + ANDROID_APK + '">🤖 הורד לאנדרואיד</a>' if is_android else ''}
    {'<a class="btn btn-ios" href="' + TESTFLIGHT + '">🍎 הורד ל-iPhone</a>' if is_ios else ''}
    {'<a class="btn btn-android" href="' + ANDROID_APK + '">🤖 הורד לאנדרואיד</a><a class="btn btn-ios" href="' + TESTFLIGHT + '">🍎 הורד ל-iPhone</a>' if not is_android and not is_ios else ''}
  </div>
</body>
</html>'''
        return Response(html, mimetype='text/html')

    # Download landing page
    @app.get('/download')
    def download():
        from flask import request, Response
        ANDROID_APK = 'https://github.com/adiel1234/adl_shareflow/releases/latest/download/app-release.apk'
        TESTFLIGHT  = 'https://testflight.apple.com/join/PLACEHOLDER'  # יעודכן לאחר אישור Apple

        # Desktop / unknown → show HTML page with both options
        html = f'''<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>הורד ADL ShareFlow</title>
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: linear-gradient(135deg, #6C63FF 0%, #3B37C8 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }}
    .card {{
      background: white;
      border-radius: 24px;
      padding: 48px 40px;
      max-width: 440px;
      width: 100%;
      text-align: center;
      box-shadow: 0 20px 60px rgba(0,0,0,0.2);
    }}
    .logo {{ font-size: 52px; margin-bottom: 16px; }}
    h1 {{ font-size: 26px; font-weight: 700; color: #1a1a2e; margin-bottom: 8px; }}
    .subtitle {{ color: #666; font-size: 15px; margin-bottom: 36px; }}
    .btn {{
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 12px;
      width: 100%;
      padding: 16px 24px;
      border-radius: 14px;
      font-size: 16px;
      font-weight: 600;
      text-decoration: none;
      margin-bottom: 14px;
      transition: opacity 0.2s;
    }}
    .btn:hover {{ opacity: 0.88; }}
    .btn-android {{
      background: #3DDC84;
      color: #1a1a2e;
    }}
    .btn-ios {{
      background: #1a1a2e;
      color: white;
    }}
    .note {{ font-size: 12px; color: #999; margin-top: 24px; }}
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">💸</div>
    <h1>ADL ShareFlow</h1>
    <p class="subtitle">חלוקת הוצאות חכמה לקבוצות</p>

    <a class="btn btn-android" href="{ANDROID_APK}">
      <span>🤖</span> הורד לאנדרואיד (APK)
    </a>

    <a class="btn btn-ios" href="{TESTFLIGHT}">
      <span>🍎</span> הורד ל-iPhone (TestFlight)
    </a>

    <p class="note">גרסת בטא — v1.0.0</p>
  </div>
</body>
</html>'''
        return Response(html, mimetype='text/html')

    return app


def _start_scheduler(app):
    global _scheduler_started
    if _scheduler_started:
        return
    try:
        from app.scheduler import scheduler
        app.config.setdefault('SCHEDULER_API_ENABLED', False)
        scheduler.init_app(app)
        scheduler.start()
        _scheduler_started = True
    except Exception as e:
        app.logger.warning(f'Scheduler failed to start: {e}')


def _register_blueprints(app):
    from app.auth.routes import auth_bp
    from app.users.routes import users_bp
    from app.groups.routes import groups_bp
    from app.expenses.routes import expenses_bp
    from app.balances.routes import balances_bp
    from app.settlements.routes import settlements_bp
    from app.notifications.routes import notifications_bp
    from app.ocr.routes import ocr_bp
    from app.currency.routes import currency_bp
    from app.dashboard.routes import dashboard_bp

    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(users_bp, url_prefix='/api/users')
    app.register_blueprint(groups_bp, url_prefix='/api/groups')
    app.register_blueprint(expenses_bp, url_prefix='/api')
    app.register_blueprint(balances_bp, url_prefix='/api')
    app.register_blueprint(settlements_bp, url_prefix='/api')
    app.register_blueprint(notifications_bp, url_prefix='/api/notifications')
    app.register_blueprint(ocr_bp, url_prefix='/api/ocr')
    app.register_blueprint(currency_bp, url_prefix='/api/currency')
    app.register_blueprint(dashboard_bp, url_prefix='/api/adl')


def _seed_feature_flags():
    """Ensure default feature flags exist in the DB (runs once on startup)."""
    try:
        from app import db
        from app.models import FeatureFlag
        defaults = [
            ('PAYMENTS_ENABLED', 'false', 'הפעלת מנגנון תשלום — כשכבוי הקבוצות מופעלות חינם (מצב בטא)'),
        ]
        for key, value, description in defaults:
            if not FeatureFlag.query.filter_by(key=key).first():
                db.session.add(FeatureFlag(key=key, value=value, description=description))
        db.session.commit()
    except Exception:
        pass  # DB may not be ready yet during first migration


def _register_jwt_handlers(jwt_manager):
    from app.common.errors import error_response

    @jwt_manager.expired_token_loader
    def expired_token_callback(jwt_header, jwt_data):
        return error_response('Token expired', 401)

    @jwt_manager.invalid_token_loader
    def invalid_token_callback(error):
        return error_response('Invalid token', 401)

    @jwt_manager.unauthorized_loader
    def missing_token_callback(error):
        return error_response('Authorization required', 401)

    @jwt_manager.revoked_token_loader
    def revoked_token_callback(jwt_header, jwt_data):
        return error_response('Token has been revoked', 401)
