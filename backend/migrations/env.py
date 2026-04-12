from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from alembic import context
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from config import get_config
from app import create_app, db

config = context.config

if config.config_file_name is not None:
    import pathlib
    ini_path = pathlib.Path(config.config_file_name)
    if not ini_path.is_absolute():
        # resolve relative to the backend root (one level above migrations/)
        ini_path = pathlib.Path(__file__).parent.parent / ini_path
    if ini_path.exists():
        fileConfig(str(ini_path))

app = create_app(get_config())
target_metadata = db.metadata


def run_migrations_offline():
    url = app.config['SQLALCHEMY_DATABASE_URI']
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={'paramstyle': 'named'},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online():
    connectable = engine_from_config(
        {'sqlalchemy.url': app.config['SQLALCHEMY_DATABASE_URI']},
        prefix='sqlalchemy.',
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
