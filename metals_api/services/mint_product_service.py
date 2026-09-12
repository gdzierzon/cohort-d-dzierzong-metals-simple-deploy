from database import SessionFactory
from dtos import CreateMintProductDTO, MintProductResponseDTO, UpdateMintProductDTO
from dtos.mint_product_dto import COIN_ONLY_FIELDS
from models import MintProduct
from repositories import mint_product_repository
from services.exceptions import BusinessValidationError


def list_mint_products(
    name: str | None = None,
    product_types: list[str] | None = None,
    metals: list[str] | None = None,
    families: list[str] | None = None,
    issuer: str | None = None,
    alloy_id: int | None = None,
) -> list[MintProductResponseDTO]:
    with SessionFactory() as session:
        products = mint_product_repository.get_mint_products(
            session, name, product_types, metals, families, issuer, alloy_id
        )
        return [MintProductResponseDTO.from_model(product) for product in products]


def list_coins(
    name: str | None = None,
    metals: list[str] | None = None,
    families: list[str] | None = None,
    issuer: str | None = None,
    alloy_id: int | None = None,
) -> list[MintProductResponseDTO]:
    """Coins only - the legal-tender slice of the catalog."""
    return list_mint_products(
        name=name,
        product_types=["COIN"],
        metals=metals,
        families=families,
        issuer=issuer,
        alloy_id=alloy_id,
    )


def find_mint_product(mint_product_id: int) -> MintProductResponseDTO | None:
    with SessionFactory() as session:
        product = mint_product_repository.get_mint_product_by_id(session, mint_product_id)
        if product is None:
            return None

        return MintProductResponseDTO.from_model(product)


def _split_coin_facts(fields: dict) -> dict | None:
    """Pull the legal-tender fields out of a flat payload.

    Returns None when none were supplied, which the repository reads as "no coin
    row". The request shape is flat for convenience; storage stays split.
    """
    facts = {name: fields.pop(name) for name in list(fields) if name in COIN_ONLY_FIELDS}
    if not facts:
        return None

    facts.setdefault("is_legal_tender", True)
    if facts["is_legal_tender"] is None:
        facts["is_legal_tender"] = True
    return facts


def create_mint_product(dto: CreateMintProductDTO) -> MintProductResponseDTO:
    with SessionFactory() as session:
        if mint_product_repository.get_mint_product_by_name(session, dto.name):
            raise BusinessValidationError(
                ["A mint product with this name already exists."]
            )

        fields = dto.to_dictionary()
        coin_facts = _split_coin_facts(fields)

        product = MintProduct(**fields)
        product = mint_product_repository.add_mint_product(session, product)

        if product.product_type == "COIN":
            mint_product_repository.set_coin_facts(session, product, coin_facts)

        # Re-read so the response carries the alloy and the coin row.
        product = mint_product_repository.get_mint_product_by_id(
            session, product.mint_product_id
        )
        return MintProductResponseDTO.from_model(product)


def change_mint_product(
    mint_product_id: int,
    dto: UpdateMintProductDTO,
) -> MintProductResponseDTO | None:
    with SessionFactory() as session:
        current = mint_product_repository.get_mint_product_by_id(session, mint_product_id)
        if current is None:
            return None

        if dto.name is not None:
            existing = mint_product_repository.get_mint_product_by_name(session, dto.name)
            if existing and existing.mint_product_id != mint_product_id:
                raise BusinessValidationError(
                    ["A mint product with this name already exists."]
                )

        changes = dto.to_dictionary(exclude_none=True)
        coin_facts = _split_coin_facts(changes)
        # The stored type applies unless this request changes it.
        resulting_type = changes.get("product_type", current.product_type)

        if resulting_type != "COIN" and coin_facts:
            raise BusinessValidationError(
                [f"a {resulting_type} cannot carry legal tender fields - only a COIN is money."]
            )

        # Order matters. The coins row holds product_type too, kept in step by
        # ON UPDATE CASCADE - so changing the product to a BAR first would
        # cascade 'BAR' into the coins row and trip its CHECK. The subtype row
        # has to go before the type changes, not after.
        if resulting_type != "COIN" and current.coin is not None:
            mint_product_repository.set_coin_facts(session, current, None)

        product = mint_product_repository.update_mint_product(session, mint_product_id, changes)
        if product is None:
            return None

        if resulting_type == "COIN" and coin_facts:
            mint_product_repository.set_coin_facts(session, product, coin_facts)

        product = mint_product_repository.get_mint_product_by_id(session, mint_product_id)
        return MintProductResponseDTO.from_model(product)


def remove_mint_product(mint_product_id: int) -> bool:
    with SessionFactory() as session:
        return mint_product_repository.delete_mint_product(session, mint_product_id)
