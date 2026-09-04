from sqlalchemy import select
from sqlalchemy.orm import Session

from models import AlloyElement


def get_alloy_elements(session: Session, alloy_id: int | None = None, atomic_number: int | None = None) -> list[AlloyElement]:
    statement = select(AlloyElement)

    if alloy_id is not None:
        statement = statement.where(AlloyElement.alloy_id == alloy_id)
    if atomic_number is not None:
        statement = statement.where(AlloyElement.atomic_number == atomic_number)

    statement = statement.order_by(
        AlloyElement.alloy_id,
        AlloyElement.atomic_number,
    )
    return list(session.scalars(statement))


def get_alloy_element_by_id(session: Session, alloy_id: int, atomic_number: int) -> AlloyElement | None:
    return session.get(AlloyElement, (alloy_id, atomic_number))


def add_alloy_element(session: Session, alloy_element: AlloyElement) -> AlloyElement:
    session.add(alloy_element)
    session.commit()
    session.refresh(alloy_element)
    return alloy_element


def update_alloy_element(session: Session, alloy_id: int, atomic_number: int, changes: dict) -> AlloyElement | None:
    alloy_element = session.get(
        AlloyElement,
        (alloy_id, atomic_number),
    )
    if alloy_element is None:
        return None

    if "percent_of_alloy" in changes:
        alloy_element.percent_of_alloy = changes["percent_of_alloy"]

    session.commit()
    session.refresh(alloy_element)
    return alloy_element


def delete_alloy_element(session: Session, alloy_id: int, atomic_number: int) -> bool:
    alloy_element = session.get(
        AlloyElement,
        (alloy_id, atomic_number),
    )
    if alloy_element is None:
        return False

    session.delete(alloy_element)
    session.commit()
    return True
