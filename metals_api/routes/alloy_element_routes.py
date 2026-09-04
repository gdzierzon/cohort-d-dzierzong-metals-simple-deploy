from flask import Blueprint, jsonify, request

from dtos import CreateAlloyElementDTO, UpdateAlloyElementDTO
from services import alloy_element_service as service
from services.exceptions import BusinessValidationError


alloy_element_blueprint = Blueprint(
    "alloy_elements",
    __name__,
    url_prefix="/api/alloy-elements",
)


# http://localhost:5000/api/alloy-elements
@alloy_element_blueprint.get("")
def get_all_alloy_elements():
    errors = []
    alloy_id = request.args.get("alloy_id")
    atomic_number = request.args.get("atomic_number")

    try:
        alloy_id = int(alloy_id) if alloy_id is not None else None
        if alloy_id is not None and alloy_id <= 0:
            errors.append("alloy_id must be a positive integer.")
    except ValueError:
        errors.append("alloy_id must be a positive integer.")

    try:
        atomic_number = int(atomic_number) if atomic_number is not None else None
        if atomic_number is not None and atomic_number <= 0:
            errors.append("atomic_number must be a positive integer.")
    except ValueError:
        errors.append("atomic_number must be a positive integer.")

    if errors:
        return jsonify({"errors": errors}), 400

    alloy_elements = service.list_alloy_elements(
        alloy_id=alloy_id,
        atomic_number=atomic_number,
    )
    
    return jsonify(
        [
            dto.to_dictionary()
            for dto in alloy_elements
        ]
    ), 200


# http://localhost:5000/api/alloy-elements/2/13
@alloy_element_blueprint.get("/<int:alloy_id>/<int:atomic_number>")
def get_alloy_element(alloy_id: int, atomic_number: int):
    dto = service.find_alloy_element(
        alloy_id,
        atomic_number,
    )
    if dto is None:
        return jsonify({"error": "Alloy element not found"}), 404

    return jsonify(dto.to_dictionary()), 200


# http://localhost:5000/api/alloy-elements
@alloy_element_blueprint.post("")
def create_alloy_element():
    data = request.get_json(silent=True)
    errors = CreateAlloyElementDTO.validate(data)
    if errors:
        return jsonify({"errors": errors}), 400

    request_dto = CreateAlloyElementDTO.from_dictionary(data)
    try:
        response_dto = service.create_alloy_element(request_dto)
    except BusinessValidationError as error:
        return jsonify({"errors": error.errors}), 400

    return jsonify(response_dto.to_dictionary()), 201


# http://localhost:5000/api/alloy-elements/2/13
@alloy_element_blueprint.put("/<int:alloy_id>/<int:atomic_number>")
def update_alloy_element(alloy_id: int, atomic_number: int):
    data = request.get_json(silent=True)
    errors = UpdateAlloyElementDTO.validate(data)
    if errors:
        return jsonify({"errors": errors}), 400

    request_dto = UpdateAlloyElementDTO.from_dictionary(data)
    try:
        response_dto = service.change_alloy_element(alloy_id, atomic_number, request_dto)
    except BusinessValidationError as error:
        return jsonify({"errors": error.errors}), 400

    if response_dto is None:
        return jsonify({"error": "Alloy element not found"}), 404

    return jsonify(response_dto.to_dictionary()), 200


# http://localhost:5000/api/alloy-elements/2/13
@alloy_element_blueprint.delete("/<int:alloy_id>/<int:atomic_number>")
def delete_alloy_element(alloy_id: int, atomic_number: int):
    deleted = service.remove_alloy_element(
        alloy_id,
        atomic_number,
    )
    if not deleted:
        return jsonify({"error": "Alloy element not found"}), 404

    return "", 204
