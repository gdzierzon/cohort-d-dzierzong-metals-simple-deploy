from dataclasses import dataclass

from dtos.base import DataTransferObject
from models import Alloy


@dataclass(frozen=True)
class CreateAlloyDTO(DataTransferObject):
    name: str
    color: str | None = None
    description: str | None = None

    @classmethod
    def validate(cls, data: object) -> list[str]:
        if not isinstance(data, dict):
            return ["Request body must be a JSON object."]

        errors = []
        allowed_fields = {"name", "color", "description"}

        for field_name in sorted(set(data) - allowed_fields):
            errors.append(f"{field_name} is not a recognized field.")

        if "name" not in data:
            errors.append("name is required.")
        elif not isinstance(data["name"], str) or not data["name"].strip():
            errors.append("name must be a non-empty string.")
        elif len(data["name"]) > 100:
            errors.append("name must be 100 characters or fewer.")

        if "color" in data and data["color"] is not None:
            if not isinstance(data["color"], str) or not data["color"].strip():
                errors.append("color must be a non-empty string.")
            elif len(data["color"]) > 50:
                errors.append("color must be 50 characters or fewer.")

        if "description" in data and data["description"] is not None and not isinstance(data["description"], str):
            errors.append("description must be a string.")

        return errors


@dataclass(frozen=True)
class UpdateAlloyDTO(DataTransferObject):
    name: str | None = None
    color: str | None = None
    description: str | None = None

    @classmethod
    def validate(cls, data: object) -> list[str]:
        if not isinstance(data, dict):
            return ["Request body must be a JSON object."]

        errors = []
        allowed_fields = {"name", "color", "description"}

        if not data:
            errors.append("At least one field must be provided.")

        for field_name in sorted(set(data) - allowed_fields):
            errors.append(f"{field_name} is not a recognized field.")

        if "name" in data:
            if not isinstance(data["name"], str) or not data["name"].strip():
                errors.append("name must be a non-empty string.")
            elif len(data["name"]) > 100:
                errors.append("name must be 100 characters or fewer.")

        if "color" in data and data["color"] is not None:
            if not isinstance(data["color"], str) or not data["color"].strip():
                errors.append("color must be a non-empty string.")
            elif len(data["color"]) > 50:
                errors.append("color must be 50 characters or fewer.")

        if "description" in data and data["description"] is not None and not isinstance(data["description"], str):
            errors.append("description must be a string.")

        return errors


@dataclass(frozen=True)
class AlloyResponseDTO(DataTransferObject):
    alloy_id: int
    name: str
    color: str | None
    description: str | None

    @classmethod
    def from_model(cls, alloy: Alloy) -> "AlloyResponseDTO":
        return cls(
            alloy_id=alloy.alloy_id,
            name=alloy.name,
            color=alloy.color,
            description=alloy.description,
        )
