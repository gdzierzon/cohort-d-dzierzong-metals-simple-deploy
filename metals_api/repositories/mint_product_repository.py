from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload, selectinload

from models import Alloy, Coin, MintProduct, MintProductComponent


def _with_related():
    """Everything MintProductResponseDTO touches, loaded up front.

    The response reads product.alloy.primary_metal, product.coin and each
    component's alloy name. Without these, listing 37 products fires well over a
    hundred follow-up queries.
    """
    return (
        joinedload(MintProduct.alloy),
        joinedload(MintProduct.coin),
        selectinload(MintProduct.component_links).joinedload(MintProductComponent.alloy),
    )


def get_mint_products(
    session: Session,
    name: str | None = None,
    product_types: list[str] | None = None,
    metals: list[str] | None = None,
    families: list[str] | None = None,
    issuer: str | None = None,
    alloy_id: int | None = None,
) -> list[MintProduct]:
    statement = select(MintProduct).options(*_with_related())

    if name:
        statement = statement.where(MintProduct.name.ilike(f"%{name}%"))
    if alloy_id:
        # Matches the predominant alloy OR any layer. Asking "what is cupronickel
        # used in" should surface the clad quarter even though the quarter's
        # predominant alloy is the pure copper core underneath.
        statement = statement.where(
            (MintProduct.alloy_id == alloy_id)
            | select(MintProductComponent.mint_product_id)
            .where(MintProductComponent.mint_product_id == MintProduct.mint_product_id)
            .where(MintProductComponent.alloy_id == alloy_id)
            .exists()
        )
    if issuer:
        statement = statement.where(MintProduct.issuer.ilike(f"%{issuer}%"))
    if product_types:
        statement = statement.where(MintProduct.product_type.in_(product_types))
    # The metal and family filters live on the alloy, so they need the join -
    # this is the derivation paying off: nothing is duplicated onto the product.
    if metals:
        statement = statement.join(MintProduct.alloy).where(Alloy.primary_metal.in_(metals))
    elif families:
        statement = statement.join(MintProduct.alloy)
    if families:
        statement = statement.where(Alloy.alloy_family.in_(families))

    statement = statement.order_by(MintProduct.mint_product_id)
    return list(session.scalars(statement).unique())


def get_mint_product_by_id(session: Session, mint_product_id: int) -> MintProduct | None:
    statement = (
        select(MintProduct)
        .options(*_with_related())
        .where(MintProduct.mint_product_id == mint_product_id)
    )
    return session.scalars(statement).unique().one_or_none()


def get_mint_product_by_name(session: Session, name: str) -> MintProduct | None:
    statement = select(MintProduct).where(func.lower(MintProduct.name) == name.lower())
    return session.scalar(statement)


def _persist(session: Session, commit: bool) -> None:
    """Commit, or only flush when the caller is composing a larger transaction.

    A product and its coins row have to land together. Committing the product
    first and the coins row second means a refused coins row leaves a COIN with
    no coins row behind - exactly the state the supertype/subtype design exists
    to make impossible - and the database does refuse some of them, which is the
    entire point of the constraints on it. Callers writing both pass
    commit=False and commit once themselves.
    """
    if commit:
        session.commit()
    else:
        session.flush()


def add_mint_product(
    session: Session, product: MintProduct, commit: bool = True
) -> MintProduct:
    session.add(product)
    _persist(session, commit)
    session.refresh(product)
    return product


def update_mint_product(
    session: Session, mint_product_id: int, changes: dict, commit: bool = True
) -> MintProduct | None:
    product = session.get(MintProduct, mint_product_id)
    if product is None:
        return None

    for field, value in changes.items():
        if field != "mint_product_id":
            setattr(product, field, value)

    _persist(session, commit)
    session.refresh(product)
    return product


def set_coin_facts(
    session: Session, product: MintProduct, facts: dict | None, commit: bool = True
) -> None:
    """Attach, update, or remove the legal-tender subtype row.

    Passing None removes it, which is what turns a coin into a plain product.
    """
    if facts is None:
        product.coin = None
        _persist(session, commit)
        session.refresh(product)
        return

    if product.coin is None:
        product.coin = Coin(product_type="COIN", **facts)
    else:
        for field, value in facts.items():
            setattr(product.coin, field, value)

    _persist(session, commit)
    session.refresh(product)


def delete_mint_product(session: Session, mint_product_id: int) -> bool:
    product = session.get(MintProduct, mint_product_id)
    if product is None:
        return False

    session.delete(product)
    session.commit()
    return True
