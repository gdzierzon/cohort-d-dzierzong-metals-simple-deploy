from sqlalchemy import func, select
from sqlalchemy.orm import Session

from models import Alloy


def get_alloys(session: Session, name: str | None = None, color: str | None = None) -> list[Alloy]:
    statement = select(Alloy)

    if name:
        statement = statement.where(Alloy.name.ilike(f"%{name}%"))
    if color:
        statement = statement.where(Alloy.color.ilike(f"%{color}%"))

    statement = statement.order_by(Alloy.alloy_id)
    return list(session.scalars(statement))


def get_alloy_by_id(session: Session, alloy_id: int) -> Alloy | None:
    return session.get(Alloy, alloy_id)


def get_alloy_by_name(session: Session, name: str) -> Alloy | None:
    statement = select(Alloy).where(func.lower(Alloy.name) == name.lower())
    return session.scalar(statement)


def add_alloy(session: Session, alloy: Alloy) -> Alloy:
    session.add(alloy)
    session.commit()
    session.refresh(alloy)
    return alloy


def update_alloy(session: Session, alloy_id: int, changes: dict) -> Alloy | None:
    alloy = session.get(Alloy, alloy_id)
    if alloy is None:
        return None

    for field, value in changes.items():
        if field != "alloy_id":
            setattr(alloy, field, value)

    session.commit()
    session.refresh(alloy)
    return alloy


def delete_alloy(session: Session, alloy_id: int) -> bool:
    alloy = session.get(Alloy, alloy_id)
    if alloy is None:
        return False

    session.delete(alloy)
    session.commit()
    return True
