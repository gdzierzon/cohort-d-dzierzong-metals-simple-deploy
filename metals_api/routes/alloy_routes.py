from flask import Blueprint, jsonify, request

from dtos import CreateAlloyDTO, UpdateAlloyDTO
from services import alloy_service as service
from services.exceptions import BusinessValidationError


alloy_blueprint = Blueprint(
    "alloys",
    __name__,
    url_prefix="/api/alloys",
)


# http://localhost:5000/api/alloys
@alloy_blueprint.get("")
def get_all_alloys():
    alloys = service.list_alloys(
        name=request.args.get("name"),
        color=request.args.get("color"),
    )
    return jsonify([dto.to_dictionary() for dto in alloys]), 200


# http://localhost:5000/api/alloys/2
@alloy_blueprint.get("/<int:alloy_id>")
def get_alloy(alloy_id: int):
    dto = service.find_alloy(alloy_id)
    if dto is None:
        return jsonify({"error": "Alloy not found"}), 404

    return jsonify(dto.to_dictionary()), 200


# http://localhost:5000/api/alloys
@alloy_blueprint.post("")
def create_alloy():
    data = request.get_json(silent=True)
    errors = CreateAlloyDTO.validate(data)
    if errors:
        return jsonify({"errors": errors}), 400

    request_dto = CreateAlloyDTO.from_dictionary(data)
    try:
        response_dto = service.create_alloy(request_dto)
    except BusinessValidationError as error:
        return jsonify({"errors": error.errors}), 400

    return jsonify(response_dto.to_dictionary()), 201


# http://localhost:5000/api/alloys/2
@alloy_blueprint.put("/<int:alloy_id>")
def update_alloy(alloy_id: int):
    data = request.get_json(silent=True)
    errors = UpdateAlloyDTO.validate(data)
    if errors:
        return jsonify({"errors": errors}), 400

    request_dto = UpdateAlloyDTO.from_dictionary(data)
    try:
        response_dto = service.change_alloy(alloy_id, request_dto)
    except BusinessValidationError as error:
        return jsonify({"errors": error.errors}), 400

    if response_dto is None:
        return jsonify({"error": "Alloy not found"}), 404

    return jsonify(response_dto.to_dictionary()), 200


# http://localhost:5000/api/alloys/2
@alloy_blueprint.delete("/<int:alloy_id>")
def delete_alloy(alloy_id: int):
    if not service.remove_alloy(alloy_id):
        return jsonify({"error": "Alloy not found"}), 404

    return "", 204
