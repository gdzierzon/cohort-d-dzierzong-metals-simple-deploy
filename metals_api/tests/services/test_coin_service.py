from unittest.mock import MagicMock

import pytest

from dtos import CreateCoinDTO, UpdateCoinDTO
from models import Alloy, Coin
from services import coin_service
from services.exceptions import BusinessValidationError


def test_list_coins_uses_mocked_database_session(monkeypatch, mocked_session_factory):
    # Arrange
    session, session_factory, _ = mocked_session_factory
    get_coins = MagicMock(
        return_value=[Coin(coin_id=1, name="Test Coin", alloy_id=2)]
    )
    monkeypatch.setattr(coin_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        coin_service.coin_repository,
        "get_coins",
        get_coins,
    )

    # Act
    result = coin_service.list_coins("test", "USA", 2)

    # Assert
    assert result[0].name == "Test Coin"
    get_coins.assert_called_once_with(session, "test", "USA", 2)


def test_create_coin_rejects_missing_alloy(monkeypatch, mocked_session_factory):
    # Arrange
    _, session_factory, _ = mocked_session_factory
    monkeypatch.setattr(coin_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        coin_service.alloy_repository,
        "get_alloy_by_id",
        MagicMock(return_value=None),
    )

    # Act
    with pytest.raises(BusinessValidationError) as error:
        coin_service.create_coin(CreateCoinDTO("Test Coin", 999))

    # Assert
    assert error.value.errors == [
        "The specified alloy does not exist."
    ]


def test_change_coin_updates_with_mocked_session(monkeypatch, mocked_session_factory):
    # Arrange
    session, session_factory, _ = mocked_session_factory
    coin = Coin(coin_id=1, name="Test Coin", alloy_id=2)
    update_coin = MagicMock(return_value=coin)
    monkeypatch.setattr(coin_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        coin_service.coin_repository,
        "get_coin_by_id",
        MagicMock(return_value=coin),
    )
    monkeypatch.setattr(
        coin_service.coin_repository,
        "update_coin",
        update_coin,
    )

    # Act
    result = coin_service.change_coin(
        1,
        UpdateCoinDTO(name="Updated Coin"),
    )

    # Assert
    assert result.coin_id == 1
    update_coin.assert_called_once_with(
        session,
        1,
        {"name": "Updated Coin"},
    )
