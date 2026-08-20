"""Unit tests for guest↔real name matching on join."""

from app.groups.name_match import names_similar, normalize_person_name


def test_normalize_collapses_spaces():
    assert normalize_person_name('  אור   שחר ') == 'אור שחר'


def test_exact_match():
    assert names_similar('אור שחר', 'אור שחר')
    assert names_similar('Or Shahar', 'or shahar')


def test_partial_first_name_matches_full():
    assert names_similar('אור', 'אור שחר')
    assert names_similar('אור שחר', 'אור')


def test_partial_last_name_matches_full():
    assert names_similar('שחר', 'אור שחר')


def test_unrelated_names_do_not_match():
    assert not names_similar('דן', 'ירדן')
    assert not names_similar('נועה', 'אור שחר')
    assert not names_similar('', 'אור')
