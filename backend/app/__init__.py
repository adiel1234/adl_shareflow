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
