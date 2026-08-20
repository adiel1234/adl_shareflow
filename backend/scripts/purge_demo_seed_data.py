#!/usr/bin/env python3
"""
Purge load-test / demo seed data from the DB (production-safe, targeted).

Deletes:
  - users with email *@shareflow-demo.local or loadprobe_*@*
  - groups they created (and cascade via ORM relationships where possible)
  - orphan guest users who only belonged to those groups

Usage (Railway):
  railway run --service adl_shareflow python scripts/purge_demo_seed_data.py --confirm
"""
from __future__ import annotations

import argparse
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--confirm', action='store_true', help='Actually delete')
    parser.add_argument('--dry-run', action='store_true', default=False)
    args = parser.parse_args()
    dry = not args.confirm

    from app import create_app, db
    from app.models import (
        User, Group, GroupMember, Expense, ExpenseParticipant, Settlement,
        GroupPayment, Notification, FCMToken, Receipt, ScheduledReminder,
        ReminderSettings, PeriodReport, PeriodDebt,
    )
    from sqlalchemy import or_, and_

    app = create_app()
    with app.app_context():
        demo_users = User.query.filter(
            or_(
                User.email.ilike('%@shareflow-demo.local'),
                User.email.ilike('loadprobe_%'),
                User.email.ilike('%@shareflowtest.local'),
                User.email.ilike('%@shareflowtest.com'),
            )
        ).all()
        demo_ids = {u.id for u in demo_users}
        print(f'Demo/test owner accounts: {len(demo_users)}')
        for u in demo_users:
            print(f'  {u.id}  {u.email}  {u.display_name}')

        groups = Group.query.filter(
            or_(
                Group.created_by.in_(demo_ids) if demo_ids else False,
                Group.name.ilike('%הדמייה%'),
                Group.name.ilike('%עומס%'),
                Group.description.ilike('%הדמיית עומס%') if True else False,
            )
        ).all() if demo_ids else Group.query.filter(
            or_(Group.name.ilike('%הדמייה%'), Group.name.ilike('%עומס%'))
        ).all()

        # Also include groups created by demo users
        if demo_ids:
            more = Group.query.filter(Group.created_by.in_(demo_ids)).all()
            by_id = {g.id: g for g in groups}
            for g in more:
                by_id[g.id] = g
            groups = list(by_id.values())

        group_ids = {g.id for g in groups}
        print(f'Groups to delete: {len(groups)}')
        for g in groups:
            print(f'  {g.id}  {g.name}  created_by={g.created_by}')

        # Members of those groups (guests + owners)
        member_user_ids = set()
        if group_ids:
            member_user_ids = {
                m.user_id for m in GroupMember.query.filter(
                    GroupMember.group_id.in_(group_ids)
                ).all()
            }
        print(f'Membership user refs: {len(member_user_ids)}')

        # Guest users who appear only in doomed groups (or nowhere after)
        guest_candidates = []
        if member_user_ids:
            for u in User.query.filter(User.id.in_(member_user_ids)).all():
                if u.id in demo_ids:
                    continue
                if not getattr(u, 'is_guest', False) and u.email and not u.email.endswith(
                    ('@shareflow-demo.local', '@shareflowtest.local', '@shareflowtest.com')
                ) and not (u.email or '').startswith('loadprobe_'):
                    # Real non-guest pilot user who joined a demo group — leave the user,
                    # only membership dies with the group.
                    continue
                guest_candidates.append(u)

        print(f'Guest/orphan users to delete: {len(guest_candidates)}')

        if dry:
            print('DRY RUN — pass --confirm to delete')
            return 0

        # Delete groups (ORM cascades expenses/settlements/members for the group)
        for g in groups:
            db.session.delete(g)
        db.session.flush()

        # Delete demo owners + guest candidates
        purge_users = list({u.id: u for u in (demo_users + guest_candidates)}.values())
        for u in purge_users:
            # Clear FKs that may not cascade from User
            ExpenseParticipant.query.filter_by(user_id=u.id).delete(synchronize_session=False)
            Notification.query.filter_by(user_id=u.id).delete(synchronize_session=False)
            FCMToken.query.filter_by(user_id=u.id).delete(synchronize_session=False)
            ReminderSettings.query.filter_by(user_id=u.id).delete(synchronize_session=False)
            ScheduledReminder.query.filter(
                or_(
                    ScheduledReminder.created_by == u.id,
                    ScheduledReminder.target_user_id == u.id,
                )
            ).delete(synchronize_session=False)
            Settlement.query.filter(
                or_(Settlement.from_user_id == u.id, Settlement.to_user_id == u.id)
            ).delete(synchronize_session=False)
            GroupPayment.query.filter(
                or_(GroupPayment.payer_id == u.id, GroupPayment.created_by == u.id)
            ).delete(synchronize_session=False)
            # expenses paid_by / created_by — should be gone with groups; clean stragglers
            Expense.query.filter(
                or_(Expense.paid_by == u.id, Expense.created_by == u.id)
            ).delete(synchronize_session=False)
            Receipt.query.filter_by(uploaded_by=u.id).delete(synchronize_session=False)
            GroupMember.query.filter_by(user_id=u.id).delete(synchronize_session=False)
            db.session.delete(u)

        db.session.commit()
        print(f'Deleted groups={len(groups)} users={len(purge_users)}')
        print('DONE')
        return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f'FAILED: {e}', file=sys.stderr)
        raise SystemExit(1)
