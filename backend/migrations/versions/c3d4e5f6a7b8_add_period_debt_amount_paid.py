"""add amount_paid to period_debts

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-08-26 21:30:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = 'c3d4e5f6a7b8'
down_revision = 'b2c3d4e5f6a7'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'period_debts',
        sa.Column(
            'amount_paid',
            sa.Numeric(12, 2),
            nullable=False,
            server_default='0',
        ),
    )


def downgrade():
    op.drop_column('period_debts', 'amount_paid')
