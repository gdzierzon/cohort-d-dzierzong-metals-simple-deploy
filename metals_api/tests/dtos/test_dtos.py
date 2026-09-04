from decimal import Decimal

from dtos import (
    CreateAlloyDTO,
    CreateAlloyElementDTO,
    CreateCoinDTO,
    CreateElementDTO,
    UpdateAlloyDTO,
    UpdateAlloyElementDTO,
    UpdateCoinDTO,
    UpdateElementDTO,
)


def test_create_element_dto_validates_multiple_errors():
    # Arrange
    data = {
        "atomic_number": 0,
        "name": "",
        "extra": True,
    }

    # Act
    errors = CreateElementDTO.validate(
        data
    )

    # Assert
    assert "atomic_number must be a positive integer." in errors
    assert "name must be a non-empty string." in errors
    assert "symbol is required." in errors
    assert "extra is not a recognized field." in errors


def test_create_element_dto_converts_decimal_fields():
    # Arrange
    data = {
        "atomic_number": 29,
        "name": "Copper",
        "symbol": "Cu",
        "density": 8.96,
    }

    # Act
    dto = CreateElementDTO.from_dictionary(
        data
    )

    # Assert
    assert dto.density == Decimal("8.96")


def test_update_element_dto_rejects_empty_body():
    # Arrange
    data = {}

    # Act
    errors = UpdateElementDTO.validate(data)

    # Assert
    assert errors == [
        "At least one field must be provided."
    ]


def test_alloy_dtos_validate_names_and_updates():
    # Arrange
    create_data = {"name": ""}
    update_data = {}

    # Act
    create_errors = CreateAlloyDTO.validate(create_data)
    update_errors = UpdateAlloyDTO.validate(update_data)

    # Assert
    assert create_errors == [
        "name must be a non-empty string."
    ]
    assert update_errors == [
        "At least one field must be provided."
    ]


def test_alloy_element_dtos_validate_percentage_range():
    # Arrange
    create_data = {
        "alloy_id": 2,
        "atomic_number": 29,
        "percent_of_alloy": 101,
    }
    update_data = {"percent_of_alloy": 0}

    # Act
    create_errors = CreateAlloyElementDTO.validate(
        create_data
    )
    update_errors = UpdateAlloyElementDTO.validate(update_data)

    # Assert
    assert create_errors == [
        "percent_of_alloy must be greater than 0 and at most 100."
    ]
    assert update_errors == [
        "percent_of_alloy must be greater than 0 and at most 100."
    ]


def test_coin_dtos_validate_business_input_shape():
    # Arrange
    create_data = {
        "name": "",
        "alloy_id": 0,
        "year_introduced": 400,
        "face_value_currency_code": "US",
    }
    update_data = {}

    # Act
    errors = CreateCoinDTO.validate(
        create_data
    )
    update_errors = UpdateCoinDTO.validate(update_data)

    # Assert
    assert errors == [
        "name must be a non-empty string.",
        "alloy_id must be a positive integer.",
        "year_introduced must be between 500 and 3000.",
        "face_value_currency_code must contain exactly 3 characters.",
    ]
    assert update_errors == [
        "At least one field must be provided."
    ]


def test_every_create_dto_rejects_non_object_json():
    # Arrange
    dto_types = (
        CreateElementDTO,
        CreateAlloyDTO,
        CreateAlloyElementDTO,
        CreateCoinDTO,
    )

    # Act
    validation_results = [
        dto_type.validate([])
        for dto_type in dto_types
    ]

    # Assert
    for errors in validation_results:
        assert errors == [
            "Request body must be a JSON object."
        ]
