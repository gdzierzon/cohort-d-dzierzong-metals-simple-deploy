from __future__ import annotations

from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Integer,
    Numeric,
    SmallInteger,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.base import Base

# import only for Pylance - ommitted for deployed code
if TYPE_CHECKING:
    from models.alloy import Alloy
    from models.coin import Coin
    from models.mint_product_component import MintProductComponent


class MintProduct(Base):
    """Anything struck or pressed from metal: coins, rounds, bars, notes."""

    __tablename__ = "mint_products"
    __table_args__ = (
        CheckConstraint(
            "product_type IN ('COIN', 'ROUND', 'BAR', 'INGOT', 'MEDAL', 'TOKEN', 'NOTE')",
            name="chk_mint_products_type",
        ),
        CheckConstraint(
            "year_introduced IS NULL OR year_introduced BETWEEN -3000 AND 3000",
            name="chk_mint_products_year",
        ),
        CheckConstraint(
            "fine_metal_weight_g IS NULL"
            " OR gross_weight_g IS NULL"
            " OR fine_metal_weight_g <= gross_weight_g",
            name="chk_mint_products_weights",
        ),
        # Redundant against the primary key, but the coins subtype points a
        # composite foreign key at it so the discriminator cannot disagree.
        UniqueConstraint("mint_product_id", "product_type", name="uq_mint_products_type"),
    )

    mint_product_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False, unique=True)
    product_type: Mapped[str] = mapped_column(String(20), nullable=False)
    # A sovereign state for coins, a private mint for rounds and bars.
    issuer: Mapped[str | None] = mapped_column(String(80))
    mint: Mapped[str | None] = mapped_column(String(120))
    year_introduced: Mapped[int | None] = mapped_column(SmallInteger)
    gross_weight_g: Mapped[Decimal | None] = mapped_column(Numeric(10, 4))
    # Recorded rather than derived: for a goldback most of the gross weight is
    # polymer, so gross x purity would be wrong.
    fine_metal_weight_g: Mapped[Decimal | None] = mapped_column(Numeric(10, 4))
    alloy_id: Mapped[int] = mapped_column(
        ForeignKey(
            "alloys.alloy_id",
            name="fk_mint_products_alloy",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )

    alloy: Mapped[Alloy] = relationship(back_populates="mint_products")

    # uselist=False is the 1:1 half of the supertype/subtype pair. None for
    # anything that is not legal tender.
    coin: Mapped[Coin | None] = relationship(
        back_populates="mint_product",
        uselist=False,
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

    component_links: Mapped[list[MintProductComponent]] = relationship(
        back_populates="mint_product",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
