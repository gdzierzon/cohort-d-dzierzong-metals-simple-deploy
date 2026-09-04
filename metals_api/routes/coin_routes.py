from flask import Blueprint, jsonify, request

from dtos import CreateCoinDTO, UpdateCoinDTO
from services import coin_service as service
from services.exceptions import BusinessValidationError


coin_blueprint = Blueprint(
    "coins",
    __name__,
    url_prefix="/api/coins",
)


# http://localhost:5000/api/coins
@coin_blueprint.get("")
def get_all_coins():
    alloy_id = request.args.get("alloy_id")
    if alloy_id is not None:
        try:
            alloy_id = int(alloy_id)
            if alloy_id <= 0:
                return jsonify({"errors": ["alloy_id must be a positive integer."]}), 400
        except ValueError:
            return jsonify({"errors": ["alloy_id must be a positive integer."]}), 400

    coins = service.list_coins(
        name=request.args.get("name"),
        country=request.args.get("country"),
        alloy_id=alloy_id,
    )
    return jsonify([dto.to_dictionary() for dto in coins]), 200


# http://localhost:5000/api/coins/1
@coin_blueprint.get("/<int:coin_id>")
def get_coin(coin_id: int):
    dto = service.find_coin(coin_id)
    if dto is None:
        return jsonify({"error": "Coin not found"}), 404

    return jsonify(dto.to_dictionary()), 200


# http://localhost:5000/api/coins
@coin_blueprint.post("")
def create_coin():
    data = request.get_json(silent=True)
    errors = CreateCoinDTO.validate(data)
    if errors:
        return jsonify({"errors": errors}), 400

    request_dto = CreateCoinDTO.from_dictionary(data)
    try:
        response_dto = service.create_coin(request_dto)
    except BusinessValidationError as error:
        return jsonify({"errors": error.errors}), 400

    return jsonify(response_dto.to_dictionary()), 201


# http://localhost:5000/api/coins/1
@coin_blueprint.put("/<int:coin_id>")
def update_coin(coin_id: int):
    data = request.get_json(silent=True)
    errors = UpdateCoinDTO.validate(data)
    if errors:
        return jsonify({"errors": errors}), 400

    request_dto = UpdateCoinDTO.from_dictionary(data)
    try:
        response_dto = service.change_coin(coin_id, request_dto)
    except BusinessValidationError as error:
        return jsonify({"errors": error.errors}), 400

    if response_dto is None:
        return jsonify({"error": "Coin not found"}), 404

    return jsonify(response_dto.to_dictionary()), 200


# http://localhost:5000/api/coins/1
@coin_blueprint.delete("/<int:coin_id>")
def delete_coin(coin_id: int):
    if not service.remove_coin(coin_id):
        return jsonify({"error": "Coin not found"}), 404

    return "", 204
