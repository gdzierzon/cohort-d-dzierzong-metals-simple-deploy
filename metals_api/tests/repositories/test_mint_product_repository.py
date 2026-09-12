from unittest.mock import MagicMock

from sqlalchemy.orm import Session

from models import Coin, MintProduct
from repositories import mint_product_repository


def _scalars_returning(*products):
    session = MagicMock(spec=Session)
    # The repository calls .unique() because joined eager loading can repeat rows.
    session.scalars.return_value.unique.return_value = list(products)
    return session


def test_get_mint_products_uses_session_scalars():
    # Arrange
    product = MintProduct(mint_product_id=1, name="Test Coin", product_type="COIN", alloy_id=2)
    session = _scalars_returning(product)

    # Act
    result = mint_product_repository.get_mint_products(
        session,
        name="test",
        product_types=["COIN"],
        metals=["SILVER"],
    )

    # Assert
    assert result == [product]
    session.scalars.assert_called_once()


def test_add_mint_product_commits_and_refreshes():
    # Arrange
    session = MagicMock(spec=Session)
    product = MintProduct(name="Test Bar", product_type="BAR", alloy_id=2)

    # Act
    result = mint_product_repository.add_mint_product(session, product)

    # Assert
    assert result is product
    session.add.assert_called_once_with(product)
    session.commit.assert_called_once_with()
    session.refresh.assert_called_once_with(product)


def test_update_mint_product_returns_none_when_missing():
    # Arrange
    session = MagicMock(spec=Session)
    session.get.return_value = None

    # Act
    result = mint_product_repository.update_mint_product(session, 999, {"name": "Missing"})

    # Assert
    assert result is None
    session.commit.assert_not_called()


def test_set_coin_facts_attaches_a_subtype_row():
    # Arrange
    session = MagicMock(spec=Session)
    product = MintProduct(mint_product_id=1, name="Test Coin", product_type="COIN", alloy_id=2)

    # Act
    mint_product_repository.set_coin_facts(
        session,
        product,
        {"face_value": 1, "face_value_currency_code": "USD", "is_legal_tender": True},
    )

    # Assert
    assert product.coin.face_value_currency_code == "USD"
    assert product.coin.product_type == "COIN"
    session.commit.assert_called_once_with()


def test_set_coin_facts_with_none_removes_the_subtype_row():
    # Arrange
    session = MagicMock(spec=Session)
    product = MintProduct(mint_product_id=1, name="Test Coin", product_type="COIN", alloy_id=2)
    product.coin = Coin(face_value_currency_code="USD")

    # Act
    mint_product_repository.set_coin_facts(session, product, None)

    # Assert
    assert product.coin is None
