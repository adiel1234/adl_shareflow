"""
SQLAlchemy models — all tables for ADL ShareFlow.
UUIDs everywhere. DECIMAL for all money. Timestamps on every table.
"""
import uuid
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import (
    Boolean, Column, Date, DateTime, Enum, ForeignKey,
    Integer, Numeric, String, Text, UniqueConstraint
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import relationship

from app import db


def _uuid():
    return str(uuid.uuid4())


def _now():
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# Users
# ---------------------------------------------------------------------------

class User(db.Model):
    __tablename__ = 'users'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    email = Column(String(255), unique=True, nullable=False, index=True)
    display_name = Column(String(100), nullable=False)
    avatar_url = Column(Text)
    phone = Column(String(20))
    default_currency = Column(String(3), nullable=False, default='ILS')
    language = Column(String(5), nullable=False, default='he')
    plan = Column(String(20), nullable=False, default='free')
    is_active = Column(Boolean, nullable=False, default=True)
    # Payment details (for settling debts via Bit / PayBox / bank transfer)
    payment_phone = Column(String(20), nullable=True)   # Bit / PayBox phone
    bank_name = Column(String(50), nullable=True)
    bank_branch = Column(String(10), nullable=True)
    bank_account_number = Column(String(30), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=_now, onupdate=_now)

    # Relationships
    identities = relationship('UserIdentity', back_populates='user', cascade='all, delete-orphan')
    refresh_tokens = relationship('RefreshToken', back_populates='user', cascade='all, delete-orphan')
    fcm_tokens = relationship('FCMToken', back_populates='user', cascade='all, delete-orphan')
    group_memberships = relationship('GroupMember', back_populates='user', cascade='all, delete-orphan')
    notifications = relationship('Notification', back_populates='user', cascade='all, delete-orphan')
    subscriptions = relationship('Subscription', back_populates='user', cascade='all, delete-orphan')

    def to_dict(self, include_private=False):
        data = {
            'id': self.id,
            'email': self.email,
            'display_name': self.display_name,
            'avatar_url': self.avatar_url,
            'phone': self.phone,
            'default_currency': self.default_currency,
            'language': self.language,
            'plan': self.plan,
            'payment_phone': self.payment_phone,
            'bank_name': self.bank_name,
            'bank_branch': self.bank_branch,
            'bank_account_number': self.bank_account_number,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
        return data

    def __repr__(self):
        return f'<User {self.email}>'


class UserIdentity(db.Model):
    __tablename__ = 'user_identities'
    __table_args__ = (UniqueConstraint('provider', 'provider_user_id'),)

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id = Column(UUID(as_uuid=False), ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    provider = Column(Enum('email', 'google', 'apple', name='auth_provider'), nullable=False)
    provider_user_id = Column(String(255), nullable=False)
    password_hash = Column(Text)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_now)

    user = relationship('User', back_populates='identities')


class RefreshToken(db.Model):
    __tablename__ = 'refresh_tokens'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id = Column(UUID(as_uuid=False), ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    token_hash = Column(Text, nullable=False, unique=True)
    device_info = Column(Text)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_now)

    user = relationship('User', back_populates='refresh_tokens')


class FCMToken(db.Model):
    __tablename__ = 'fcm_tokens'
    __table_args__ = (UniqueConstraint('user_id', 'token'),)

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id = Column(UUID(as_uuid=False), ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    token = Column(Text, nullable=False)
    platform = Column(Enum('ios', 'android', name='fcm_platform'), nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_now)

    user = relationship('User', back_populates='fcm_tokens')


# ---------------------------------------------------------------------------
# Groups
# ---------------------------------------------------------------------------

class Group(db.Model):
    __tablename__ = 'groups'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    name = Column(String(100), nullable=False)
    description = Column(Text)
    base_currency = Column(String(3), nullable=False, default='ILS')
    category = Column(String(50))  # apartment, trip, vehicle, other
    created_by = Column(UUID(as_uuid=False), ForeignKey('users.id'), nullable=False)
    invite_code = Column(String(12), unique=True, index=True)
    is_active = Column(Boolean, nullable=False, default=True)
    is_closed = Column(Boolean, nullable=False, default=False)
    closed_at = Column(DateTime(timezone=True), nullable=True)
    # Lifecycle / monetization
    group_type = Column(String(10), nullable=False, default='event')   # 'event' | 'ongoing'
    group_state = Column(String(12), nullable=False, default='free')   # 'free' | 'limited' | 'active' | 'expired' | 'read_only'
    pricing_tier = Column(String(10), nullable=True)                   # '10' | '15' | '25' (event) / '5' | '8' | '12' (ongoing)
    activated_at = Column(DateTime(timezone=True), nullable=True)
    expiry_date = Column(DateTime(timezone=True), nullable=True)
    max_participants_snapshot = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=_now, onupdate=_now)

    members = relationship('GroupMember', back_populates='group', cascade='all, delete-orphan')
    expenses = relationship('Expense', back_populates='group', cascade='all, delete-orphan')
    settlements = relationship('Settlement', back_populates='group', cascade='all, delete-orphan')
    payments = relationship('GroupPayment', back_populates='group', cascade='all, delete-orphan')

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'base_currency': self.base_currency,
            'category': self.category,
            'invite_code': self.invite_code,
            'is_active': self.is_active,
            'is_closed': self.is_closed,
            'closed_at': self.closed_at.isoformat() if self.closed_at else None,
            'group_type': self.group_type,
            'group_state': self.group_state,
            'pricing_tier': self.pricing_tier,
            'activated_at': self.activated_at.isoformat() if self.activated_at else None,
            'expiry_date': self.expiry_date.isoformat() if self.expiry_date else None,
            'max_participants_snapshot': self.max_participants_snapshot,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'member_count': len(self.members),
        }


class GroupMember(db.Model):
    __tablename__ = 'group_members'
    __table_args__ = (UniqueConstraint('group_id', 'user_id'),)

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    group_id = Column(UUID(as_uuid=False), ForeignKey('groups.id', ondelete='CASCADE'), nullable=False, index=True)
    user_id = Column(UUID(as_uuid=False), ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    role = Column(Enum('admin', 'member', name='member_role'), nullable=False, default='member')
    nickname = Column(String(50))
    joined_at = Column(DateTime(timezone=True), nullable=False, default=_now)

    group = relationship('Group', back_populates='members')
    user = relationship('User', back_populates='group_memberships')

    def to_dict(self):
        return {
            'id': self.id,
            'group_id': self.group_id,
            'user_id': self.user_id,
            'role': self.role,
            'nickname': self.nickname,
            'joined_at': self.joined_at.isoformat() if self.joined_at else None,
            'user': self.user.to_dict() if self.user else None,
        }


# ---------------------------------------------------------------------------
# Expenses
# ---------------------------------------------------------------------------

class Expense(db.Model):
    __tablename__ = 'expenses'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    group_id = Column(UUID(as_uuid=False), ForeignKey('groups.id', ondelete='CASCADE'), nullable=False, index=True)
    paid_by = Column(UUID(as_uuid=False), ForeignKey('users.id'), nullable=False)
    title = Column(String(200), nullable=False)
    original_amount = Column(Numeric(12, 2), nullable=False)
    original_currency = Column(String(3), nullable=False)
    exchange_rate = Column(Numeric(12, 6), nullable=False, default=Decimal('1.000000'))
    converted_amount = Column(Numeric(12, 2), nullable=False)
    category = Column(String(50))
    split_type = Column(
        Enum('equal', 'exact', 'percentage', name='split_type'),
        nullable=False, default='equal'
    )
    receipt_id = Column(UUID(as_uuid=False), ForeignKey('receipts.id'), nullable=True)
    expense_date = Column(Date, nullable=False)
    notes = Column(Text)
    created_by = Column(UUID(as_uuid=False), ForeignKey('users.id'), nullable=False)
    # System-generated expenses (platform payments injected as group expenses)
    is_system_expense = Column(Boolean, nullable=False, default=False)
    expense_source = Column(String(20), nullable=True)  # 'activation' | 'extension' | 'renewal'
    created_at = Column(DateTime(timezone=True), nullable=False, default=_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=_now, onupdate=_now)

    group = relationship('Group', back_populates='expenses')
    payer = relationship('User', foreign_keys=[paid_by])
    participants = relationship('ExpenseParticipant', back_populates='expense', cascade='all, delete-orphan')
    receipt = relationship('Receipt', foreign_keys=[receipt_id])

    def to_dict(self):
        return {
            'id': self.id,
            'group_id': self.group_id,
            'paid_by': self.paid_by,
            'payer': self.payer.to_dict() if self.payer else None,
            'created_by': self.created_by,
            'title': self.title,
            'original_amount': str(self.original_amount),
            'original_currency': self.original_currency,
            'exchange_rate': str(self.exchange_rate),
            'converted_amount': str(self.converted_amount),
            'category': self.category,
            'split_type': self.split_type,
            'expense_date': self.expense_date.isoformat() if self.expense_date else None,
            'notes': self.notes,
            'is_system_expense': self.is_system_expense,
            'expense_source': self.expense_source,
            'participants': [p.to_dict() for p in self.participants],
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
        }


class ExpenseParticipant(db.Model):
    __tablename__ = 'expense_participants'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    expense_id = Column(UUID(as_uuid=False), ForeignKey('expenses.id', ondelete='CASCADE'), nullable=False, index=True)
    user_id = Column(UUID(as_uuid=False), ForeignKey('users.id'), nullable=False)
    share_amount = Column(Numeric(12, 2), nullable=False)
    share_percentage = Column(Numeric(5, 2))
    is_settled = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_now)

    expense = relationship('Expense', back_populates='participants')
    user = relationship('User')

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'user': self.user.to_dict() if self.user else None,
            'share_amount': str(self.share_amount),
            'share_percentage': str(self.share_percentage) if self.share_percentage else None,
            'is_settled': self.is_settled,
        }


