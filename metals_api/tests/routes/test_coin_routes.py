from unittest.mock import MagicMock

from services import coin_service
from services.exceptions import BusinessValidationError


def test_get_coins_validates_alloy_id_query(client, monkeypatch):
    # Arrange
    list_coins = MagicMock()
    monkeypatch.setattr(coin_service, "list_coins", list_coins)

    # Act
    response = client.get("/api/coins?alloy_id=invalid")

    # Assert
    assert response.status_code == 400
    assert response.get_json()["errors"] == [
        "alloy_id must be a positive integer."
    ]
    list_coins.assert_not_called()


def test_get_coins_returns_200(client, monkeypatch, coin_response_dto):
    # Arrange
    list_coins = MagicMock(return_value=[coin_response_dto])
    monkeypatch.setattr(coin_service, "list_coins", list_coins)

    # Act
    response = client.get(
        "/api/coins?name=test&country=USA&alloy_id=2"
    )

    # Assert
    assert response.status_code == 200
    assert response.get_json()[0]["coin_id"] == 1
    list_coins.assert_called_once_with(
        name="test",
        country="USA",
        alloy_id=2,
    )


def test_create_coin_returns_201(client, monkeypatch, coin_response_dto):
    # Arrange
    create_coin = MagicMock(return_value=coin_response_dto)
    monkeypatch.setattr(coin_service, "create_coin", create_coin)

    # Act
    response = client.post(
        "/api/coins",
        json={"name": "Test Coin", "alloy_id": 2},
    )

    # Assert
    assert response.status_code == 201
    assert response.get_json()["coin_id"] == 1


def test_create_coin_returns_business_validation_errors(client, monkeypatch):
    # Arrange
    monkeypatch.setattr(
        coin_service,
        "create_coin",
        MagicMock(
            side_effect=BusinessValidationError(
                ["The specified alloy does not exist."]
            )
        ),
    )

    # Act
    response = client.post(
        "/api/coins",
        json={"name": "Test Coin", "alloy_id": 999},
    )

    # Assert
    assert response.status_code == 400
    assert response.get_json()["errors"] == [
        "The specified alloy does not exist."
    ]
