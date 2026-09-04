from unittest.mock import MagicMock

from sqlalchemy.orm import Session

from models import Alloy
from repositories import alloy_repository


def test_get_alloys_uses_session_scalars():
    # Arrange
    session = MagicMock(spec=Session)
    alloy = Alloy(alloy_id=2, name="Bronze")
    session.scalars.return_value = [alloy]

    # Act
    result = alloy_repository.get_alloys(
        session,
        name="bronze",
        color="brown",
    )

    # Assert
    assert result == [alloy]
    session.scalars.assert_called_once()


def test_add_alloy_commits_and_refreshes():
    # Arrange
    session = MagicMock(spec=Session)
    alloy = Alloy(name="Bronze")

    # Act
    result = alloy_repository.add_alloy(session, alloy)

    # Assert
    assert result is alloy
    session.add.assert_called_once_with(alloy)
    session.commit.assert_called_once_with()
    session.refresh.assert_called_once_with(alloy)


def test_delete_alloy_deletes_existing_model():
    # Arrange
    session = MagicMock(spec=Session)
    alloy = Alloy(alloy_id=2, name="Bronze")
    session.get.return_value = alloy

    # Act
    result = alloy_repository.delete_alloy(session, 2)

    # Assert
    assert result is True
    session.delete.assert_called_once_with(alloy)
    session.commit.assert_called_once_with()
