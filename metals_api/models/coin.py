from __future__ import annotations

from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    CHAR,
    Boolean,
    CheckConstraint,
    ForeignKeyConstraint,
    Integer,
    Numeric,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.base import Base

# import only for Pylance - ommitted for deployed code
if TYPE_CHECKING:
    from models.mint_product import MintProduct


class Coin(Base):
    """The legal-tender subtype of MintProduct.

    There is no is_coin flag anywhere in the schema: the existence of a row in
    this table is what says a mint product is money.
    """

    __tablename__ = "coins"
    __table_args__ = (
        CheckConstraint("product_type = 'COIN'", name="chk_coins_product_type"),
        # Composite, pointing at uq_mint_products_type. This is what stops a
        # coins row attaching to a product whose type is BAR.
        ForeignKeyConstraint(
            ["mint_product_id", "product_type"],
            ["mint_products.mint_product_id", "mint_products.product_type"],
            name="fk_coins_mint_product",
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
    )

    # Primary key and foreign key at once - that pairing is what makes it 1:1.
    mint_product_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_type: Mapped[str] = mapped_column(String(20), nullable=False, default="COIN")
    # Nullable for one real reason: a Krugerrand is legal tender with no
    # denomination struck on it. That is a fact, not missing data.
    face_value: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    face_value_currency_code: Mapped[str] = mapped_column(CHAR(3), nullable=False)
    is_legal_tender: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    mint_product: Mapped[MintProduct] = relationship(back_populates="coin")
