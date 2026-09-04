from database import SessionFactory
from dtos import CoinResponseDTO, CreateCoinDTO, UpdateCoinDTO
from models import Coin
from repositories import alloy_repository, coin_repository
from services.exceptions import BusinessValidationError


def list_coins(name: str | None = None, country: str | None = None, alloy_id: int | None = None) -> list[CoinResponseDTO]:
    with SessionFactory() as session:
        coins = coin_repository.get_coins(
            session,
            name,
            country,
            alloy_id,
        )
        return [
            CoinResponseDTO.from_model(coin)
            for coin in coins
        ]


def find_coin(coin_id: int) -> CoinResponseDTO | None:
    with SessionFactory() as session:
        coin = coin_repository.get_coin_by_id(session, coin_id)
        if coin is None:
            return None

        return CoinResponseDTO.from_model(coin)


def create_coin(dto: CreateCoinDTO) -> CoinResponseDTO:
    with SessionFactory() as session:
        if alloy_repository.get_alloy_by_id(session, dto.alloy_id) is None:
            raise BusinessValidationError(
                ["The specified alloy does not exist."]
            )

        coin = Coin(**dto.to_dictionary())
        coin = coin_repository.add_coin(session, coin)
        return CoinResponseDTO.from_model(coin)


def change_coin(coin_id: int, dto: UpdateCoinDTO) -> CoinResponseDTO | None:
    with SessionFactory() as session:
        if coin_repository.get_coin_by_id(session, coin_id) is None:
            return None

        if dto.alloy_id is not None and alloy_repository.get_alloy_by_id(session, dto.alloy_id) is None:
            raise BusinessValidationError(
                ["The specified alloy does not exist."]
            )

        coin = coin_repository.update_coin(
            session,
            coin_id,
            dto.to_dictionary(exclude_none=True),
        )
        if coin is None:
            return None

        return CoinResponseDTO.from_model(coin)


def remove_coin(coin_id: int) -> bool:
    with SessionFactory() as session:
        return coin_repository.delete_coin(session, coin_id)
