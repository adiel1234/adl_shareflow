"""Add group lifecycle, payment details, and system expenses

Revision ID: f1a2b3c4d5e6
Revises: ead3d281b414
Create Date: 2026-03-31

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = 'f1a2b3c4d5e6'
down_revision = 'ead3d281b414'
branch_labels = None
depends_on = None


def upgrade():
    # -- groups: lifecycle fields --
    op.add_column('groups', sa.Column('group_type', sa.String(10), nullable=False, server_default='event'))
    op.add_column('groups', sa.Column('group_state', sa.String(12), nullable=False, server_default='free'))
    op.add_column('groups', sa.Column('pricing_tier', sa.String(10), nullable=True))
    op.add_column('groups', sa.Column('activated_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('groups', sa.Column('expiry_date', sa.DateTime(timezone=True), nullable=True))
    op.add_column('groups', sa.Column('max_participants_snapshot', sa.Integer(), nullable=True))

    # -- expenses: system-expense fields --
    op.add_column('expenses', sa.Column('is_system_expense', sa.Boolean(), nullable=False, server_default='false'))
    op.add_column('expenses', sa.Column('expense_source', sa.String(20), nullable=True))

    # -- users: payment details --
    op.add_column('users', sa.Column('payment_phone', sa.String(20), nullable=True))
    op.add_column('users', sa.Column('bank_name', sa.String(50), nullable=True))
    op.add_column('users', sa.Column('bank_branch', sa.String(10), nullable=True))
    op.add_column('users', sa.Column('bank_account_number', sa.String(30), nullable=True))

    # -- new table: group_payments --
    op.create_table(
        'group_payments',
        sa.Column('id', UUID(as_uuid=False), primary_key=True),
        sa.Column('group_id', UUID(as_uuid=False),
                  sa.ForeignKey('groups.id', ondelete='CASCADE'), nullable=False),
        sa.Column('payer_id', UUID(as_uuid=False),
                  sa.ForeignKey('users.id'), nullable=False),
        sa.Column('amount', sa.Numeric(10, 2), nullable=False),
        sa.Column('payment_type', sa.String(15), nullable=False),
        sa.Column('split_among_group', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('expense_id', UUID(as_uuid=False),
                  sa.ForeignKey('expenses.id'), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_group_payments_group_id', 'group_payments', ['group_id'])


def downgrade():
    op.drop_table('group_payments')

    op.drop_column('users', 'bank_account_number')
    op.drop_column('users', 'bank_branch')
    op.drop_column('users', 'bank_name')
    op.drop_column('users', 'payment_phone')

    op.drop_column('expenses', 'expense_source')
    op.drop_column('expenses', 'is_system_expense')

    op.drop_column('groups', 'max_participants_snapshot')
    op.drop_column('groups', 'expiry_date')
    op.drop_column('groups', 'activated_at')
    op.drop_column('groups', 'pricing_tier')
    op.drop_column('groups', 'group_state')
    op.drop_column('groups', 'group_type')
