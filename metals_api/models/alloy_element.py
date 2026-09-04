from __future__ import annotations

from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Numeric, SmallInteger
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.base import Base

# import only for Pylance - ommitted for deployed code
if TYPE_CHECKING:
    from models.alloy import Alloy
    from models.element import Element


class AlloyElement(Base):
    __tablename__ = "alloy_elements"

    alloy_id: Mapped[int] = mapped_column(
        ForeignKey(
            "alloys.alloy_id",
            name="fk_alloy_elements_alloy",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )
    atomic_number: Mapped[int] = mapped_column(
        SmallInteger,
        ForeignKey(
            "elements.atomic_number",
            name="fk_alloy_elements_element",
            ondelete="RESTRICT",
        ),
        primary_key=True,
    )
    percent_of_alloy: Mapped[Decimal] = mapped_column(
        Numeric(6, 3),
        nullable=False,
    )

    alloy: Mapped[Alloy] = relationship(back_populates="element_links")
    element: Mapped[Element] = relationship(back_populates="alloy_links")
