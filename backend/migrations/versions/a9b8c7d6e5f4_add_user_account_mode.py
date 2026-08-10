"""add_user_account_mode

Revision ID: a9b8c7d6e5f4
Revises: d8e9f0a1b2c3
Create Date: 2026-08-10 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = 'a9b8c7d6e5f4'
down_revision = 'd8e9f0a1b2c3'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'users',
        sa.Column(
            'account_mode',
            sa.String(length=20),
            nullable=False,
            server_default='pilot',
        ),
    )
    # Existing production users after wipe are empty; default pilot matches current phase.
    op.create_index('ix_users_account_mode', 'users', ['account_mode'])


def downgrade():
    op.drop_index('ix_users_account_mode', table_name='users')
    op.drop_column('users', 'account_mode')
