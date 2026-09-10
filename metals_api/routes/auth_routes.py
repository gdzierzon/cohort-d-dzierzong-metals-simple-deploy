from flask import Blueprint, g, jsonify, request

from auth import require_auth
from dtos import LoginDTO, RegisterDTO
from services import auth_service
from services.exceptions import BusinessValidationError


auth_blueprint = Blueprint("auth", __name__, url_prefix="/api/auth")


def _token_response(user: object, status_code: int):
    token, expires_in = auth_service.create_access_token(user)
    return jsonify(
        {
            "access_token": token,
            "token_type": "Bearer",
            "expires_in": expires_in,
            "user": auth_service.user_payload(user),
        }
    ), status_code


@auth_blueprint.post("/register")
def register():
    data = request.get_json(silent=True)
    errors = RegisterDTO.validate(data)
    if errors:
        return jsonify({"errors": errors}), 400

    dto = RegisterDTO.from_dictionary(data)
    try:
        user = auth_service.register(dto.username, dto.password)
    except BusinessValidationError as error:
        return jsonify({"errors": error.errors}), 400

    return _token_response(user, 201)


@auth_blueprint.post("/login")
def login():
    data = request.get_json(silent=True)
    errors = LoginDTO.validate(data)
    if errors:
        return jsonify({"errors": errors}), 400

    dto = LoginDTO.from_dictionary(data)
    user = auth_service.authenticate(dto.username, dto.password)
    if user is None:
        return jsonify({"error": "Invalid username or password."}), 401

    return _token_response(user, 200)


@auth_blueprint.get("/me")
@require_auth
def current_user():
    return jsonify(
        {
            "user_id": int(g.current_user["sub"]),
            "username": g.current_user["username"],
            "roles": g.current_user["roles"],
        }
    ), 200
