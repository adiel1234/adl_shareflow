"""add iap_processed_transactions table

Revision ID: a4b5c6d7e8f9
Revises: c3d4e5f6a7b8
Create Date: 2026-09-30

"""
from alembic import op
import sqlalchemy as sa


revision = 'a4b5c6d7e8f9'
down_revision = 'c3d4e5f6a7b8'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'iap_processed_transactions',
        sa.Column('id', sa.UUID(as_uuid=False), nullable=False),
        sa.Column('transaction_id', sa.String(length=128), nullable=False),
        sa.Column('product_id', sa.String(length=120), nullable=False),
        sa.Column('platform', sa.String(length=16), nullable=False),
        sa.Column('operation', sa.String(length=20), nullable=False),
        sa.Column('group_id', sa.UUID(as_uuid=False), nullable=True),
        sa.Column('user_id', sa.UUID(as_uuid=False), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['group_id'], ['groups.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('transaction_id'),
    )
    op.create_index(
        op.f('ix_iap_processed_transactions_transaction_id'),
        'iap_processed_transactions',
        ['transaction_id'],
        unique=True,
    )
    op.create_index(
        op.f('ix_iap_processed_transactions_group_id'),
        'iap_processed_transactions',
        ['group_id'],
        unique=False,
    )
    op.create_index(
        op.f('ix_iap_processed_transactions_user_id'),
        'iap_processed_transactions',
        ['user_id'],
        unique=False,
    )


def downgrade():
    op.drop_index(op.f('ix_iap_processed_transactions_user_id'), table_name='iap_processed_transactions')
    op.drop_index(op.f('ix_iap_processed_transactions_group_id'), table_name='iap_processed_transactions')
    op.drop_index(op.f('ix_iap_processed_transactions_transaction_id'), table_name='iap_processed_transactions')
    op.drop_table('iap_processed_transactions')
