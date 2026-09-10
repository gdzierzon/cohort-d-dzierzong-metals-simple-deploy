from functools import wraps

import jwt
from flask import current_app, g, jsonify, request

from database import SessionFactory
from repositories import user_repository


def require_auth(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        authorization = request.headers.get("Authorization", "")
        scheme, _, token = authorization.partition(" ")
        if scheme.lower() != "bearer" or not token:
            return jsonify({"error": "Authentication required."}), 401

        try:
            g.current_user = jwt.decode(
                token,
                current_app.config["JWT_SECRET_KEY"],
                algorithms=["HS256"],
            )
        except jwt.InvalidTokenError:
            return jsonify({"error": "Invalid or expired access token."}), 401

        return view(*args, **kwargs)

    return wrapped


def require_roles(*required_roles: str):
    def decorator(view):
        @wraps(view)
        def wrapped(*args, **kwargs):
            current_roles = _get_current_roles()
            if not current_roles.intersection(required_roles):
                return jsonify({"error": "You do not have permission to perform this action."}), 403
            return view(*args, **kwargs)

        return wrapped

    return decorator


def _get_current_roles() -> set[str]:
    if not current_app.config.get("REFRESH_ROLES_ON_AUTHORIZATION", True):
        return set(g.current_user.get("roles", []))

    with SessionFactory() as session:
        user = user_repository.get_user_by_id(session, int(g.current_user["sub"]))
        return {role.name for role in user.roles} if user else set()
