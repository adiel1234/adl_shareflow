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


def _get_client_ip(request) -> str:
    forwarded = request.headers.get('X-Forwarded-For', '')
    return forwarded.split(',')[0].strip() if forwarded else request.remote_addr or ''


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

    # Deferred deep link — app calls this on first launch to retrieve pending invite code
    @app.get('/api/deferred-link')
    def deferred_link():
        from flask import request, jsonify
        from app.models import DeferredLink
        from datetime import datetime, timezone, timedelta
        client_ip = _get_client_ip(request)
        try:
            expiry = datetime.now(timezone.utc) - timedelta(hours=1)
            entry = db.session.query(DeferredLink).filter(
                DeferredLink.client_ip == client_ip,
                DeferredLink.created_at >= expiry,
            ).first()
            if entry:
                code = entry.invite_code
                db.session.delete(entry)
                db.session.commit()
                return jsonify({'invite_code': code})
        except Exception as e:
            db.session.rollback()
            print(f'[deferred_link] Failed to retrieve: {e}')
        return jsonify({'invite_code': None})

    # Smart join link — opens app if installed, otherwise shows download page
    @app.get('/join/<invite_code>')
    def join_redirect(invite_code):
        from flask import request, redirect, Response
        ANDROID_APK = 'https://github.com/adiel1234/adl_shareflow/releases/latest/download/app-release.apk'
        TESTFLIGHT  = 'https://testflight.apple.com/join/PLACEHOLDER'
        deep_link   = f'shareflow://join/{invite_code}'

        # Save deferred deep link for this visitor's IP (stored in DB, shared across workers)
        client_ip = _get_client_ip(request)
        if client_ip:
            try:
                from app.models import DeferredLink
                from datetime import datetime, timezone, timedelta
                # Delete expired entries and upsert for this IP
                expiry = datetime.now(timezone.utc) - timedelta(hours=1)
                db.session.query(DeferredLink).filter(DeferredLink.created_at < expiry).delete()
                existing = db.session.query(DeferredLink).filter_by(client_ip=client_ip).first()
                if existing:
                    existing.invite_code = invite_code
                    existing.created_at = datetime.now(timezone.utc)
                else:
                    db.session.add(DeferredLink(client_ip=client_ip, invite_code=invite_code))
                db.session.commit()
            except Exception as e:
                db.session.rollback()
                print(f'[deferred_link] Failed to save: {e}')

        page_url = request.url
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
      background: white; border-radius: 24px; padding: 40px 32px;
      max-width: 440px; width: 100%; text-align: center;
      box-shadow: 0 20px 60px rgba(0,0,0,0.2);
    }}
    .logo {{ font-size: 52px; margin-bottom: 12px; }}
    h1 {{ font-size: 22px; font-weight: 700; color: #1a1a2e; margin-bottom: 6px; }}
    .subtitle {{ color: #666; font-size: 14px; margin-bottom: 24px; line-height: 1.5; }}
    .btn {{
      display: flex; align-items: center; justify-content: center; gap: 10px;
      width: 100%; padding: 15px 20px; border-radius: 14px;
      font-size: 16px; font-weight: 600; text-decoration: none;
      margin-bottom: 12px; transition: opacity 0.2s; cursor: pointer;
      border: none;
    }}
    .btn:hover {{ opacity: 0.88; }}
    .btn-primary {{ background: #6C63FF; color: white; }}
    .btn-browser {{ background: #25D366; color: white; font-size: 15px; }}
    .btn-android {{ background: #3DDC84; color: #1a1a2e; }}
    .btn-ios {{ background: #1a1a2e; color: white; }}
    .divider {{ margin: 16px 0; color: #bbb; font-size: 13px; }}
    .code {{ font-family: monospace; font-size: 20px; font-weight: 700;
             letter-spacing: 4px; color: #6C63FF; margin: 12px 0 20px; }}
    .wa-notice {{
      background: #f0fdf4; border: 1.5px solid #25D366; border-radius: 14px;
      padding: 16px; margin-bottom: 16px; display: none;
    }}
    .wa-notice p {{ color: #166534; font-size: 13px; line-height: 1.6; margin-bottom: 10px; }}
    .wa-notice strong {{ font-size: 14px; }}
    #main-actions {{ display: block; }}
  </style>
  <script>
    var DEEP = '{deep_link}';
    var CLIP = 'shareflow-invite:{invite_code}';
    var PAGE = '{page_url}';

    function isInAppBrowser() {{
      var ua = navigator.userAgent || '';
      return /WhatsApp|FBAN|FBAV|Instagram|Snapchat|Line|WeChat|MicroMessenger/i.test(ua);
    }}
    function isIOS() {{ return /iPhone|iPad|iPod/i.test(navigator.userAgent); }}

    function writeClip(then) {{
      if (navigator.clipboard && navigator.clipboard.writeText) {{
        navigator.clipboard.writeText(CLIP).then(then, then);
      }} else {{
        try {{
          var ta = document.createElement('textarea');
          ta.value = CLIP; ta.style.cssText = 'position:fixed;opacity:0';
          document.body.appendChild(ta); ta.focus(); ta.select();
          document.execCommand('copy'); document.body.removeChild(ta);
        }} catch(x) {{}}
        then();
      }}
    }}

    function openInBrowser() {{
      // iOS: x-safari will hand off to Safari; Android: use intent to Chrome
      if (isIOS()) {{
        window.location = 'x-safari:' + PAGE;
      }} else {{
        window.location = 'intent://' + PAGE.replace(/https?:\\/\\//, '') +
          '#Intent;scheme=https;package=com.android.chrome;end';
      }}
    }}

    function openApp() {{
      writeClip(function() {{ window.location = DEEP; }});
    }}

    function dlApp(e, url) {{
      e.preventDefault();
      writeClip(function() {{ window.location = url; }});
    }}

    window.onload = function() {{
      if (isInAppBrowser()) {{
        // WhatsApp/in-app browser: cannot open custom schemes — show notice
        document.getElementById('wa-notice').style.display = 'block';
        document.getElementById('main-actions').style.display = 'none';
      }} else {{
        // Normal browser — try to open app automatically
        window.location = DEEP;
      }}
    }};
  </script>
</head>
<body>
  <div class="card">
    <div class="logo">💸</div>
    <h1>הוזמנת ל-ADL ShareFlow</h1>
    <p class="subtitle">ניהול הוצאות משותפות בקלות</p>
    <div class="code">{invite_code}</div>

    <!-- Shown only inside WhatsApp / in-app browser -->
    <div class="wa-notice" id="wa-notice">
      <p><strong>כדי לפתוח את האפליקציה יש לפתוח קישור זה בדפדפן הרגיל</strong><br>
      לחץ על הכפתור למטה כדי להמשיך</p>
      <button class="btn btn-browser" onclick="openInBrowser()">
        &#127758; פתח בדפדפן
      </button>
    </div>

    <!-- Shown in regular browsers -->
    <div id="main-actions">
      <a class="btn btn-primary" href="#" onclick="event.preventDefault();openApp()">פתח באפליקציה</a>
      <div class="divider">— אין לך את האפליקציה עדיין? —</div>
      <a class="btn btn-android" href="#" onclick="dlApp(event,'{ANDROID_APK}')">🤖 הורד לאנדרואיד</a>
      <a class="btn btn-ios" href="#" onclick="dlApp(event,'{TESTFLIGHT}')">🍎 הורד ל-iPhone</a>
    </div>
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
    from app.download.routes import download_bp

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
    app.register_blueprint(download_bp)


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
