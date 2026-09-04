from unittest.mock import MagicMock

from sqlalchemy.orm import Session

from models import Element
from repositories import element_repository


def test_get_elements_uses_session_scalars():
    # Arrange
    session = MagicMock(spec=Session)
    element = Element(
        atomic_number=29,
        name="Copper",
        symbol="Cu",
    )
    session.scalars.return_value = [element]

    # Act
    result = element_repository.get_elements(
        session,
        name="copper",
        color="reddish",
    )

    # Assert
    assert result == [element]
    session.scalars.assert_called_once()


def test_add_element_commits_and_refreshes():
    # Arrange
    session = MagicMock(spec=Session)
    element = Element(
        atomic_number=29,
        name="Copper",
        symbol="Cu",
    )

    # Act
    result = element_repository.add_element(session, element)

    # Assert
    assert result is element
    session.add.assert_called_once_with(element)
    session.commit.assert_called_once_with()
    session.refresh.assert_called_once_with(element)


def test_update_element_applies_changes():
    # Arrange
    session = MagicMock(spec=Session)
    element = Element(
        atomic_number=29,
        name="Copper",
        symbol="Cu",
    )
    session.get.return_value = element

    # Act
    result = element_repository.update_element(
        session,
        29,
        {"name": "Updated Copper", "atomic_number": 99},
    )

    # Assert
    assert result is element
    assert element.name == "Updated Copper"
    assert element.atomic_number == 29
    session.commit.assert_called_once_with()


def test_delete_element_returns_false_when_missing():
    # Arrange
    session = MagicMock(spec=Session)
    session.get.return_value = None

    # Act
    result = element_repository.delete_element(session, 999)

    # Assert
    assert result is False
    session.delete.assert_not_called()
    session.commit.assert_not_called()
