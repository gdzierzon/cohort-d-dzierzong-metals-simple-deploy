# we have a dependency on SessionFactory - this imports it
# to test the service we must replace  this with an injected Mock Session Factory
from database import SessionFactory
from dtos import (
    CreateElementDTO,
    ElementResponseDTO,
    UpdateElementDTO,
)
from models import Element
from repositories import element_repository
from services.exceptions import BusinessValidationError


def list_elements(name: str | None = None, color: str | None = None) -> list[ElementResponseDTO]:
    with SessionFactory() as session:
        elements = element_repository.get_elements(session, name, color)
        return [
            ElementResponseDTO.from_model(element)
            for element in elements
        ]


def find_element(atomic_number: int) -> ElementResponseDTO | None:
    with SessionFactory() as session:
        element = element_repository.get_element_by_id(
            session,
            atomic_number,
        )
        if element is None:
            return None

        return ElementResponseDTO.from_model(element)


def create_element(dto: CreateElementDTO) -> ElementResponseDTO:
    with SessionFactory() as session:
        errors = []

        if element_repository.get_element_by_id(session, dto.atomic_number):
            errors.append("An element with this atomic_number already exists.")
        if element_repository.get_element_by_name(session, dto.name):
            errors.append("An element with this name already exists.")
        if element_repository.get_element_by_symbol(session, dto.symbol):
            errors.append("An element with this symbol already exists.")

        if errors:
            raise BusinessValidationError(errors)

        element = Element(**dto.to_dictionary())
        element = element_repository.add_element(session, element)
        return ElementResponseDTO.from_model(element)


def change_element(atomic_number: int, dto: UpdateElementDTO) -> ElementResponseDTO | None:
    with SessionFactory() as session:
        current_element = element_repository.get_element_by_id(
            session,
            atomic_number,
        )
        if current_element is None:
            return None

        errors = []
        if dto.name is not None:
            element_with_name = element_repository.get_element_by_name(
                session,
                dto.name,
            )
            if element_with_name and element_with_name.atomic_number != atomic_number:
                errors.append("An element with this name already exists.")

        if dto.symbol is not None:
            element_with_symbol = element_repository.get_element_by_symbol(
                session,
                dto.symbol,
            )
            if element_with_symbol and element_with_symbol.atomic_number != atomic_number:
                errors.append("An element with this symbol already exists.")

        if errors:
            raise BusinessValidationError(errors)

        element = element_repository.update_element(
            session,
            atomic_number,
            dto.to_dictionary(exclude_none=True),
        )
        if element is None:
            return None

        return ElementResponseDTO.from_model(element)


def remove_element(atomic_number: int) -> bool:
    with SessionFactory() as session:
        return element_repository.delete_element(session, atomic_number)
