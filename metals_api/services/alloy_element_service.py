from decimal import Decimal

from database import SessionFactory
from dtos import ( AlloyElementResponseDTO, CreateAlloyElementDTO, UpdateAlloyElementDTO )
from models import AlloyElement
from repositories import (
    alloy_element_repository,
    alloy_repository,
    element_repository,
)
from services.exceptions import BusinessValidationError


def list_alloy_elements(alloy_id: int | None = None, atomic_number: int | None = None) -> list[AlloyElementResponseDTO]:
    with SessionFactory() as session:
        alloy_elements = alloy_element_repository.get_alloy_elements(session,alloy_id,atomic_number)
        
        return [
            AlloyElementResponseDTO.from_model(alloy_element)
            for alloy_element in alloy_elements
        ]


def find_alloy_element(alloy_id: int, atomic_number: int) -> AlloyElementResponseDTO | None:
    with SessionFactory() as session:
        alloy_element = alloy_element_repository.get_alloy_element_by_id(session,alloy_id,atomic_number)
        
        if alloy_element is None:
            return None

        return AlloyElementResponseDTO.from_model(alloy_element)


def create_alloy_element(dto: CreateAlloyElementDTO) -> AlloyElementResponseDTO:
    with SessionFactory() as session:
        errors = []

        if alloy_repository.get_alloy_by_id(session, dto.alloy_id) is None:
            errors.append("The specified alloy does not exist.")
        if element_repository.get_element_by_id(session, dto.atomic_number) is None:
            errors.append("The specified element does not exist.")
        if alloy_element_repository.get_alloy_element_by_id(session, dto.alloy_id, dto.atomic_number):
            errors.append("This element is already part of the alloy.")

        components = alloy_element_repository.get_alloy_elements(
            session,
            alloy_id=dto.alloy_id,
        )
        current_total = sum(
            (component.percent_of_alloy for component in components),
            Decimal("0"),
        )
        if current_total + dto.percent_of_alloy > 100:
            errors.append("The alloy composition cannot exceed 100 percent.")

        if errors:
            raise BusinessValidationError(errors)

        alloy_element = AlloyElement(**dto.to_dictionary())
        alloy_element = alloy_element_repository.add_alloy_element(session,alloy_element)
        
        return AlloyElementResponseDTO.from_model(alloy_element)


def change_alloy_element(alloy_id: int, atomic_number: int, dto: UpdateAlloyElementDTO) -> AlloyElementResponseDTO | None:
    with SessionFactory() as session:
        current_component = alloy_element_repository.get_alloy_element_by_id(
            session,
            alloy_id,
            atomic_number,
        )
        if current_component is None:
            return None

        if dto.percent_of_alloy is not None:
            components = alloy_element_repository.get_alloy_elements(
                session,
                alloy_id=alloy_id,
            )
            other_total = sum(
                (
                    component.percent_of_alloy
                    for component in components
                    if component.atomic_number != atomic_number
                ),
                Decimal("0"),
            )
            if other_total + dto.percent_of_alloy > 100:
                raise BusinessValidationError(
                    ["The alloy composition cannot exceed 100 percent."]
                )

        alloy_element = (
            alloy_element_repository.update_alloy_element(session,alloy_id,atomic_number,dto.to_dictionary(exclude_none=True))
        )
        
        if alloy_element is None:
            return None

        return AlloyElementResponseDTO.from_model(alloy_element)


def remove_alloy_element(alloy_id: int, atomic_number: int) -> bool:
    with SessionFactory() as session:
        return alloy_element_repository.delete_alloy_element(session,alloy_id,atomic_number)
