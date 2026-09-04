from dataclasses import asdict
from decimal import Decimal
from typing import ClassVar, TypeVar


DTOType = TypeVar("DTOType", bound="DataTransferObject")


class DataTransferObject:
    decimal_fields: ClassVar[tuple[str, ...]] = ()

    @classmethod
    def from_dictionary(cls: type[DTOType], data: dict) -> DTOType:
        converted_data = data.copy()

        for field_name in cls.decimal_fields:
            value = converted_data.get(field_name)
            if value is not None:
                converted_data[field_name] = Decimal(str(value))

        return cls(**converted_data)

    def to_dictionary(self, exclude_none: bool = False) -> dict:
        data = asdict(self)

        if exclude_none:
            return {
                field: value
                for field, value in data.items()
                if value is not None
            }

        return data