# ---------------------------------------------------------------------------
# Settlements
# ---------------------------------------------------------------------------

class Settlement(db.Model):
    __tablename__ = 'settlements'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    group_id = Column(UUID(as_uuid=False), ForeignKey('groups.id', ondelete='CASCADE'), nullable=False, index=True)
    from_user_id = Column(UUID(as_uuid=False), ForeignKey('users.id'), nullable=False)
    to_user_id = Column(UUID(as_uuid=False), ForeignKey('users.id'), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(3), nullable=False)
    status = Column(
        Enum('pending', 'confirmed', 'cancelled', name='settlement_status'),
        nullable=False, default='pending'
    )
    notes = Column(Text)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_now)
    confirmed_at = Column(DateTime(timezone=True))

    group = relationship('Group', back_populates='settlements')
    from_user = relationship('User', foreign_keys=[from_user_id])
    to_user = relationship('User', foreign_keys=[to_user_id])

    def to_dict(self):
        return {
            'id': self.id,
            'group_id': self.group_id,
            'from_user_id': self.from_user_id,
            'from_user': self.from_user.to_dict() if self.from_user else None,
            'to_user_id': self.to_user_id,
            'to_user': self.to_user.to_dict() if self.to_user else None,
            'amount': str(self.amount),
            'currency': self.currency,
            'status': self.status,
            'notes': self.notes,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'confirmed_at': self.confirmed_at.isoformat() if self.confirmed_at else None,
        }


