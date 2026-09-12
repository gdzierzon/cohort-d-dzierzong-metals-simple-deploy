from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.base import Base

# import only for Pylance - ommitted for deployed code
if TYPE_CHECKING:
    from models.alloy import Alloy


class AlloyUse(Base):
    __tablename__ = "alloy_uses"

    alloy_id: Mapped[int] = mapped_column(
        SmallInteger,
        ForeignKey(
            "alloys.alloy_id",
            name="fk_alloy_uses_alloy",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )
    use_code: Mapped[str] = mapped_column(
        String(40),
        primary_key=True,
    )

    alloy: Mapped[Alloy] = relationship(back_populates="use_links")
