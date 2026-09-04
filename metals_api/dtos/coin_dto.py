from dataclasses import dataclass
from decimal import Decimal, InvalidOperation

from dtos.base import DataTransferObject
from models import Coin


COIN_DECIMAL_FIELDS = (
    "gross_weight_g",
    "face_value",
)

COIN_FIELDS = {
    "name",
    "alloy_id",
    "country",
    "mint",
    "year_introduced",
    "gross_weight_g",
    "face_value",
    "face_value_currency_code",
}


@dataclass(frozen=True)
class CreateCoinDTO(DataTransferObject):
    decimal_fields = COIN_DECIMAL_FIELDS

    name: str
    alloy_id: int
    country: str | None = None
    mint: str | None = None
    year_introduced: int | None = None
    gross_weight_g: Decimal | None = None
    face_value: Decimal | None = None
    face_value_currency_code: str | None = None

    @classmethod
    def validate(cls, data: object) -> list[str]:
        if not isinstance(data, dict):
            return ["Request body must be a JSON object."]

        errors = []

        for field_name in sorted(set(data) - COIN_FIELDS):
            errors.append(f"{field_name} is not a recognized field.")

        for field_name in ("name", "alloy_id"):
            if field_name not in data:
                errors.append(f"{field_name} is required.")

        if "name" in data:
            if not isinstance(data["name"], str) or not data["name"].strip():
                errors.append("name must be a non-empty string.")
            elif len(data["name"]) > 120:
                errors.append("name must be 120 characters or fewer.")

        alloy_id = data.get("alloy_id")
        if "alloy_id" in data and (not isinstance(alloy_id, int) or isinstance(alloy_id, bool) or alloy_id <= 0):
            errors.append("alloy_id must be a positive integer.")

        for field_name, maximum_length in (("country", 80), ("mint", 120)):
            if field_name in data and data[field_name] is not None:
                value = data[field_name]
                if not isinstance(value, str) or not value.strip():
                    errors.append(f"{field_name} must be a non-empty string.")
                elif len(value) > maximum_length:
                    errors.append(f"{field_name} must be {maximum_length} characters or fewer.")

        year = data.get("year_introduced")
        if "year_introduced" in data and year is not None:
            if not isinstance(year, int) or isinstance(year, bool):
                errors.append("year_introduced must be an integer.")
            elif year < 500 or year > 3000:
                errors.append("year_introduced must be between 500 and 3000.")

        for field_name in COIN_DECIMAL_FIELDS:
            if field_name in data and data[field_name] is not None:
                try:
                    number = Decimal(str(data[field_name]))
                    if not number.is_finite():
                        errors.append(f"{field_name} must be a finite number.")
                    elif field_name == "gross_weight_g" and number <= 0:
                        errors.append("gross_weight_g must be greater than 0.")
                    elif field_name == "face_value" and number < 0:
                        errors.append("face_value must be at least 0.")
                except (InvalidOperation, TypeError, ValueError):
                    errors.append(f"{field_name} must be a number.")

        currency_code = data.get("face_value_currency_code")
        if currency_code is not None and (not isinstance(currency_code, str) or len(currency_code) != 3):
            errors.append("face_value_currency_code must contain exactly 3 characters.")

        return errors


@dataclass(frozen=True)
class UpdateCoinDTO(DataTransferObject):
    decimal_fields = COIN_DECIMAL_FIELDS

    name: str | None = None
    country: str | None = None
    mint: str | None = None
    year_introduced: int | None = None
    alloy_id: int | None = None
    gross_weight_g: Decimal | None = None
    face_value: Decimal | None = None
    face_value_currency_code: str | None = None

    @classmethod
    def validate(cls, data: object) -> list[str]:
        if not isinstance(data, dict):
            return ["Request body must be a JSON object."]

        errors = []

        if not data:
            errors.append("At least one field must be provided.")

        for field_name in sorted(set(data) - COIN_FIELDS):
            errors.append(f"{field_name} is not a recognized field.")

        if "name" in data:
            if not isinstance(data["name"], str) or not data["name"].strip():
                errors.append("name must be a non-empty string.")
            elif len(data["name"]) > 120:
                errors.append("name must be 120 characters or fewer.")

        alloy_id = data.get("alloy_id")
        if alloy_id is not None and (not isinstance(alloy_id, int) or isinstance(alloy_id, bool) or alloy_id <= 0):
            errors.append("alloy_id must be a positive integer.")

        for field_name, maximum_length in (("country", 80), ("mint", 120)):
            if field_name in data and data[field_name] is not None:
                value = data[field_name]
                if not isinstance(value, str) or not value.strip():
                    errors.append(f"{field_name} must be a non-empty string.")
                elif len(value) > maximum_length:
                    errors.append(f"{field_name} must be {maximum_length} characters or fewer.")

        year = data.get("year_introduced")
        if year is not None:
            if not isinstance(year, int) or isinstance(year, bool):
                errors.append("year_introduced must be an integer.")
            elif year < 500 or year > 3000:
                errors.append("year_introduced must be between 500 and 3000.")

        for field_name in COIN_DECIMAL_FIELDS:
            if field_name in data and data[field_name] is not None:
                try:
                    number = Decimal(str(data[field_name]))
                    if not number.is_finite():
                        errors.append(f"{field_name} must be a finite number.")
                    elif field_name == "gross_weight_g" and number <= 0:
                        errors.append("gross_weight_g must be greater than 0.")
                    elif field_name == "face_value" and number < 0:
                        errors.append("face_value must be at least 0.")
                except (InvalidOperation, TypeError, ValueError):
                    errors.append(f"{field_name} must be a number.")

        currency_code = data.get("face_value_currency_code")
        if currency_code is not None and (not isinstance(currency_code, str) or len(currency_code) != 3):
            errors.append("face_value_currency_code must contain exactly 3 characters.")

        return errors


@dataclass(frozen=True)
class CoinResponseDTO(DataTransferObject):
    coin_id: int
    name: str
    country: str | None
    mint: str | None
    year_introduced: int | None
    alloy_id: int
    gross_weight_g: Decimal | None
    face_value: Decimal | None
    face_value_currency_code: str | None

    @classmethod
    def from_model(cls, coin: Coin) -> "CoinResponseDTO":
        return cls(
            coin_id=coin.coin_id,
            name=coin.name,
            country=coin.country,
            mint=coin.mint,
            year_introduced=coin.year_introduced,
            alloy_id=coin.alloy_id,
            gross_weight_g=coin.gross_weight_g,
            face_value=coin.face_value,
            face_value_currency_code=coin.face_value_currency_code,
        )
