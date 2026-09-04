from sqlalchemy import select
from sqlalchemy.orm import Session

from models import Coin


def get_coins(session: Session, name: str | None = None, country: str | None = None, alloy_id: int | None = None) -> list[Coin]:
    statement = select(Coin)

    if name:
        statement = statement.where(Coin.name.ilike(f"%{name}%"))
    if country:
        statement = statement.where(Coin.country.ilike(f"%{country}%"))
    if alloy_id is not None:
        statement = statement.where(Coin.alloy_id == alloy_id)

    statement = statement.order_by(Coin.coin_id)
    return list(session.scalars(statement))


def get_coin_by_id(session: Session, coin_id: int) -> Coin | None:
    return session.get(Coin, coin_id)


def add_coin(session: Session, coin: Coin) -> Coin:
    session.add(coin)
    session.commit()
    session.refresh(coin)
    return coin


def update_coin(session: Session, coin_id: int, changes: dict) -> Coin | None:
    coin = session.get(Coin, coin_id)
    if coin is None:
        return None

    for field, value in changes.items():
        if field != "coin_id":
            setattr(coin, field, value)

    session.commit()
    session.refresh(coin)
    return coin


def delete_coin(session: Session, coin_id: int) -> bool:
    coin = session.get(Coin, coin_id)
    if coin is None:
        return False

    session.delete(coin)
    session.commit()
    return True
