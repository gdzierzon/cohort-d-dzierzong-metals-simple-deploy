from unittest.mock import MagicMock

import pytest

from dtos import CreateMintProductDTO, UpdateMintProductDTO
from models import Alloy, Coin, MintProduct
from services import mint_product_service
from services.exceptions import BusinessValidationError


def _product(product_type="COIN", with_coin=True):
    product = MintProduct(
        mint_product_id=1,
        name="Test Coin",
        product_type=product_type,
        alloy_id=2,
    )
    product.alloy = Alloy(
        alloy_id=2,
        name="Coin Silver",
        alloy_family="PRECIOUS",
        primary_metal="SILVER",
    )
    if with_coin:
        product.coin = Coin(face_value_currency_code="USD", is_legal_tender=True)
    return product


def test_list_mint_products_passes_every_filter(monkeypatch, mocked_session_factory):
    # Arrange
    session, session_factory, _ = mocked_session_factory
    get_products = MagicMock(return_value=[_product()])
    monkeypatch.setattr(mint_product_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        mint_product_service.mint_product_repository, "get_mint_products", get_products
    )

    # Act
    result = mint_product_service.list_mint_products(
        name="test", product_types=["BAR"], metals=["SILVER"], families=["PRECIOUS"], issuer="USA"
    )

    # Assert
    assert result[0].name == "Test Coin"
    get_products.assert_called_once_with(
        session, "test", ["BAR"], ["SILVER"], ["PRECIOUS"], "USA", None
    )


def test_list_coins_restricts_to_the_coin_type(monkeypatch, mocked_session_factory):
    # Arrange
    session, session_factory, _ = mocked_session_factory
    get_products = MagicMock(return_value=[_product()])
    monkeypatch.setattr(mint_product_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        mint_product_service.mint_product_repository, "get_mint_products", get_products
    )

    # Act
    mint_product_service.list_coins(metals=["GOLD"])

    # Assert
    assert get_products.call_args.args[2] == ["COIN"]


def test_response_reports_is_coin_from_the_subtype_row(monkeypatch, mocked_session_factory):
    # Arrange - a bar has no coins row, so nothing about it is legal tender.
    session, session_factory, _ = mocked_session_factory
    monkeypatch.setattr(mint_product_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        mint_product_service.mint_product_repository,
        "get_mint_products",
        MagicMock(return_value=[_product(product_type="BAR", with_coin=False)]),
    )

    # Act
    result = mint_product_service.list_mint_products()

    # Assert
    assert result[0].is_coin is False
    assert result[0].face_value_currency_code is None
    assert result[0].is_legal_tender is None


def test_create_rejects_a_duplicate_name(monkeypatch, mocked_session_factory):
    # Arrange
    _, session_factory, _ = mocked_session_factory
    monkeypatch.setattr(mint_product_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        mint_product_service.mint_product_repository,
        "get_mint_product_by_name",
        MagicMock(return_value=_product()),
    )

    # Act
    with pytest.raises(BusinessValidationError) as error:
        mint_product_service.create_mint_product(
            CreateMintProductDTO("Test Coin", "COIN", 2, face_value_currency_code="USD")
        )

    # Assert
    assert error.value.errors == ["A mint product with this name already exists."]


def test_change_returns_none_when_missing(monkeypatch, mocked_session_factory):
    # Arrange
    _, session_factory, _ = mocked_session_factory
    monkeypatch.setattr(mint_product_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        mint_product_service.mint_product_repository,
        "get_mint_product_by_id",
        MagicMock(return_value=None),
    )

    # Act
    result = mint_product_service.change_mint_product(999, UpdateMintProductDTO(mint="Nowhere"))

    # Assert
    assert result is None


def test_change_refuses_legal_tender_fields_on_a_bar(monkeypatch, mocked_session_factory):
    # Arrange - the stored type is what counts when the request does not change it.
    _, session_factory, _ = mocked_session_factory
    monkeypatch.setattr(mint_product_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        mint_product_service.mint_product_repository,
        "get_mint_product_by_id",
        MagicMock(return_value=_product(product_type="BAR", with_coin=False)),
    )

    # Act
    with pytest.raises(BusinessValidationError) as error:
        mint_product_service.change_mint_product(
            1, UpdateMintProductDTO(face_value_currency_code="USD")
        )

    # Assert
    assert "only a COIN is money" in error.value.errors[0]


def test_turning_a_coin_into_a_bar_drops_the_subtype_row_first(monkeypatch, mocked_session_factory):
    """The coins row carries product_type too, kept in step by ON UPDATE CASCADE.

    Updating the product first would cascade 'BAR' into it and trip its CHECK, so
    the subtype row has to be removed before the type changes.
    """
    # Arrange
    _, session_factory, _ = mocked_session_factory
    coin_product = _product()
    calls = []
    monkeypatch.setattr(mint_product_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        mint_product_service.mint_product_repository,
        "get_mint_product_by_id",
        MagicMock(return_value=coin_product),
    )
    monkeypatch.setattr(
        mint_product_service.mint_product_repository,
        "set_coin_facts",
        MagicMock(side_effect=lambda *a, **k: calls.append("set_coin_facts")),
    )
    monkeypatch.setattr(
        mint_product_service.mint_product_repository,
        "update_mint_product",
        MagicMock(side_effect=lambda *a, **k: calls.append("update") or coin_product),
    )

    # Act
    mint_product_service.change_mint_product(1, UpdateMintProductDTO(product_type="BAR"))

    # Assert
    assert calls == ["set_coin_facts", "update"]


def test_create_writes_the_product_and_its_coin_in_one_transaction(
    monkeypatch, mocked_session_factory
):
    """A refused coins row must not leave the product behind.

    Committing the product first and the coins row second produced a real orphan:
    a COIN with no coins row, reporting is_coin false, which the supertype/subtype
    design exists to make impossible. Both writes now flush and the service commits
    once, so the database rejecting the coins row takes the product with it.
    """
    # Arrange
    session, session_factory, _ = mocked_session_factory
    new_product = _product()
    monkeypatch.setattr(mint_product_service, "SessionFactory", session_factory)
    monkeypatch.setattr(
        mint_product_service.mint_product_repository,
        "get_mint_product_by_name",
        MagicMock(return_value=None),
    )
    monkeypatch.setattr(
        mint_product_service.mint_product_repository,
        "get_mint_product_by_id",
        MagicMock(return_value=new_product),
    )
    add = MagicMock(return_value=new_product)
    set_coin_facts = MagicMock()
    monkeypatch.setattr(mint_product_service.mint_product_repository, "add_mint_product", add)
    monkeypatch.setattr(
        mint_product_service.mint_product_repository, "set_coin_facts", set_coin_facts
    )

    # Act
    mint_product_service.create_mint_product(
        CreateMintProductDTO(
            name="Test Coin",
            product_type="COIN",
            alloy_id=2,
            face_value_currency_code="USD",
        )
    )

    # Assert - neither write commits on its own; the service commits once for both.
    assert add.call_args.kwargs["commit"] is False
    assert set_coin_facts.call_args.kwargs["commit"] is False
    session.commit.assert_called_once_with()
