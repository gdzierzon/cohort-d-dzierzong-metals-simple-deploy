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
        return_value=[Alloy(alloy_id=2, name="Bronze", alloy_family="COPPER")]
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
    assert result[0].alloy_family == "COPPER"
    get_alloys.assert_called_once_with(session, "bronze", "brown", None, None)


def test_list_alloys_passes_family_and_use_filters(monkeypatch, mocked_session_factory):
    # Arrange
    session, session_factory, _ = mocked_session_factory
    get_alloys = MagicMock(
        return_value=[Alloy(alloy_id=5, name="304 Stainless Steel", alloy_family="FERROUS")]
    )
    monkeypatch.setattr(alloy_service, "SessionFactory", session_factory)
    monkeypatch.setattr(alloy_service.alloy_repository, "get_alloys", get_alloys)

    # Act
    result = alloy_service.list_alloys(families=["FERROUS"], uses=["MEDICAL"])

    # Assert
    assert result[0].alloy_family == "FERROUS"
    get_alloys.assert_called_once_with(session, None, None, ["FERROUS"], ["MEDICAL"])


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
        alloy_service.create_alloy(CreateAlloyDTO("Bronze", "COPPER"))

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
