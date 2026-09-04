from unittest.mock import MagicMock

import pytest

from dtos import CreateAlloyDTO, UpdateAlloyDTO
from models import Alloy
from services import alloy_service
from services.exceptions import BusinessValidationError


def test_list_alloys_uses_mocked_database_session(monkeypatch, mocked_session_factory):
    # Arrange
    session, session_factory, _ = mocked_session_factory
    get_alloys = MagicMock(
        return_value=[Alloy(alloy_id=2, name="Bronze")]
    )
    monkeypatch.setattr(alloy_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        alloy_service.alloy_repository,
        "get_alloys",
        get_alloys,
    )

    # Act
    result = alloy_service.list_alloys("bronze", "brown")

    # Assert
    assert result[0].name == "Bronze"
    get_alloys.assert_called_once_with(session, "bronze", "brown")


def test_create_alloy_rejects_duplicate_name(monkeypatch, mocked_session_factory):
    # Arrange
    _, session_factory, _ = mocked_session_factory
    monkeypatch.setattr(alloy_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        alloy_service.alloy_repository,
        "get_alloy_by_name",
        MagicMock(return_value=Alloy(alloy_id=2, name="Bronze")),
    )

    # Act
    with pytest.raises(BusinessValidationError) as error:
        alloy_service.create_alloy(CreateAlloyDTO("Bronze"))

    # Assert
    assert error.value.errors == [
        "An alloy with this name already exists."
    ]


def test_change_alloy_returns_none_when_missing(monkeypatch, mocked_session_factory):
    # Arrange
    _, session_factory, _ = mocked_session_factory
    monkeypatch.setattr(alloy_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        alloy_service.alloy_repository,
        "get_alloy_by_id",
        MagicMock(return_value=None),
    )

    # Act
    result = alloy_service.change_alloy(
        999,
        UpdateAlloyDTO(color="gray"),
    )

    # Assert
    assert result is None
