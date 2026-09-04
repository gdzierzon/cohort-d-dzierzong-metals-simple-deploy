from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from dtos import CreateAlloyElementDTO, UpdateAlloyElementDTO
from models import Alloy, Element
from services import alloy_element_service
from services.exceptions import BusinessValidationError


def test_list_alloy_elements_uses_mocked_database_session(monkeypatch, mocked_session_factory):
    # Arrange
    session, session_factory, _ = mocked_session_factory
    component = SimpleNamespace(
        alloy_id=2,
        atomic_number=29,
        percent_of_alloy=Decimal("88"),
    )
    get_components = MagicMock(return_value=[component])
    monkeypatch.setattr(
        alloy_element_service,
        "SessionFactory",
        session_factory,
    )
    monkeypatch.setattr(
        alloy_element_service.alloy_element_repository,
        "get_alloy_elements",
        get_components,
    )

    # Act
    result = alloy_element_service.list_alloy_elements(2, 29)

    # Assert
    assert result[0].percent_of_alloy == Decimal("88")
    get_components.assert_called_once_with(session, 2, 29)


def test_create_alloy_element_validates_relationships(monkeypatch, mocked_session_factory):
    # Arrange
    _, session_factory, _ = mocked_session_factory
    monkeypatch.setattr(
        alloy_element_service,
        "SessionFactory",
        session_factory,
    )
    monkeypatch.setattr(
        alloy_element_service.alloy_repository,
        "get_alloy_by_id",
        MagicMock(return_value=None),
    )
    monkeypatch.setattr(
        alloy_element_service.element_repository,
        "get_element_by_id",
        MagicMock(return_value=None),
    )
    monkeypatch.setattr(
        alloy_element_service.alloy_element_repository,
        "get_alloy_element_by_id",
        MagicMock(return_value=None),
    )
    monkeypatch.setattr(
        alloy_element_service.alloy_element_repository,
        "get_alloy_elements",
        MagicMock(return_value=[]),
    )

    # Act
    with pytest.raises(BusinessValidationError) as error:
        alloy_element_service.create_alloy_element(
            CreateAlloyElementDTO(
                alloy_id=2,
                atomic_number=29,
                percent_of_alloy=Decimal("88"),
            )
        )

    # Assert
    assert error.value.errors == [
        "The specified alloy does not exist.",
        "The specified element does not exist.",
    ]


def test_change_alloy_element_rejects_total_over_100(monkeypatch, mocked_session_factory):
    # Arrange
    _, session_factory, _ = mocked_session_factory
    current = SimpleNamespace(
        alloy_id=2,
        atomic_number=29,
        percent_of_alloy=Decimal("20"),
    )
    other = SimpleNamespace(
        alloy_id=2,
        atomic_number=13,
        percent_of_alloy=Decimal("60"),
    )
    monkeypatch.setattr(
        alloy_element_service,
        "SessionFactory",
        session_factory,
    )
    monkeypatch.setattr(
        alloy_element_service.alloy_element_repository,
        "get_alloy_element_by_id",
        MagicMock(return_value=current),
    )
    monkeypatch.setattr(
        alloy_element_service.alloy_element_repository,
        "get_alloy_elements",
        MagicMock(return_value=[current, other]),
    )

    # Act
    with pytest.raises(BusinessValidationError) as error:
        alloy_element_service.change_alloy_element(
            2,
            29,
            UpdateAlloyElementDTO(Decimal("50")),
        )

    # Assert
    assert error.value.errors == [
        "The alloy composition cannot exceed 100 percent."
    ]
