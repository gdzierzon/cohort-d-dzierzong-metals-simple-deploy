from __future__ import annotations

from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.base import Base

# import only for Pylance - ommitted for deployed code
if TYPE_CHECKING:
    from models.alloy import Alloy
    from models.mint_product import MintProduct


class MintProductComponent(Base):
    """One layer of a multi-alloy piece: a clad quarter, a plated cent, a 2 euro.

    Solid pieces have no rows here at all - their alloy_id says everything.
    """

    __tablename__ = "mint_product_components"
    __table_args__ = (
        CheckConstraint(
            "component_role IN ('CORE', 'CLADDING', 'PLATING', 'RING', 'CENTER', 'LEAF')",
            name="chk_mint_product_component_role",
        ),
        CheckConstraint(
            "percent_of_weight IS NULL"
            " OR (percent_of_weight > 0 AND percent_of_weight <= 100)",
            name="chk_mint_product_component_percent",
        ),
    )

    mint_product_id: Mapped[int] = mapped_column(
        ForeignKey(
            "mint_products.mint_product_id",
            name="fk_mint_product_components_product",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )
    alloy_id: Mapped[int] = mapped_column(
        ForeignKey(
            "alloys.alloy_id",
            name="fk_mint_product_components_alloy",
            ondelete="RESTRICT",
        ),
        primary_key=True,
    )
    component_role: Mapped[str] = mapped_column(String(20), primary_key=True)
    # NULL where the split between layers cannot be stated accurately - an honest
    # gap beats an invented number.
    percent_of_weight: Mapped[Decimal | None] = mapped_column(Numeric(6, 3))

    mint_product: Mapped[MintProduct] = relationship(back_populates="component_links")
    alloy: Mapped[Alloy] = relationship(back_populates="mint_product_component_links")
