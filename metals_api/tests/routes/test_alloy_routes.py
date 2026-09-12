from unittest.mock import MagicMock

from services import alloy_service


def test_get_alloys_returns_200(client, monkeypatch, alloy_response_dto):
    # Arrange
    list_alloys = MagicMock(return_value=[alloy_response_dto])
    monkeypatch.setattr(alloy_service, "list_alloys", list_alloys)

    # Act
    response = client.get("/api/alloys?name=bronze")

    # Assert
    assert response.status_code == 200
    assert response.get_json()[0]["name"] == "Bronze"
    assert response.get_json()[0]["uses"] == ["BEARING", "DECORATIVE"]
    list_alloys.assert_called_once_with(
        name="bronze",
        color=None,
        families=None,
        uses=None,
    )


def test_get_alloys_passes_repeated_family_and_use_filters(client, monkeypatch, alloy_response_dto):
    # Arrange
    list_alloys = MagicMock(return_value=[alloy_response_dto])
    monkeypatch.setattr(alloy_service, "list_alloys", list_alloys)

    # Act
    response = client.get("/api/alloys?family=FERROUS&family=NICKEL&use=AEROSPACE")

    # Assert
    assert response.status_code == 200
    list_alloys.assert_called_once_with(
        name=None,
        color=None,
        families=["FERROUS", "NICKEL"],
        uses=["AEROSPACE"],
    )


def test_create_alloy_returns_validation_errors(client, monkeypatch):
    # Arrange
    create_alloy = MagicMock()
    monkeypatch.setattr(alloy_service, "create_alloy", create_alloy)

    # Act
    response = client.post("/api/alloys", json={"name": ""})

    # Assert
    assert response.status_code == 400
    assert response.get_json()["errors"] == [
        "name must be a non-empty string.",
        "alloy_family is required.",
    ]
    create_alloy.assert_not_called()


def test_create_alloy_rejects_an_unknown_family(client, monkeypatch):
    # Arrange
    create_alloy = MagicMock()
    monkeypatch.setattr(alloy_service, "create_alloy", create_alloy)

    # Act
    response = client.post(
        "/api/alloys",
        json={"name": "Unobtainium Bronze", "alloy_family": "UNOBTAINIUM"},
    )

    # Assert
    assert response.status_code == 400
    assert "alloy_family must be one of" in response.get_json()["errors"][0]
    create_alloy.assert_not_called()


def test_create_alloy_rejects_an_unknown_use_code(client, monkeypatch):
    # Arrange
    create_alloy = MagicMock()
    monkeypatch.setattr(alloy_service, "create_alloy", create_alloy)

    # Act
    response = client.post(
        "/api/alloys",
        json={"name": "Bronze", "alloy_family": "COPPER", "uses": ["TIME_TRAVEL"]},
    )

    # Assert
    assert response.status_code == 400
    assert response.get_json()["errors"] == [
        "TIME_TRAVEL is not a recognized use code."
    ]
    create_alloy.assert_not_called()


def test_create_alloy_returns_201(client, monkeypatch, alloy_response_dto):
    # Arrange
    monkeypatch.setattr(
        alloy_service,
        "create_alloy",
        MagicMock(return_value=alloy_response_dto),
    )

    # Act
    response = client.post(
        "/api/alloys",
        json={"name": "Bronze", "alloy_family": "COPPER"},
    )

    # Assert
    assert response.status_code == 201
    assert response.get_json()["alloy_id"] == 2


def test_update_alloy_returns_404_when_missing(client, monkeypatch):
    # Arrange
    monkeypatch.setattr(
        alloy_service,
        "change_alloy",
        MagicMock(return_value=None),
    )

    # Act
    response = client.put(
        "/api/alloys/999",
        json={"color": "gray"},
    )

    # Assert
    assert response.status_code == 404
