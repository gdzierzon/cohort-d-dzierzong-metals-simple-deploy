from unittest.mock import MagicMock

from services import alloy_element_service


def test_get_alloy_elements_validates_query_parameters(client, monkeypatch):
    # Arrange
    list_components = MagicMock()
    # mock the element service - service will not actually be called
    monkeypatch.setattr(
        alloy_element_service,
        "list_alloy_elements",
        list_components,
    )

    # Act
    response = client.get(
        "/api/alloy-elements?alloy_id=nope&atomic_number=-1"
    )

    # Assert
    assert response.status_code == 400
    assert len(response.get_json()["errors"]) == 2
    list_components.assert_not_called()


def test_get_alloy_elements_returns_200(client, monkeypatch, alloy_element_response_dto):
    # Arrange
    list_components = MagicMock(
        return_value=[alloy_element_response_dto]
    )
    monkeypatch.setattr(
        alloy_element_service,
        "list_alloy_elements",
        list_components,
    )

    # Act
    response = client.get(
        "/api/alloy-elements?alloy_id=2&atomic_number=29"
    )

    # Assert
    assert response.status_code == 200
    assert response.get_json()[0]["percent_of_alloy"] == "88"
    list_components.assert_called_once_with(
        alloy_id=2,
        atomic_number=29,
    )


def test_create_alloy_element_returns_201(client, monkeypatch, alloy_element_response_dto):
    # Arrange
    create_component = MagicMock(
        return_value=alloy_element_response_dto
    )
    monkeypatch.setattr(
        alloy_element_service,
        "create_alloy_element",
        create_component,
    )

    # Act
    response = client.post(
        "/api/alloy-elements",
        json={
            "alloy_id": 2,
            "atomic_number": 29,
            "percent_of_alloy": 88,
        },
    )

    # Assert
    assert response.status_code == 201
    assert create_component.call_args.args[
        0
    ].percent_of_alloy == 88


def test_update_alloy_element_rejects_invalid_percentage(client, monkeypatch):
    # Arrange
    change_component = MagicMock()
    monkeypatch.setattr(
        alloy_element_service,
        "change_alloy_element",
        change_component,
    )

    # Act
    response = client.put(
        "/api/alloy-elements/2/29",
        json={"percent_of_alloy": 101},
    )

    # Assert
    assert response.status_code == 400
    change_component.assert_not_called()
