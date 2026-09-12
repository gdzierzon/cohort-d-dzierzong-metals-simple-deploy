from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.base import Base

# import only for Pylance - ommitted for deployed code
if TYPE_CHECKING:
    from models.alloy_element import AlloyElement
    from models.alloy_use import AlloyUse
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
    # The base metal by mass fraction. Not nullable: the database enforces both
    # presence and the allowed values, so a bad family fails at the insert.
    alloy_family: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
    )
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

    use_links: Mapped[list[AlloyUse]] = relationship(
        back_populates="alloy",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
