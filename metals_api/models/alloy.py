from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.base import Base

# import only for Pylance - ommitted for deployed code
if TYPE_CHECKING:
    from models.alloy_element import AlloyElement
    from models.alloy_use import AlloyUse
    from models.mint_product import MintProduct
    from models.mint_product_component import MintProductComponent


class Alloy(Base):
    __tablename__ = "alloys"

    alloy_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        unique=True,
    )
    color: Mapped[str | None] = mapped_column(String(50))
    # Which of five buckets that free-text color falls into, so the catalog can be
    # grouped by how an alloy looks. Seeded by mapping the color string, then
    # editable - unlike primary_metal, the grouping is a judgement call.
    color_family: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
    )
    # The base metal by mass fraction. Not nullable: the database enforces both
    # presence and the allowed values, so a bad family fails at the insert.
    alloy_family: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
    )
    # The single metal this alloy is mostly made of - finer than alloy_family,
    # which collapses gold, silver, platinum and palladium into PRECIOUS. The
    # seed derives it from alloy_elements, so it always agrees with the
    # composition. Coins read their metal through this rather than storing it.
    primary_metal: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )
    description: Mapped[str | None] = mapped_column(Text)

    # linked relationships
    mint_products: Mapped[list[MintProduct]] = relationship(
        back_populates="alloy",
        passive_deletes=True,
    )

    mint_product_component_links: Mapped[list[MintProductComponent]] = relationship(
        back_populates="alloy",
        passive_deletes=True,
    )
    
    element_links: Mapped[list[AlloyElement]] = relationship(
        back_populates="alloy",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

    use_links: Mapped[list[AlloyUse]] = relationship(
        back_populates="alloy",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
