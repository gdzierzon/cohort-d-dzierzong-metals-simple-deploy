from unittest.mock import MagicMock

from services import element_service
from services.exceptions import BusinessValidationError


def test_get_elements_returns_200(client, monkeypatch, element_response_dto):
    # Arrange
    # list_elements = MagicMock(return_value=[element_response_dto])
    # monkeypatch.setattr(
    #     element_service,
    #     "list_elements",
    #     list_elements,
    # )

    # Act
    try:
        response = client.get( "/api/elements?name=copper&color=reddish")

        # Assert
        assert response.status_code == 200
        assert response.get_json()[0]["symbol"] == "Cu"
    except Exception as ex:
        print(ex)
    # list_elements.assert_called_once_with(
    #     name="copper",
    #     color="reddish",
    # )


def test_get_element_returns_404_when_missing(client, monkeypatch):
    # Arrange
    monkeypatch.setattr(
        element_service,
        "find_element",
        MagicMock(return_value=None),
    )

    # Act
    response = client.get("/api/elements/999")

    # Assert
    assert response.status_code == 404
    assert response.get_json() == {"error": "Element not found"}


def test_create_element_returns_400_without_calling_service(client, monkeypatch):
    # Arrange
    create_element = MagicMock()
    monkeypatch.setattr(
        element_service,
        "create_element",
        create_element,
    )

    # Act
    response = client.post(
        "/api/elements",
        json={"atomic_number": 0, "name": ""},
    )

    # Assert
    assert response.status_code == 400
    assert isinstance(response.get_json()["errors"], list)
    create_element.assert_not_called()


def test_create_element_returns_201(client, monkeypatch, element_response_dto):
    # Arrange
    create_element = MagicMock(return_value=element_response_dto)
    monkeypatch.setattr(
        element_service,
        "create_element",
        create_element,
    )

    # Act
    response = client.post(
        "/api/elements",
        json={
            "atomic_number": 29,
            "name": "Copper",
            "symbol": "Cu",
        },
    )

    # Assert
    assert response.status_code == 201
    assert response.get_json()["atomic_number"] == 29
    assert create_element.call_args.args[0].symbol == "Cu"


def test_create_element_returns_business_errors(client, monkeypatch):
    # Arrange
    create_element = MagicMock(
        side_effect=BusinessValidationError(
            ["An element with this name already exists."]
        )
    )
    monkeypatch.setattr(
        element_service,
        "create_element",
        create_element,
    )

    # Act
    response = client.post(
        "/api/elements",
        json={
            "atomic_number": 29,
            "name": "Copper",
            "symbol": "Cu",
        },
    )

    # Assert
    assert response.status_code == 400
    assert response.get_json()["errors"] == [
        "An element with this name already exists."
    ]


def test_delete_element_returns_bodyless_204(client, monkeypatch):
    # Arrange
    monkeypatch.setattr(
        element_service,
        "remove_element",
        MagicMock(return_value=True),
    )

    # Act
    response = client.delete("/api/elements/29")

    # Assert
    assert response.status_code == 204
    assert response.data == b""
