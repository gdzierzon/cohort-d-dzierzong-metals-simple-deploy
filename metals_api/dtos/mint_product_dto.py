from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation

from dtos.base import DataTransferObject
from models import MintProduct


# Mirrors chk_mint_products_type in sql/metals-db.sql.
PRODUCT_TYPES = ("COIN", "ROUND", "BAR", "INGOT", "MEDAL", "TOKEN", "NOTE")

# Mirrors chk_mint_product_component_role.
COMPONENT_ROLES = ("CORE", "CLADDING", "PLATING", "RING", "CENTER", "LEAF")

MINT_PRODUCT_DECIMAL_FIELDS = (
    "gross_weight_g",
    "fine_metal_weight_g",
    "face_value",
)

# The coin fields are accepted inline even though they live in their own table.
# Storage stays normalized; the request and response shapes stay convenient.
COIN_ONLY_FIELDS = {"face_value", "face_value_currency_code", "is_legal_tender"}

MINT_PRODUCT_FIELDS = {
    "name",
    "product_type",
    "issuer",
    "mint",
    "year_introduced",
    "gross_weight_g",
    "fine_metal_weight_g",
    "alloy_id",
} | COIN_ONLY_FIELDS


def _text_errors(data: dict, field_name: str, maximum_length: int) -> list[str]:
    value = data[field_name]
    if not isinstance(value, str) or not value.strip():
        return [f"{field_name} must be a non-empty string."]
    if len(value) > maximum_length:
        return [f"{field_name} must be {maximum_length} characters or fewer."]
    return []


def _shared_errors(data: dict) -> list[str]:
    errors = []

    for field_name in sorted(set(data) - MINT_PRODUCT_FIELDS):
        errors.append(f"{field_name} is not a recognized field.")

    if "name" in data:
        errors.extend(_text_errors(data, "name", 120))

    if "product_type" in data:
        product_type = data["product_type"]
        if not isinstance(product_type, str) or product_type not in PRODUCT_TYPES:
            errors.append("product_type must be one of: " + ", ".join(PRODUCT_TYPES) + ".")

    alloy_id = data.get("alloy_id")
    if "alloy_id" in data and (
        not isinstance(alloy_id, int) or isinstance(alloy_id, bool) or alloy_id <= 0
    ):
        errors.append("alloy_id must be a positive integer.")

    for field_name, maximum_length in (("issuer", 80), ("mint", 120)):
        if field_name in data and data[field_name] is not None:
            errors.extend(_text_errors(data, field_name, maximum_length))

    year = data.get("year_introduced")
    if "year_introduced" in data and year is not None:
        if not isinstance(year, int) or isinstance(year, bool):
            errors.append("year_introduced must be an integer.")
        elif year < -3000 or year > 3000:
            # Negative years are BC - a Roman denarius is -211.
            errors.append("year_introduced must be between -3000 and 3000.")

    numbers = {}
    for field_name in MINT_PRODUCT_DECIMAL_FIELDS:
        if field_name in data and data[field_name] is not None:
            try:
                number = Decimal(str(data[field_name]))
                if not number.is_finite():
                    errors.append(f"{field_name} must be a finite number.")
                    continue
                if field_name == "face_value":
                    if number < 0:
                        errors.append("face_value must be at least 0.")
                elif number <= 0:
                    errors.append(f"{field_name} must be greater than 0.")
                numbers[field_name] = number
            except (InvalidOperation, TypeError, ValueError):
                errors.append(f"{field_name} must be a number.")

    gross = numbers.get("gross_weight_g")
    fine = numbers.get("fine_metal_weight_g")
    if gross is not None and fine is not None and fine > gross:
        errors.append("fine_metal_weight_g must not exceed gross_weight_g.")

    currency_code = data.get("face_value_currency_code")
    if currency_code is not None and (not isinstance(currency_code, str) or len(currency_code) != 3):
        errors.append("face_value_currency_code must contain exactly 3 characters.")

    if "is_legal_tender" in data and data["is_legal_tender"] is not None:
        if not isinstance(data["is_legal_tender"], bool):
            errors.append("is_legal_tender must be true or false.")

    return errors


