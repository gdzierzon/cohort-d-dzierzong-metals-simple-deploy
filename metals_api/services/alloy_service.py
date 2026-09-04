from database import SessionFactory
from dtos import AlloyResponseDTO, CreateAlloyDTO, UpdateAlloyDTO
from models import Alloy
from repositories import alloy_repository
from services.exceptions import BusinessValidationError


def list_alloys(name: str | None = None, color: str | None = None) -> list[AlloyResponseDTO]:
    with SessionFactory() as session:
        alloys = alloy_repository.get_alloys(session, name, color)
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

        alloy = Alloy(**dto.to_dictionary())
        alloy = alloy_repository.add_alloy(session, alloy)
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

        alloy = alloy_repository.update_alloy(
            session,
            alloy_id,
            dto.to_dictionary(exclude_none=True),
        )
        if alloy is None:
            return None

        return AlloyResponseDTO.from_model(alloy)


def remove_alloy(alloy_id: int) -> bool:
    with SessionFactory() as session:
        return alloy_repository.delete_alloy(session, alloy_id)
