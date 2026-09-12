from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from models import Alloy, AlloyUse


def get_alloys(
    session: Session,
    name: str | None = None,
    color: str | None = None,
    families: list[str] | None = None,
    uses: list[str] | None = None,
) -> list[Alloy]:
    # selectinload fetches every alloy's uses in one extra query instead of one
    # query per alloy, which matters now that the response includes them.
    statement = select(Alloy).options(selectinload(Alloy.use_links))

    if name:
        statement = statement.where(Alloy.name.ilike(f"%{name}%"))
    if color:
        statement = statement.where(Alloy.color.ilike(f"%{color}%"))
    if families:
        statement = statement.where(Alloy.alloy_family.in_(families))
    if uses:
        # An alloy matches if it carries ANY of the requested uses. A correlated
        # EXISTS keeps it to one row per alloy - joining the junction directly
        # would return duplicates for an alloy matching two of them.
        statement = statement.where(
            select(AlloyUse.alloy_id)
            .where(AlloyUse.alloy_id == Alloy.alloy_id)
            .where(AlloyUse.use_code.in_(uses))
            .exists()
        )

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


def set_alloy_uses(session: Session, alloy: Alloy, use_codes: list[str]) -> None:
    """Replace an alloy's uses with exactly the codes given."""
    # delete-orphan on the relationship turns the removals into DELETEs, so
    # reassigning the collection is enough - no manual cleanup needed.
    alloy.use_links = [
        AlloyUse(alloy_id=alloy.alloy_id, use_code=code)
        for code in sorted(set(use_codes))
    ]
    session.commit()
    session.refresh(alloy)


def delete_alloy(session: Session, alloy_id: int) -> bool:
    alloy = session.get(Alloy, alloy_id)
    if alloy is None:
        return False

    session.delete(alloy)
    session.commit()
    return True
