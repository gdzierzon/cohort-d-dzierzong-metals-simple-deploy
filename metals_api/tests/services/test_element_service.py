from unittest.mock import MagicMock

import pytest

from dtos import CreateElementDTO
from models import Element
# after this import, element_service has a SessionFactory object
from services import element_service
from services.exceptions import BusinessValidationError


def make_element():
    return Element(
        atomic_number=29,
        name="Copper",
        symbol="Cu",
        is_toxic=False,
        is_magnetic=False,
    )


def test_list_elements_uses_mocked_database_session(monkeypatch, mocked_session_factory):
    # Arrange
    session, session_factory, context_manager = mocked_session_factory
    
    # create a mock function that will return a well knon fake query result
    get_elements = MagicMock(return_value=[make_element(), make_element()])
    
    # configure the mock repository
    # replace the currenly imported SessionFactory with the mock version
    monkeypatch.setattr(element_service, "SessionFactory", session_factory)
    
    # replace the get_elements function of the element_repository 
    # with the mocked function
    monkeypatch.setattr(
        element_service.element_repository,
        "get_elements",
        get_elements,
    )

    # Act
    # Call the actual service list_elements function - it will use the mocked objects
    result = element_service.list_elements("copper", "reddish")

    # Assert
    # assert the results as normal
    # we are just validating the services logic and effect on the data
    assert result[0].name == "Copper"
    # the mock lets us determine how many times the function was called
    # and with what parameters
    get_elements.assert_called_once_with(
        session,
        "copper",
        "reddish",
    )


def test_create_element_uses_mocked_session_and_repository(monkeypatch, mocked_session_factory):
    # Arrange
    session, session_factory, _ = mocked_session_factory
    add_element = MagicMock(side_effect=lambda session, element: element)
    monkeypatch.setattr(element_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        element_service.element_repository,
        "get_element_by_id",
        MagicMock(return_value=None),
    )
    monkeypatch.setattr(
        element_service.element_repository,
        "get_element_by_name",
        MagicMock(return_value=None),
    )
    monkeypatch.setattr(
        element_service.element_repository,
        "get_element_by_symbol",
        MagicMock(return_value=None),
    )
    monkeypatch.setattr(
        element_service.element_repository,
        "add_element",
        add_element,
    )

    # Act
    result = element_service.create_element(
        CreateElementDTO(29, "Copper", "Cu")
    )

    # Assert
    assert result.atomic_number == 29
    saved_element = add_element.call_args.args[1]
    assert saved_element.name == "Copper"
    assert add_element.call_args.args[0] is session


def test_create_element_accumulates_uniqueness_errors(monkeypatch, mocked_session_factory):
    # Arrange
    _, session_factory, _ = mocked_session_factory
    existing = make_element()
    monkeypatch.setattr(element_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        element_service.element_repository,
        "get_element_by_id",
        MagicMock(return_value=existing),
    )
    monkeypatch.setattr(
        element_service.element_repository,
        "get_element_by_name",
        MagicMock(return_value=existing),
    )
    monkeypatch.setattr(
        element_service.element_repository,
        "get_element_by_symbol",
        MagicMock(return_value=existing),
    )

    # Act
    with pytest.raises(BusinessValidationError) as error:
        element_service.create_element(
            CreateElementDTO(29, "Copper", "Cu")
        )

    # Assert
    assert len(error.value.errors) == 3
