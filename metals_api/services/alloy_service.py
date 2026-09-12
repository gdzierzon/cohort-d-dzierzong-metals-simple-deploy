from database import SessionFactory
from dtos import AlloyResponseDTO, CreateAlloyDTO, UpdateAlloyDTO
from models import Alloy
from repositories import alloy_repository
from services.exceptions import BusinessValidationError


def list_alloys(
    name: str | None = None,
    color: str | None = None,
    families: list[str] | None = None,
    uses: list[str] | None = None,
) -> list[AlloyResponseDTO]:
    with SessionFactory() as session:
        alloys = alloy_repository.get_alloys(session, name, color, families, uses)
        return [
            AlloyResponseDTO.from_model(alloy)
            for alloy in alloys
        ]


def find_alloy(alloy_id: int) -> AlloyResponseDTO | None:
    with SessionFactory() as session:
        alloy = alloy_repository.get_alloy_by_id(session, alloy_id)
        if alloy is None:
            return None

        return AlloyResponseDTO.from_model(alloy)


def create_alloy(dto: CreateAlloyDTO) -> AlloyResponseDTO:
    with SessionFactory() as session:
        if alloy_repository.get_alloy_by_name(session, dto.name):
            raise BusinessValidationError(
                ["An alloy with this name already exists."]
            )

        # uses live in their own table, so they cannot be passed to Alloy().
        fields = dto.to_dictionary()
        use_codes = list(fields.pop("uses", ()) or ())

        alloy = Alloy(**fields)
        alloy = alloy_repository.add_alloy(session, alloy)

        if use_codes:
            alloy_repository.set_alloy_uses(session, alloy, use_codes)

        return AlloyResponseDTO.from_model(alloy)


def change_alloy(alloy_id: int, dto: UpdateAlloyDTO) -> AlloyResponseDTO | None:
    with SessionFactory() as session:
        current_alloy = alloy_repository.get_alloy_by_id(session, alloy_id)
        if current_alloy is None:
            return None

        if dto.name is not None:
            alloy_with_name = alloy_repository.get_alloy_by_name(
                session,
                dto.name,
            )
            if alloy_with_name and alloy_with_name.alloy_id != alloy_id:
                raise BusinessValidationError(
                    ["An alloy with this name already exists."]
                )

        changes = dto.to_dictionary(exclude_none=True)
        # Pulled out before the column update: None means "leave uses alone",
        # and exclude_none has already dropped it in that case. An empty list
        # survives, and means "remove every use".
        use_codes = changes.pop("uses", None)

        alloy = alloy_repository.update_alloy(session, alloy_id, changes)
        if alloy is None:
            return None

        if use_codes is not None:
            alloy_repository.set_alloy_uses(session, alloy, list(use_codes))

        return AlloyResponseDTO.from_model(alloy)


def remove_alloy(alloy_id: int) -> bool:
    with SessionFactory() as session:
        return alloy_repository.delete_alloy(session, alloy_id)
