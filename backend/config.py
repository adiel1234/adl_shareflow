import os
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv()


class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key')
    DEBUG = False
    TESTING = False

    # Database
    SQLALCHEMY_DATABASE_URI = os.getenv('DATABASE_URL', 'postgresql://shareflow:shareflow_pass@localhost:5432/shareflow')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_pre_ping': True,
        'pool_recycle': 300,
    }

    # JWT
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'dev-jwt-secret')
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=int(os.getenv('JWT_ACCESS_TOKEN_EXPIRES_MINUTES', 60)))
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=int(os.getenv('JWT_REFRESH_TOKEN_EXPIRES_DAYS', 30)))
    JWT_TOKEN_LOCATION = ['headers']
    JWT_HEADER_NAME = 'Authorization'
    JWT_HEADER_TYPE = 'Bearer'

    # Google OAuth
    GOOGLE_CLIENT_ID = os.getenv('GOOGLE_CLIENT_ID', '')

    # Apple Sign-In
    APPLE_CLIENT_ID = os.getenv('APPLE_CLIENT_ID', '')
    APPLE_TEAM_ID = os.getenv('APPLE_TEAM_ID', '')
    APPLE_KEY_ID = os.getenv('APPLE_KEY_ID', '')
    APPLE_PRIVATE_KEY_PATH = os.getenv('APPLE_PRIVATE_KEY_PATH', '')

    # Google Vision
    GOOGLE_APPLICATION_CREDENTIALS = os.getenv('GOOGLE_APPLICATION_CREDENTIALS', '')

    # Firebase
    FIREBASE_CREDENTIALS_PATH = os.getenv('FIREBASE_CREDENTIALS_PATH', '')

    # Storage
    STORAGE_BACKEND = os.getenv('STORAGE_BACKEND', 'local')
    STORAGE_LOCAL_PATH = os.getenv('STORAGE_LOCAL_PATH', './uploads')
    AWS_ACCESS_KEY_ID = os.getenv('AWS_ACCESS_KEY_ID', '')
    AWS_SECRET_ACCESS_KEY = os.getenv('AWS_SECRET_ACCESS_KEY', '')
    AWS_S3_BUCKET = os.getenv('AWS_S3_BUCKET', '')
    AWS_S3_REGION = os.getenv('AWS_S3_REGION', 'us-east-1')

    # ADL Dashboard
    ADL_CONTROL_DATABASE_URL = os.getenv('ADL_CONTROL_DATABASE_URL', '')

    # CORS
    CORS_ORIGINS = os.getenv('CORS_ORIGINS', 'http://localhost:3000').split(',')

    # Max upload size: 10MB
    MAX_CONTENT_LENGTH = 10 * 1024 * 1024


class DevelopmentConfig(Config):
    DEBUG = True
    FLASK_ENV = 'development'


class ProductionConfig(Config):
    DEBUG = False
    FLASK_ENV = 'production'
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_pre_ping': True,
        'pool_recycle': 300,
        'pool_size': 10,
        'max_overflow': 20,
    }


class TestingConfig(Config):
    TESTING = True
    DEBUG = True
    # Use local PostgreSQL (same user as dev) or SQLite fallback
    SQLALCHEMY_DATABASE_URI = os.getenv(
        'TEST_DATABASE_URL',
        os.getenv('DATABASE_URL', 'sqlite:///test_shareflow.db').replace(
            '/shareflow', '/shareflow_test'
        )
    )
    SQLALCHEMY_ENGINE_OPTIONS = {}  # No pooling for tests
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=5)
    ADL_ADMIN_KEY = 'shareflow-adl-admin-dev-key'


config_map = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
}


def get_config():
    env = os.getenv('FLASK_ENV', 'development')
    return config_map.get(env, DevelopmentConfig)
