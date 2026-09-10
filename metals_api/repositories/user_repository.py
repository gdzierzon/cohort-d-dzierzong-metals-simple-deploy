from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from models import Role, User


def get_user_by_username(session: Session, username: str) -> User | None:
    statement = (
        select(User)
        .options(selectinload(User.roles))
        .where(func.lower(User.username) == username.lower())
    )
    return session.scalar(statement)


def get_role_by_name(session: Session, name: str) -> Role | None:
    statement = select(Role).where(func.lower(Role.name) == name.lower())
    return session.scalar(statement)


def get_users(session: Session) -> list[User]:
    statement = select(User).options(selectinload(User.roles)).order_by(User.username)
    return list(session.scalars(statement).all())


def get_user_by_id(session: Session, user_id: int) -> User | None:
    statement = (
        select(User)
        .options(selectinload(User.roles))
        .where(User.user_id == user_id)
    )
    return session.scalar(statement)


def save_user(session: Session, user: User) -> User:
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


def add_user(session: Session, user: User) -> User:
    session.add(user)
    session.commit()
    # Re-query with roles eagerly loaded. The authentication response is built
    # after the service session closes, so returning an unloaded relationship
    # would otherwise cause a detached-instance error after the user is saved.
    statement = (
        select(User)
        .options(selectinload(User.roles))
        .where(User.user_id == user.user_id)
    )
    created_user = session.scalar(statement)
    if created_user is None:
        raise RuntimeError("The newly created user could not be reloaded.")
    return created_user