def _coin_consistency_errors(data: dict, product_type: object) -> list[str]:
    """The API mirror of the database's subtype rules."""
    errors = []
    supplied = sorted(COIN_ONLY_FIELDS & set(data))

    if product_type == "COIN":
        # The coins row requires a currency code, so a coin has to carry one.
        if not data.get("face_value_currency_code"):
            errors.append("face_value_currency_code is required when product_type is COIN.")
    elif supplied:
        errors.append(
            "a "
            + str(product_type)
            + " cannot have "
            + ", ".join(supplied)
            + " - only a COIN is legal tender."
        )

    return errors


@dataclass(frozen=True)
class CreateMintProductDTO(DataTransferObject):
    decimal_fields = MINT_PRODUCT_DECIMAL_FIELDS

    name: str
    product_type: str
    alloy_id: int
    issuer: str | None = None
    mint: str | None = None
    year_introduced: int | None = None
    gross_weight_g: Decimal | None = None
    fine_metal_weight_g: Decimal | None = None
    face_value: Decimal | None = None
    face_value_currency_code: str | None = None
    is_legal_tender: bool | None = None

    @classmethod
    def validate(cls, data: object) -> list[str]:
        if not isinstance(data, dict):
            return ["Request body must be a JSON object."]

        errors = []
        for field_name in ("name", "product_type", "alloy_id"):
            if field_name not in data:
                errors.append(f"{field_name} is required.")

        errors.extend(_shared_errors(data))
        if "product_type" in data:
            errors.extend(_coin_consistency_errors(data, data["product_type"]))
        return errors


@dataclass(frozen=True)
class UpdateMintProductDTO(DataTransferObject):
    decimal_fields = MINT_PRODUCT_DECIMAL_FIELDS

    name: str | None = None
    product_type: str | None = None
    alloy_id: int | None = None
    issuer: str | None = None
    mint: str | None = None
    year_introduced: int | None = None
    gross_weight_g: Decimal | None = None
    fine_metal_weight_g: Decimal | None = None
    face_value: Decimal | None = None
    face_value_currency_code: str | None = None
    is_legal_tender: bool | None = None

    @classmethod
    def validate(cls, data: object) -> list[str]:
        if not isinstance(data, dict):
            return ["Request body must be a JSON object."]

        errors = []
        if not data:
            errors.append("At least one field must be provided.")

        errors.extend(_shared_errors(data))
        # Only checkable when the type is part of this request; the service
        # re-checks against the stored type otherwise.
        if data.get("product_type") is not None:
            errors.extend(_coin_consistency_errors(data, data["product_type"]))
        return errors


@dataclass(frozen=True)
class MintProductComponentResponseDTO(DataTransferObject):
    alloy_id: int
    alloy_name: str
    component_role: str
    percent_of_weight: Decimal | None


@dataclass(frozen=True)
class MintProductResponseDTO(DataTransferObject):
    mint_product_id: int
    name: str
    product_type: str
    issuer: str | None
    mint: str | None
    year_introduced: int | None
    gross_weight_g: Decimal | None
    fine_metal_weight_g: Decimal | None
    alloy_id: int
    alloy_name: str
    alloy_family: str
    # What the reader thinks of as "a gold coin" - read through the alloy, never
    # stored on the product.
    primary_metal: str
    # True when a coins row exists. There is no stored flag for this.
    is_coin: bool
    face_value: Decimal | None
    face_value_currency_code: str | None
    is_legal_tender: bool | None
    components: list[dict] = field(default_factory=list)

    @classmethod
    def from_model(cls, product: MintProduct) -> "MintProductResponseDTO":
        coin = product.coin
        return cls(
            mint_product_id=product.mint_product_id,
            name=product.name,
            product_type=product.product_type,
            issuer=product.issuer,
            mint=product.mint,
            year_introduced=product.year_introduced,
            gross_weight_g=product.gross_weight_g,
            fine_metal_weight_g=product.fine_metal_weight_g,
            alloy_id=product.alloy_id,
            alloy_name=product.alloy.name,
            alloy_family=product.alloy.alloy_family,
            primary_metal=product.alloy.primary_metal,
            is_coin=coin is not None,
            face_value=coin.face_value if coin else None,
            face_value_currency_code=coin.face_value_currency_code if coin else None,
            is_legal_tender=coin.is_legal_tender if coin else None,
            components=[
                MintProductComponentResponseDTO(
                    alloy_id=link.alloy_id,
                    alloy_name=link.alloy.name,
                    component_role=link.component_role,
                    percent_of_weight=link.percent_of_weight,
                ).to_dictionary()
                for link in sorted(
                    product.component_links,
                    key=lambda link: (link.component_role, link.alloy_id),
                )
            ],
        )
