from unittest.mock import MagicMock

from services import mint_product_service


def test_get_mint_products_returns_200(client, monkeypatch, mint_product_response_dto):
    # Arrange
    list_products = MagicMock(return_value=[mint_product_response_dto])
    monkeypatch.setattr(mint_product_service, "list_mint_products", list_products)

    # Act
    response = client.get("/api/mint-products?type=BAR&type=ROUND&metal=SILVER&name=bar")

    # Assert
    assert response.status_code == 200
    assert response.get_json()[0]["name"] == "Test Coin"
    list_products.assert_called_once_with(
        product_types=["BAR", "ROUND"],
        name="bar",
        issuer=None,
        metals=["SILVER"],
        families=None,
        alloy_id=None,
    )


def test_coins_endpoint_still_works(client, monkeypatch, mint_product_response_dto):
    # Arrange
    list_coins = MagicMock(return_value=[mint_product_response_dto])
    monkeypatch.setattr(mint_product_service, "list_coins", list_coins)

    # Act
    response = client.get("/api/coins?metal=GOLD")

    # Assert
    assert response.status_code == 200
    assert response.get_json()[0]["is_coin"] is True
    list_coins.assert_called_once_with(name=None, issuer=None, metals=["GOLD"], families=None, alloy_id=None)


def test_fetching_a_bar_through_the_coins_endpoint_is_404(client, monkeypatch, bar_response_dto):
    # Arrange - a bar is a mint product, but it is not a coin.
    monkeypatch.setattr(
        mint_product_service, "find_mint_product", MagicMock(return_value=bar_response_dto)
    )

    # Act
    response = client.get("/api/coins/2")

    # Assert
    assert response.status_code == 404
    assert response.get_json() == {"error": "Coin not found"}


def test_fetching_that_same_bar_as_a_mint_product_is_200(client, monkeypatch, bar_response_dto):
    # Arrange
    monkeypatch.setattr(
        mint_product_service, "find_mint_product", MagicMock(return_value=bar_response_dto)
    )

    # Act
    response = client.get("/api/mint-products/2")

    # Assert
    assert response.status_code == 200
    assert response.get_json()["is_coin"] is False


def test_create_returns_validation_errors(client, monkeypatch):
    # Arrange
    create = MagicMock()
    monkeypatch.setattr(mint_product_service, "create_mint_product", create)

    # Act
    response = client.post("/api/mint-products", json={"name": "Nameless"})

    # Assert
    assert response.status_code == 400
    errors = response.get_json()["errors"]
    assert "product_type is required." in errors
    assert "alloy_id is required." in errors
    create.assert_not_called()


def test_create_rejects_a_bar_carrying_a_face_value(client, monkeypatch):
    # Arrange - the API mirror of the subtype rule the database enforces.
    create = MagicMock()
    monkeypatch.setattr(mint_product_service, "create_mint_product", create)

    # Act
    response = client.post(
        "/api/mint-products",
        json={"name": "Odd Bar", "product_type": "BAR", "alloy_id": 1, "face_value": 5},
    )

    # Assert
    assert response.status_code == 400
    assert "only a COIN is legal tender" in response.get_json()["errors"][0]
    create.assert_not_called()


def test_create_requires_a_currency_code_for_a_coin(client, monkeypatch):
    # Arrange
    monkeypatch.setattr(mint_product_service, "create_mint_product", MagicMock())

    # Act
    response = client.post(
        "/api/mint-products",
        json={"name": "New Coin", "product_type": "COIN", "alloy_id": 1},
    )

    # Assert
    assert response.status_code == 400
    assert response.get_json()["errors"] == [
        "face_value_currency_code is required when product_type is COIN."
    ]


def test_create_accepts_a_bc_year(client, monkeypatch, mint_product_response_dto):
    # Arrange - the old constraint stopped at 500 AD, which ruled out ancient coins.
    monkeypatch.setattr(
        mint_product_service,
        "create_mint_product",
        MagicMock(return_value=mint_product_response_dto),
    )

    # Act
    response = client.post(
        "/api/mint-products",
        json={
            "name": "Roman Denarius",
            "product_type": "COIN",
            "alloy_id": 1,
            "year_introduced": -211,
            "face_value_currency_code": "XXX",
        },
    )

    # Assert
    assert response.status_code == 201


def test_create_rejects_fine_metal_heavier_than_gross(client, monkeypatch):
    # Arrange
    monkeypatch.setattr(mint_product_service, "create_mint_product", MagicMock())

    # Act
    response = client.post(
        "/api/mint-products",
        json={
            "name": "Impossible Bar",
            "product_type": "BAR",
            "alloy_id": 1,
            "gross_weight_g": 10,
            "fine_metal_weight_g": 20,
        },
    )

    # Assert
    assert response.status_code == 400
    assert response.get_json()["errors"] == [
        "fine_metal_weight_g must not exceed gross_weight_g."
    ]


def test_update_returns_404_when_missing(client, monkeypatch):
    # Arrange
    monkeypatch.setattr(
        mint_product_service, "change_mint_product", MagicMock(return_value=None)
    )

    # Act
    response = client.put("/api/mint-products/999", json={"mint": "Nowhere"})

    # Assert
    assert response.status_code == 404


def test_delete_returns_204(client, monkeypatch):
    # Arrange
    monkeypatch.setattr(
        mint_product_service, "remove_mint_product", MagicMock(return_value=True)
    )

    # Act
    response = client.delete("/api/mint-products/1")

    # Assert
    assert response.status_code == 204
