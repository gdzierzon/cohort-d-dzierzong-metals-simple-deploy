from dataclasses import dataclass
from decimal import Decimal, InvalidOperation

from dtos.base import DataTransferObject
from models import AlloyElement


@dataclass(frozen=True)
class CreateAlloyElementDTO(DataTransferObject):
    decimal_fields = ("percent_of_alloy",)

    alloy_id: int
    atomic_number: int
    percent_of_alloy: Decimal

    @classmethod
    def validate(cls, data: object) -> list[str]:
        if not isinstance(data, dict):
            return ["Request body must be a JSON object."]

        errors = []
        allowed_fields = {
            "alloy_id",
            "atomic_number",
            "percent_of_alloy",
        }

        for field_name in sorted(set(data) - allowed_fields):
            errors.append(f"{field_name} is not a recognized field.")

        for field_name in allowed_fields:
            if field_name not in data:
                errors.append(f"{field_name} is required.")

        alloy_id = data.get("alloy_id")
        if "alloy_id" in data and (not isinstance(alloy_id, int) or isinstance(alloy_id, bool) or alloy_id <= 0):
            errors.append("alloy_id must be a positive integer.")

        atomic_number = data.get("atomic_number")
        if "atomic_number" in data and (not isinstance(atomic_number, int) or isinstance(atomic_number, bool) or atomic_number <= 0):
            errors.append("atomic_number must be a positive integer.")

        percentage = data.get("percent_of_alloy")
        if "percent_of_alloy" in data:
            try:
                percentage = Decimal(str(percentage))
                if not percentage.is_finite() or percentage <= 0 or percentage > 100:
                    errors.append("percent_of_alloy must be greater than 0 and at most 100.")
            except (InvalidOperation, TypeError, ValueError):
                errors.append("percent_of_alloy must be a number.")

        return errors


@dataclass(frozen=True)
class UpdateAlloyElementDTO(DataTransferObject):
    decimal_fields = ("percent_of_alloy",)

    percent_of_alloy: Decimal | None = None

    @classmethod
    def validate(cls, data: object) -> list[str]:
        if not isinstance(data, dict):
            return ["Request body must be a JSON object."]

        errors = []

        if not data:
            errors.append("percent_of_alloy is required.")

        for field_name in sorted(set(data) - {"percent_of_alloy"}):
            errors.append(f"{field_name} is not a recognized field.")

        if "percent_of_alloy" in data:
            try:
                percentage = Decimal(str(data["percent_of_alloy"]))
                if not percentage.is_finite() or percentage <= 0 or percentage > 100:
                    errors.append("percent_of_alloy must be greater than 0 and at most 100.")
            except (InvalidOperation, TypeError, ValueError):
                errors.append("percent_of_alloy must be a number.")

        return errors


@dataclass(frozen=True)
class AlloyElementResponseDTO(DataTransferObject):
    alloy_id: int
    atomic_number: int
    percent_of_alloy: Decimal

    @classmethod
    def from_model(cls, alloy_element: AlloyElement) -> "AlloyElementResponseDTO":
        return cls(
            alloy_id=alloy_element.alloy_id,
            atomic_number=alloy_element.atomic_number,
            percent_of_alloy=alloy_element.percent_of_alloy,
        )
