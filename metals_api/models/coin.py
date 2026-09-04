from __future__ import annotations

from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    CHAR,
    CheckConstraint,
    ForeignKey,
    Integer,
    Numeric,
    SmallInteger,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.base import Base

# import only for Pylance - ommitted for deployed code
if TYPE_CHECKING:
    from models.alloy import Alloy


class Coin(Base):
    __tablename__ = "coins"
    __table_args__ = (
        CheckConstraint(
            "year_introduced IS NULL OR year_introduced BETWEEN 500 AND 3000",
            name="chk_coins_year_introduced",
        ),
    )

    coin_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    country: Mapped[str | None] = mapped_column(String(80))
    mint: Mapped[str | None] = mapped_column(String(120))
    year_introduced: Mapped[int | None] = mapped_column(SmallInteger)
    alloy_id: Mapped[int] = mapped_column(
        ForeignKey(
            "alloys.alloy_id",
            name="fk_coins_alloy",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )
    gross_weight_g: Mapped[Decimal | None] = mapped_column(Numeric(10, 4))
    face_value: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    face_value_currency_code: Mapped[str | None] = mapped_column(CHAR(3))

    # linked relationship
    alloy: Mapped[Alloy] = relationship(back_populates="coins")