# ---------------------------------------------------------------------------
# OCR / Receipts
# ---------------------------------------------------------------------------

class Receipt(db.Model):
    __tablename__ = 'receipts'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id = Column(UUID(as_uuid=False), ForeignKey('users.id'), nullable=False)
    group_id = Column(UUID(as_uuid=False), ForeignKey('groups.id'))
    image_url = Column(Text, nullable=False)
    ocr_raw = Column(JSONB)
    extracted_amount = Column(Numeric(12, 2))
    extracted_merchant = Column(String(200))
    extracted_date = Column(Date)
    status = Column(
        Enum('pending', 'confirmed', 'failed', name='receipt_status'),
        nullable=False, default='pending'
    )
    created_at = Column(DateTime(timezone=True), nullable=False, default=_now)

    def to_dict(self):
        return {
            'id': self.id,
            'image_url': self.image_url,
            'extracted_amount': str(self.extracted_amount) if self.extracted_amount else None,
            'extracted_merchant': self.extracted_merchant,
            'extracted_date': self.extracted_date.isoformat() if self.extracted_date else None,
            'status': self.status,
        }


# ---------------------------------------------------------------------------
# Currency
# ---------------------------------------------------------------------------

class ExchangeRate(db.Model):
    __tablename__ = 'exchange_rates'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    from_currency = Column(String(3), nullable=False)
    to_currency = Column(String(3), nullable=False)
    rate = Column(Numeric(12, 6), nullable=False)
    source = Column(Enum('manual', 'api', name='rate_source'), nullable=False, default='manual')
    fetched_at = Column(DateTime(timezone=True), nullable=False, default=_now)

    def to_dict(self):
        return {
            'from_currency': self.from_currency,
            'to_currency': self.to_currency,
            'rate': str(self.rate),
            'source': self.source,
            'fetched_at': self.fetched_at.isoformat() if self.fetched_at else None,
        }


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

