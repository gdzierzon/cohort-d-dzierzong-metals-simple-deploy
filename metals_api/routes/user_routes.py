from flask import Blueprint, g, jsonify, request

from auth import require_auth, require_roles
from services import auth_service


user_blueprint = Blueprint("users", __name__, url_prefix="/api/users")


@user_blueprint.get("")
@require_auth
@require_roles("Admin")
def get_all_users():
    return jsonify(auth_service.list_users()), 200


@user_blueprint.put("/<int:user_id>/admin")
@require_auth
@require_roles("Admin")
def update_admin_permission(user_id: int):
    data = request.get_json(silent=True)
    if not isinstance(data, dict) or not isinstance(data.get("is_admin"), bool):
        return jsonify({"errors": ["is_admin must be true or false."]}), 400

    if user_id == int(g.current_user["sub"]) and not data["is_admin"]:
        return jsonify({"error": "You cannot remove your own administrator permission."}), 400

    user = auth_service.set_admin_permission(user_id, data["is_admin"])
    if user is None:
        return jsonify({"error": "User not found"}), 404

    return jsonify(user), 200
