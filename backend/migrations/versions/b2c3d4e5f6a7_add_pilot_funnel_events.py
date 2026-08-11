"""add_pilot_funnel_events

Revision ID: b2c3d4e5f6a7
Revises: a9b8c7d6e5f4
Create Date: 2026-08-11 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = 'b2c3d4e5f6a7'
down_revision = 'a9b8c7d6e5f4'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'pilot_funnel_events',
        sa.Column('id', sa.UUID(as_uuid=False), primary_key=True),
        sa.Column('event', sa.String(length=40), nullable=False),
        sa.Column('platform', sa.String(length=20)),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_pilot_funnel_events_event', 'pilot_funnel_events', ['event'])
    op.create_index('ix_pilot_funnel_events_created_at', 'pilot_funnel_events', ['created_at'])


def downgrade():
    op.drop_index('ix_pilot_funnel_events_created_at', table_name='pilot_funnel_events')
    op.drop_index('ix_pilot_funnel_events_event', table_name='pilot_funnel_events')
    op.drop_table('pilot_funnel_events')
