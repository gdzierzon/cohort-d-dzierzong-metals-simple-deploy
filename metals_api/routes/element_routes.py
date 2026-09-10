from flask import Blueprint, jsonify, request

from auth import require_auth, require_roles
from dtos import CreateElementDTO, UpdateElementDTO
from services import element_service as service
from services.exceptions import BusinessValidationError


element_blueprint = Blueprint(
    "elements",
    __name__,
    url_prefix="/api/elements",
)


# http://localhost:5000/api/elements
@element_blueprint.get("")
@require_auth
def get_all_elements():
    elements = service.list_elements(
        name=request.args.get("name"),
        color=request.args.get("color"),
    )
    return jsonify([dto.to_dictionary() for dto in elements]), 200


# http://localhost:5000/api/elements/29
@element_blueprint.get("/<int:atomic_number>")
@require_auth
def get_element(atomic_number: int):
    dto = service.find_element(atomic_number)
    if dto is None:
        return jsonify({"error": "Element not found"}), 404

    return jsonify(dto.to_dictionary()), 200


# http://localhost:5000/api/elements
@element_blueprint.post("")
@require_auth
@require_roles("Admin")
def create_element():
    data = request.get_json(silent=True)
    errors = CreateElementDTO.validate(data)
    if errors:
        return jsonify({"errors": errors}), 400

    request_dto = CreateElementDTO.from_dictionary(data)
    try:
        response_dto = service.create_element(request_dto)
    except BusinessValidationError as error:
        return jsonify({"errors": error.errors}), 400

    return jsonify(response_dto.to_dictionary()), 201


# http://localhost:5000/api/elements/29
@element_blueprint.put("/<int:atomic_number>")
@require_auth
@require_roles("Admin")
def update_element(atomic_number: int):
    data = request.get_json(silent=True)
    errors = UpdateElementDTO.validate(data)
    if errors:
        return jsonify({"errors": errors}), 400
    
    try:
        request_dto = UpdateElementDTO.from_dictionary(data)
    except Exception as error:
        request_dto = None
        var = error

    try:
        response_dto = service.change_element(atomic_number, request_dto)
    except BusinessValidationError as error:
        return jsonify({"errors": error.errors}), 400

    if response_dto is None:
        return jsonify({"error": "Element not found"}), 404

    json = jsonify(response_dto.to_dictionary())
        
    return json, 200


# http://localhost:5000/api/elements/29
@element_blueprint.delete("/<int:atomic_number>")
@require_auth
@require_roles("Admin")
def delete_element(atomic_number: int):
    if not service.remove_element(atomic_number):
        return jsonify({"error": "Element not found"}), 404

    return "", 204
