from unittest.mock import MagicMock

from sqlalchemy.orm import Session

from models import Coin
from repositories import coin_repository


def test_get_coins_uses_session_scalars():
    # Arrange
    session = MagicMock(spec=Session)
    coin = Coin(coin_id=1, name="Test Coin", alloy_id=2)
    session.scalars.return_value = [coin]

    # Act
    result = coin_repository.get_coins(
        session,
        name="test",
        country="USA",
        alloy_id=2,
    )

    # Assert
    assert result == [coin]
    session.scalars.assert_called_once()


def test_add_coin_commits_and_refreshes():
    # Arrange
    session = MagicMock(spec=Session)
    coin = Coin(name="Test Coin", alloy_id=2)

    # Act
    result = coin_repository.add_coin(session, coin)

    # Assert
    assert result is coin
    session.add.assert_called_once_with(coin)
    session.commit.assert_called_once_with()
    session.refresh.assert_called_once_with(coin)


def test_update_coin_returns_none_when_missing():
    # Arrange
    session = MagicMock(spec=Session)
    session.get.return_value = None

    # Act
    result = coin_repository.update_coin(
        session,
        999,
        {"name": "Missing Coin"},
    )

    # Assert
    assert result is None
    session.commit.assert_not_called()
