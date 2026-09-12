from __future__ import annotations

from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    Numeric,
    SmallInteger,
    String,
    Text,
    false,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.base import Base

# import only for Pylance - ommitted for deployed code
if TYPE_CHECKING:
    from models.alloy_element import AlloyElement


class Element(Base):
    __tablename__ = "elements"

    atomic_number: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    name: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    symbol: Mapped[str] = mapped_column(String(3), nullable=False, unique=True)
    melting_point_f: Mapped[Decimal | None] = mapped_column(Numeric(8, 2))
    boiling_point_f: Mapped[Decimal | None] = mapped_column(Numeric(8, 2))
    color: Mapped[str | None] = mapped_column(String(50))
    density: Mapped[Decimal | None] = mapped_column(Numeric(10, 6))
    category: Mapped[str | None] = mapped_column(String(40))
    state_at_room_temp: Mapped[str | None] = mapped_column(String(20))
    
    is_toxic: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=false(),
    )
    
    is_magnetic: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=false(),
    )
    
    common_uses: Mapped[str | None] = mapped_column(Text)

    # relationship
    alloy_links: Mapped[list[AlloyElement]] = relationship(
        back_populates="element",
        passive_deletes=True,
    )
