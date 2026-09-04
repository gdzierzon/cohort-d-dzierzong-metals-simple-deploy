from sqlalchemy import func, select
from sqlalchemy.orm import Session

from models import Element


def get_elements(session: Session, name: str | None = None, color: str | None = None) -> list[Element]:
    statement = select(Element)

    if name:
        statement = statement.where(Element.name.ilike(f"%{name}%"))
    if color:
        statement = statement.where(Element.color.ilike(f"%{color}%"))

    statement = statement.order_by(Element.atomic_number)
    return list(session.scalars(statement))


def get_element_by_id(session: Session, atomic_number: int) -> Element | None:
    return session.get(Element, atomic_number)


def get_element_by_name(session: Session, name: str) -> Element | None:
    statement = select(Element).where(func.lower(Element.name) == name.lower())
    return session.scalar(statement)


def get_element_by_symbol(session: Session, symbol: str) -> Element | None:
    statement = select(Element).where(func.lower(Element.symbol) == symbol.lower())
    return session.scalar(statement)


def add_element(session: Session, element: Element) -> Element:
    session.add(element)
    session.commit()
    session.refresh(element)
    return element


def update_element(session: Session, atomic_number: int, changes: dict) -> Element | None:
    element = session.get(Element, atomic_number)
    if element is None:
        return None

    for field, value in changes.items():
        if field != "atomic_number":
            setattr(element, field, value)

    session.commit()
    session.refresh(element)
    return element


def delete_element(session: Session, atomic_number: int) -> bool:
    element = session.get(Element, atomic_number)
    if element is None:
        return False

    session.delete(element)
    session.commit()
    return True
