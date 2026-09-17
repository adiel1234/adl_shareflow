from types import SimpleNamespace

from app.users.account_deletion import is_deleted_account


def test_is_deleted_account_by_mode():
    assert is_deleted_account(SimpleNamespace(account_mode='deleted', email='a@b.com'))


def test_is_deleted_account_by_email():
    user = SimpleNamespace(
        account_mode='pilot',
        email='deleted+abc@invalid.shareflow',
    )
    assert is_deleted_account(user)


def test_is_deleted_account_active():
    user = SimpleNamespace(account_mode='active', email='ada@example.com')
    assert not is_deleted_account(user)
