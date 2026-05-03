"""add_paybox_link_to_users

Revision ID: a1b2c3d4e5f6
Revises: 480ff4d3679c
Create Date: 2026-05-04 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = 'a1b2c3d4e5f6'
down_revision = '480ff4d3679c'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('users', sa.Column('paybox_link', sa.String(500), nullable=True))


def downgrade():
    op.drop_column('users', 'paybox_link')
