from flask import Blueprint, jsonify, request

from auth import require_auth, require_roles
from dtos import CreateMintProductDTO, UpdateMintProductDTO
from services import mint_product_service as service
from services.exceptions import BusinessValidationError


mint_product_blueprint = Blueprint(
    "mint_products",
    __name__,
    url_prefix="/api/mint-products",
)

# Coins are a slice of the same catalog, not a separate resource. This keeps
# /api/coins working for anything already pointed at it.
coin_blueprint = Blueprint(
    "coins",
    __name__,
    url_prefix="/api/coins",
)


def _filters():
    # getlist so filters can repeat: ?metal=GOLD&metal=SILVER means either.
    alloy_id = request.args.get("alloy_id", type=int)
    return {
        "name": request.args.get("name"),
        "issuer": request.args.get("issuer"),
        "metals": request.args.getlist("metal") or None,
        "families": request.args.getlist("family") or None,
        "alloy_id": alloy_id,
    }


# http://localhost:5000/api/mint-products
# http://localhost:5000/api/mint-products?type=BAR&type=ROUND&metal=SILVER
@mint_product_blueprint.get("")
@require_auth
def get_all_mint_products():
    products = service.list_mint_products(
        product_types=request.args.getlist("type") or None,
        **_filters(),
    )
    return jsonify([dto.to_dictionary() for dto in products]), 200


# http://localhost:5000/api/coins?metal=GOLD
@coin_blueprint.get("")
@require_auth
def get_all_coins():
    coins = service.list_coins(**_filters())
    return jsonify([dto.to_dictionary() for dto in coins]), 200


# http://localhost:5000/api/mint-products/2
@mint_product_blueprint.get("/<int:mint_product_id>")
@require_auth
def get_mint_product(mint_product_id: int):
    dto = service.find_mint_product(mint_product_id)
    if dto is None:
        return jsonify({"error": "Mint product not found"}), 404

    return jsonify(dto.to_dictionary()), 200


# http://localhost:5000/api/coins/2
@coin_blueprint.get("/<int:mint_product_id>")
@require_auth
def get_coin(mint_product_id: int):
    dto = service.find_mint_product(mint_product_id)
    if dto is None or not dto.is_coin:
        return jsonify({"error": "Coin not found"}), 404

    return jsonify(dto.to_dictionary()), 200


# http://localhost:5000/api/mint-products
@mint_product_blueprint.post("")
@require_auth
@require_roles("Admin")
def create_mint_product():
    data = request.get_json(silent=True)
    errors = CreateMintProductDTO.validate(data)
    if errors:
        return jsonify({"errors": errors}), 400

    request_dto = CreateMintProductDTO.from_dictionary(data)
    try:
        response_dto = service.create_mint_product(request_dto)
    except BusinessValidationError as error:
        return jsonify({"errors": error.errors}), 400

    return jsonify(response_dto.to_dictionary()), 201


# http://localhost:5000/api/mint-products/2
@mint_product_blueprint.put("/<int:mint_product_id>")
@require_auth
@require_roles("Admin")
def update_mint_product(mint_product_id: int):
    data = request.get_json(silent=True)
    errors = UpdateMintProductDTO.validate(data)
    if errors:
        return jsonify({"errors": errors}), 400

    request_dto = UpdateMintProductDTO.from_dictionary(data)
    try:
        response_dto = service.change_mint_product(mint_product_id, request_dto)
    except BusinessValidationError as error:
        return jsonify({"errors": error.errors}), 400

    if response_dto is None:
        return jsonify({"error": "Mint product not found"}), 404

    return jsonify(response_dto.to_dictionary()), 200


# http://localhost:5000/api/mint-products/2
@mint_product_blueprint.delete("/<int:mint_product_id>")
@require_auth
@require_roles("Admin")
def delete_mint_product(mint_product_id: int):
    if not service.remove_mint_product(mint_product_id):
        return jsonify({"error": "Mint product not found"}), 404

    return "", 204
