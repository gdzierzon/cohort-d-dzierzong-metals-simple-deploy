from dataclasses import dataclass
from decimal import Decimal, InvalidOperation

from dtos.base import DataTransferObject
from models import Element


ELEMENT_DECIMAL_FIELDS = (
    "melting_point_f",
    "boiling_point_f",
    "density",
)

ELEMENT_FIELDS = {
    "atomic_number",
    "name",
    "symbol",
    "melting_point_f",
    "boiling_point_f",
    "color",
    "density",
    "category",
    "state_at_room_temp",
    "is_toxic",
    "is_magnetic",
    "common_uses",
}


@dataclass(frozen=True)
class CreateElementDTO(DataTransferObject):
    decimal_fields = ELEMENT_DECIMAL_FIELDS

    atomic_number: int
    name: str
    symbol: str
    melting_point_f: Decimal | None = None
    boiling_point_f: Decimal | None = None
    color: str | None = None
    density: Decimal | None = None
    category: str | None = None
    state_at_room_temp: str | None = None
    is_toxic: bool = False
    is_magnetic: bool = False
    common_uses: str | None = None

    @classmethod
    def validate(cls, data: object) -> list[str]:
        if not isinstance(data, dict):
            return ["Request body must be a JSON object."]

        errors = []

        for field_name in sorted(set(data) - ELEMENT_FIELDS):
            errors.append(f"{field_name} is not a recognized field.")

        for field_name in ("atomic_number", "name", "symbol"):
            if field_name not in data:
                errors.append(f"{field_name} is required.")

        atomic_number = data.get("atomic_number")
        if "atomic_number" in data and (not isinstance(atomic_number, int)  or atomic_number <= 0):
            errors.append("atomic_number must be a positive integer.")

        for field_name, maximum_length in (("name", 50), ("symbol", 3)):
            if field_name in data:
                value = data[field_name]
                if not isinstance(value, str) or not value.strip():
                    errors.append(f"{field_name} must be a non-empty string.")
                elif len(value) > maximum_length:
                    errors.append(f"{field_name} must be {maximum_length} characters or fewer.")

        for field_name, maximum_length in (("color", 50), ("category", 40), ("state_at_room_temp", 20)):
            if field_name in data and data[field_name] is not None:
                value = data[field_name]
                if not isinstance(value, str) or not value.strip():
                    errors.append(f"{field_name} must be a non-empty string.")
                elif len(value) > maximum_length:
                    errors.append(f"{field_name} must be {maximum_length} characters or fewer.")

        if "common_uses" in data and data["common_uses"] is not None and not isinstance(data["common_uses"], str):
            errors.append("common_uses must be a string.")

        for field_name in ELEMENT_DECIMAL_FIELDS:
            if field_name in data and data[field_name] is not None:
                try:
                    number = Decimal(str(data[field_name]))
                    if not number.is_finite():
                        errors.append(f"{field_name} must be a finite number.")
                    elif field_name == "density" and number <= 0:
                        errors.append("density must be greater than 0.")
                except (InvalidOperation, TypeError, ValueError):
                    errors.append(f"{field_name} must be a number.")

        for field_name in ("is_toxic", "is_magnetic"):
            if field_name in data and not isinstance(data[field_name], bool):
                errors.append(f"{field_name} must be a boolean.")

        state = data.get("state_at_room_temp")
        if state is not None and state not in {"SOLID", "LIQUID", "GAS"}:
            errors.append("state_at_room_temp must be SOLID, LIQUID, or GAS.")

        melting_point = data.get("melting_point_f")
        boiling_point = data.get("boiling_point_f")
        try:
            if melting_point is not None and boiling_point is not None and Decimal(str(boiling_point)) <= Decimal(str(melting_point)):
                errors.append("boiling_point_f must be greater than melting_point_f.")
        except (InvalidOperation, TypeError, ValueError):
            pass

        return errors


@dataclass(frozen=True)
class UpdateElementDTO(DataTransferObject):
    decimal_fields = ELEMENT_DECIMAL_FIELDS

    # atomic_number: int | None = None
    name: str | None = None
    symbol: str | None = None
    melting_point_f: Decimal | None = None
    boiling_point_f: Decimal | None = None
    color: str | None = None
    density: Decimal | None = None
    category: str | None = None
    state_at_room_temp: str | None = None
    is_toxic: bool | None = None
    is_magnetic: bool | None = None
    common_uses: str | None = None

    @classmethod
    def validate(cls, data: object) -> list[str]:
        if not isinstance(data, dict):
            return ["Request body must be a JSON object."]

        errors = []
        allowed_fields = ELEMENT_FIELDS

        if not data:
            errors.append("At least one field must be provided.")

        for field_name in sorted(set(data) - allowed_fields):
            errors.append(f"{field_name} is not a recognized field.")

        for field_name, maximum_length in (("name", 50), ("symbol", 3), ("color", 50), ("category", 40), ("state_at_room_temp", 20)):
            if field_name in data and data[field_name] is not None:
                value = data[field_name]
                if not isinstance(value, str) or not value.strip():
                    errors.append(f"{field_name} must be a non-empty string.")
                elif len(value) > maximum_length:
                    errors.append(f"{field_name} must be {maximum_length} characters or fewer.")

        if "common_uses" in data and data["common_uses"] is not None and not isinstance(data["common_uses"], str):
            errors.append("common_uses must be a string.")

        for field_name in ELEMENT_DECIMAL_FIELDS:
            if field_name in data and data[field_name] is not None:
                try:
                    number = Decimal(str(data[field_name]))
                    if not number.is_finite():
                        errors.append(f"{field_name} must be a finite number.")
                    elif field_name == "density" and number <= 0:
                        errors.append("density must be greater than 0.")
                except (InvalidOperation, TypeError, ValueError):
                    errors.append(f"{field_name} must be a number.")

        for field_name in ("is_toxic", "is_magnetic"):
            if field_name in data and data[field_name] is not None and not isinstance(data[field_name], bool):
                errors.append(f"{field_name} must be a boolean.")

        state = data.get("state_at_room_temp")
        if state is not None and state not in {"SOLID", "LIQUID", "GAS"}:
            errors.append("state_at_room_temp must be SOLID, LIQUID, or GAS.")

        melting_point = data.get("melting_point_f")
        boiling_point = data.get("boiling_point_f")
        try:
            if melting_point is not None and boiling_point is not None and Decimal(str(boiling_point)) <= Decimal(str(melting_point)):
                errors.append("boiling_point_f must be greater than melting_point_f.")
        except (InvalidOperation, TypeError, ValueError):
            pass

        return errors


@dataclass(frozen=True)
class ElementResponseDTO(DataTransferObject):
    atomic_number: int
    name: str
    symbol: str
    melting_point_f: Decimal | None
    boiling_point_f: Decimal | None
    color: str | None
    density: Decimal | None
    category: str | None
    state_at_room_temp: str | None
    is_toxic: bool
    is_magnetic: bool
    common_uses: str | None

    @classmethod
    def from_model(cls, element: Element) -> "ElementResponseDTO":
        return cls(
            atomic_number=element.atomic_number,
            name=element.name,
            symbol=element.symbol.strip(),
            melting_point_f=element.melting_point_f,
            boiling_point_f=element.boiling_point_f,
            color=element.color,
            density=element.density,
            category=element.category,
            state_at_room_temp=element.state_at_room_temp,
            is_toxic=element.is_toxic,
            is_magnetic=element.is_magnetic,
            common_uses=element.common_uses,
        )
