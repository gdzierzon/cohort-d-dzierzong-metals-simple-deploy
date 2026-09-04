from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.base import Base

# import only for Pylance - ommitted for deployed code
if TYPE_CHECKING:
    from models.alloy_element import AlloyElement
    from models.coin import Coin


class Alloy(Base):
    __tablename__ = "alloys"

    alloy_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        unique=True,
    )
    color: Mapped[str | None] = mapped_column(String(50))
    description: Mapped[str | None] = mapped_column(Text)

    # linked relationships
    coins: Mapped[list[Coin]] = relationship(
        back_populates="alloy",
        passive_deletes=True,
    )
    
    element_links: Mapped[list[AlloyElement]] = relationship(
        back_populates="alloy",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