class Notification(db.Model):
    __tablename__ = 'notifications'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id = Column(UUID(as_uuid=False), ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    type = Column(String(50), nullable=False)
    title = Column(String(200))
    body = Column(Text)
    data = Column(JSONB)
    is_read = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_now)

    user = relationship('User', back_populates='notifications')

    def to_dict(self):
        return {
            'id': self.id,
            'type': self.type,
            'title': self.title,
            'body': self.body,
            'data': self.data,
            'is_read': self.is_read,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }


# ---------------------------------------------------------------------------
# Reminder Settings
# ---------------------------------------------------------------------------

class ReminderSettings(db.Model):
    __tablename__ = 'reminder_settings'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id = Column(UUID(as_uuid=False), ForeignKey('users.id', ondelete='CASCADE'),
                     nullable=False, unique=True, index=True)
    # 'none' | 'daily' | 'every_2_days' | 'weekly' | 'biweekly' | 'manual'
    frequency = Column(String(20), nullable=False, default='manual')
    # comma-separated: 'app', 'whatsapp', or 'app,whatsapp'
    platforms = Column(String(50), nullable=False, default='app')
    enabled = Column(Boolean, nullable=False, default=True)
    last_sent_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=_now, onupdate=_now)

    user = relationship('User')

    def to_dict(self):
        return {
            'frequency': self.frequency,
            'platforms': self.platforms.split(',') if self.platforms else ['app'],
            'enabled': self.enabled,
        }


# ---------------------------------------------------------------------------
# Group Payments (lifecycle monetization audit trail)
# ---------------------------------------------------------------------------

class GroupPayment(db.Model):
    __tablename__ = 'group_payments'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    group_id = Column(UUID(as_uuid=False), ForeignKey('groups.id', ondelete='CASCADE'), nullable=False, index=True)
    payer_id = Column(UUID(as_uuid=False), ForeignKey('users.id'), nullable=False)
    amount = Column(Numeric(10, 2), nullable=False)
    payment_type = Column(String(15), nullable=False)   # 'activation' | 'extension' | 'renewal'
    split_among_group = Column(Boolean, nullable=False, default=False)
    expense_id = Column(UUID(as_uuid=False), ForeignKey('expenses.id'), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_now)

    group = relationship('Group', back_populates='payments')
    payer = relationship('User', foreign_keys=[payer_id])
    expense = relationship('Expense', foreign_keys=[expense_id])

    def to_dict(self):
        return {
            'id': self.id,
            'group_id': self.group_id,
            'payer_id': self.payer_id,
            'amount': str(self.amount),
            'payment_type': self.payment_type,
            'split_among_group': self.split_among_group,
            'expense_id': self.expense_id,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }


# ---------------------------------------------------------------------------
# Plans / Subscriptions / Feature Flags
# ---------------------------------------------------------------------------

class Plan(db.Model):
    __tablename__ = 'plans'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    name = Column(String(50), nullable=False)
    price_monthly = Column(Numeric(8, 2))
    features = Column(JSONB)
    is_active = Column(Boolean, nullable=False, default=True)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'price_monthly': str(self.price_monthly) if self.price_monthly else None,
            'features': self.features,
        }


class Subscription(db.Model):
    __tablename__ = 'subscriptions'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id = Column(UUID(as_uuid=False), ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    plan_id = Column(UUID(as_uuid=False), ForeignKey('plans.id'), nullable=False)
    status = Column(String(20), nullable=False, default='active')
    started_at = Column(DateTime(timezone=True), nullable=False, default=_now)
    expires_at = Column(DateTime(timezone=True))

    user = relationship('User', back_populates='subscriptions')
    plan = relationship('Plan')


class FeatureFlag(db.Model):
    __tablename__ = 'feature_flags'

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    key = Column(String(100), unique=True, nullable=False)
    value = Column(JSONB)
    description = Column(Text)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=_now, onupdate=_now)
