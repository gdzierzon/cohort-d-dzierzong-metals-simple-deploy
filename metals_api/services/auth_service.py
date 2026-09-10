from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerificationError
from flask import current_app

from database import SessionFactory
from models import User
from repositories import user_repository
from services.exceptions import BusinessValidationError


password_hasher = PasswordHasher()


def authenticate(username: str, password: str) -> User | None:
    with SessionFactory() as session:
        user = user_repository.get_user_by_username(session, username.strip().lower())
        if user is None:
            return None

        try:
            password_hasher.verify(user.password_hash, password)
        except VerificationError:
            return None

        return user


def register(username: str, password: str) -> User:
    normalized_username = username.strip().lower()

    with SessionFactory() as session:
        if user_repository.get_user_by_username(session, normalized_username):
            raise BusinessValidationError(["That username is already in use."])

        customer_role = user_repository.get_role_by_name(session, "Customer")
        if customer_role is None:
            raise RuntimeError("The Customer role has not been seeded.")

        user = User(
            username=normalized_username,
            password_hash=password_hasher.hash(password),
            roles=[customer_role],
        )
        return user_repository.add_user(session, user)


def list_users() -> list[dict]:
    with SessionFactory() as session:
        return [user_payload(user) for user in user_repository.get_users(session)]


def set_admin_permission(user_id: int, is_admin: bool) -> dict | None:
    with SessionFactory() as session:
        user = user_repository.get_user_by_id(session, user_id)
        if user is None:
            return None

        admin_role = user_repository.get_role_by_name(session, "Admin")
        if admin_role is None:
            raise RuntimeError("The Admin role has not been seeded.")

        has_admin_role = any(role.name == "Admin" for role in user.roles)
        if is_admin and not has_admin_role:
            user.roles.append(admin_role)
        elif not is_admin and has_admin_role:
            user.roles = [role for role in user.roles if role.name != "Admin"]

        updated_user = user_repository.save_user(session, user)
        return user_payload(updated_user)


def user_payload(user: User) -> dict:
    return {
        "user_id": user.user_id,
        "username": user.username,
        "roles": [role.name for role in user.roles],
    }


def create_access_token(user: User) -> tuple[str, int]:
    secret = current_app.config.get("JWT_SECRET_KEY")
    if not secret or secret == "replace-with-a-long-random-secret":
        raise RuntimeError("JWT_SECRET_KEY must be configured.")

    expiration_minutes = current_app.config["JWT_EXPIRATION_MINUTES"]
    issued_at = datetime.now(timezone.utc)
    expires_at = issued_at + timedelta(minutes=expiration_minutes)
    token = jwt.encode(
        {
            "sub": str(user.user_id),
            "username": user.username,
            "roles": [role.name for role in user.roles],
            "iat": issued_at,
            "exp": expires_at,
        },
        secret,
        algorithm="HS256",
    )
    return token, expiration_minutes * 60
