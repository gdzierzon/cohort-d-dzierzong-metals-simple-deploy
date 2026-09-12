from dataclasses import dataclass, field

from dtos.base import DataTransferObject
from models import Alloy


# Mirrors chk_alloy_family in sql/metals-db.sql. Validating here too means a bad
# value comes back as a readable 400 instead of a database constraint error.
ALLOY_FAMILIES = (
    "ALUMINUM",
    "COPPER",
    "FERROUS",
    "MAGNESIUM",
    "NICKEL",
    "PRECIOUS",
    "TIN",
    "TITANIUM",
    "ZINC",
)

# Mirrors chk_alloy_use_code.
ALLOY_USE_CODES = (
    "AEROSPACE",
    "BEARING",
    "BULLION",
    "COINAGE",
    "COOKWARE",
    "DECORATIVE",
    "ELECTRICAL",
    "FASTENERS",
    "HIGH_TEMPERATURE",
    "INSTRUMENTATION",
    "JEWELRY",
    "MARINE",
    "MEDICAL",
    "MUSICAL",
    "SOLDERING",
    "STRUCTURAL",
    "TOOLING",
)


def _name_errors(value: object) -> list[str]:
    if not isinstance(value, str) or not value.strip():
        return ["name must be a non-empty string."]
    if len(value) > 100:
        return ["name must be 100 characters or fewer."]
    return []


def _color_errors(value: object) -> list[str]:
    if not isinstance(value, str) or not value.strip():
        return ["color must be a non-empty string."]
    if len(value) > 50:
        return ["color must be 50 characters or fewer."]
    return []


def _family_errors(value: object) -> list[str]:
    if not isinstance(value, str) or not value.strip():
        return ["alloy_family must be a non-empty string."]
    if value not in ALLOY_FAMILIES:
        return [
            "alloy_family must be one of: " + ", ".join(ALLOY_FAMILIES) + "."
        ]
    return []


def _uses_errors(value: object) -> list[str]:
    if not isinstance(value, list):
        return ["uses must be a list of use codes."]

    errors = []
    for code in value:
        if not isinstance(code, str):
            errors.append("uses must contain only strings.")
            break

    unknown = sorted(
        {code for code in value if isinstance(code, str) and code not in ALLOY_USE_CODES}
    )
    for code in unknown:
        errors.append(f"{code} is not a recognized use code.")

    if len(value) != len({code for code in value if isinstance(code, str)}):
        errors.append("uses must not contain duplicates.")

    return errors


@dataclass(frozen=True)
class CreateAlloyDTO(DataTransferObject):
    name: str
    alloy_family: str
    color: str | None = None
    description: str | None = None
    uses: tuple[str, ...] = ()

    @classmethod
    def validate(cls, data: object) -> list[str]:
        if not isinstance(data, dict):
            return ["Request body must be a JSON object."]

        errors = []
        allowed_fields = {"name", "color", "alloy_family", "description", "uses"}

        for field_name in sorted(set(data) - allowed_fields):
            errors.append(f"{field_name} is not a recognized field.")

        if "name" not in data:
            errors.append("name is required.")
        else:
            errors.extend(_name_errors(data["name"]))

        # The column is NOT NULL with no default, so this genuinely is required.
        if "alloy_family" not in data:
            errors.append("alloy_family is required.")
        else:
            errors.extend(_family_errors(data["alloy_family"]))

        if "color" in data and data["color"] is not None:
            errors.extend(_color_errors(data["color"]))

        if "description" in data and data["description"] is not None and not isinstance(data["description"], str):
            errors.append("description must be a string.")

        if "uses" in data and data["uses"] is not None:
            errors.extend(_uses_errors(data["uses"]))

        return errors

    @classmethod
    def from_dictionary(cls, data: dict) -> "CreateAlloyDTO":
        return cls(
            name=data["name"],
            alloy_family=data["alloy_family"],
            color=data.get("color"),
            description=data.get("description"),
            uses=tuple(data.get("uses") or ()),
        )


@dataclass(frozen=True)
class UpdateAlloyDTO(DataTransferObject):
    name: str | None = None
    color: str | None = None
    alloy_family: str | None = None
    description: str | None = None
    # None means "leave the uses alone"; an empty tuple means "remove them all".
    uses: tuple[str, ...] | None = None

    @classmethod
    def validate(cls, data: object) -> list[str]:
        if not isinstance(data, dict):
            return ["Request body must be a JSON object."]

        errors = []
        allowed_fields = {"name", "color", "alloy_family", "description", "uses"}

        if not data:
            errors.append("At least one field must be provided.")

        for field_name in sorted(set(data) - allowed_fields):
            errors.append(f"{field_name} is not a recognized field.")

        if "name" in data:
            errors.extend(_name_errors(data["name"]))

        if "alloy_family" in data:
            errors.extend(_family_errors(data["alloy_family"]))

        if "color" in data and data["color"] is not None:
            errors.extend(_color_errors(data["color"]))

        if "description" in data and data["description"] is not None and not isinstance(data["description"], str):
            errors.append("description must be a string.")

        if "uses" in data and data["uses"] is not None:
            errors.extend(_uses_errors(data["uses"]))

        return errors

    @classmethod
    def from_dictionary(cls, data: dict) -> "UpdateAlloyDTO":
        uses = data.get("uses")
        return cls(
            name=data.get("name"),
            color=data.get("color"),
            alloy_family=data.get("alloy_family"),
            description=data.get("description"),
            uses=None if uses is None else tuple(uses),
        )


@dataclass(frozen=True)
class AlloyResponseDTO(DataTransferObject):
    alloy_id: int
    name: str
    color: str | None
    alloy_family: str
    # Derived from the composition by the seed, never typed in.
    primary_metal: str
    description: str | None
    uses: list[str] = field(default_factory=list)

    @classmethod
    def from_model(cls, alloy: Alloy) -> "AlloyResponseDTO":
        return cls(
            alloy_id=alloy.alloy_id,
            name=alloy.name,
            color=alloy.color,
            alloy_family=alloy.alloy_family,
            primary_metal=alloy.primary_metal,
            description=alloy.description,
            uses=sorted(link.use_code for link in alloy.use_links),
        )
