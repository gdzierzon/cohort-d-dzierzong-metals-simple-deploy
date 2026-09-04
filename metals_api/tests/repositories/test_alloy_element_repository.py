from decimal import Decimal
from unittest.mock import MagicMock

from sqlalchemy.orm import Session

from models import AlloyElement
from repositories import alloy_element_repository


def test_get_alloy_elements_uses_session_scalars():
    # Arrange
    session = MagicMock(spec=Session)
    component = AlloyElement(
        alloy_id=2,
        atomic_number=29,
        percent_of_alloy=Decimal("88"),
    )
    session.scalars.return_value = [component]

    # Act
    result = alloy_element_repository.get_alloy_elements(
        session,
        alloy_id=2,
        atomic_number=29,
    )

    # Assert
    assert result == [component]
    session.scalars.assert_called_once()


def test_update_alloy_element_changes_percentage():
    # Arrange
    session = MagicMock(spec=Session)
    component = AlloyElement(
        alloy_id=2,
        atomic_number=29,
        percent_of_alloy=Decimal("88"),
    )
    session.get.return_value = component

    # Act
    result = alloy_element_repository.update_alloy_element(
        session,
        2,
        29,
        {"percent_of_alloy": Decimal("90")},
    )

    # Assert
    assert result.percent_of_alloy == Decimal("90")
    session.commit.assert_called_once_with()
    session.refresh.assert_called_once_with(component)


def test_delete_alloy_element_uses_composite_key():
    # Arrange
    session = MagicMock(spec=Session)
    component = AlloyElement(
        alloy_id=2,
        atomic_number=29,
        percent_of_alloy=Decimal("88"),
    )
    session.get.return_value = component

    # Act
    result = alloy_element_repository.delete_alloy_element(
        session,
        2,
        29,
    )

    # Assert
    assert result is True
    session.get.assert_called_once_with(AlloyElement, (2, 29))
    session.delete.assert_called_once_with(component)
