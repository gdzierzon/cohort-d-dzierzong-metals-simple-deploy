from sqlalchemy.orm import configure_mappers

from models import (
    Alloy,
    AlloyElement,
    AlloyUse,
    Base,
    Coin,
    Element,
    MintProduct,
    MintProductComponent,
    Role,
    User,
)


def test_all_models_are_registered_with_shared_metadata():
    # Arrange
    expected_tables = {
        "alloys",
        "alloy_elements",
        "alloy_uses",
        "coins",
        "elements",
        "mint_products",
        "mint_product_components",
        "roles",
        "users",
        "user_roles",
    }

    # Act
    registered_tables = set(Base.metadata.tables)

    # Assert
    assert registered_tables == expected_tables


def test_model_primary_keys_match_database_design():
    # Arrange
    expected_primary_keys = {
        Element: ["atomic_number"],
        Alloy: ["alloy_id"],
        MintProduct: ["mint_product_id"],
        # The coin subtype's primary key IS its foreign key - that pairing is
        # what makes the relationship 1:1.
        Coin: ["mint_product_id"],
        MintProductComponent: ["mint_product_id", "alloy_id", "component_role"],
        AlloyElement: ["alloy_id", "atomic_number"],
        User: ["user_id"],
        Role: ["role_id"],
    }

    # Act
    actual_primary_keys = {
        model: [
            column.name
            for column in model.__table__.primary_key
        ]
        for model in expected_primary_keys
    }

    # Assert
    assert actual_primary_keys[Element] == [
        "atomic_number"
    ]
    assert actual_primary_keys[Alloy] == [
        "alloy_id"
    ]
    assert actual_primary_keys[MintProduct] == [
        "mint_product_id"
    ]
    assert actual_primary_keys[Coin] == [
        "mint_product_id"
    ]
    assert actual_primary_keys[MintProductComponent] == [
        "mint_product_id",
        "alloy_id",
        "component_role",
    ]
    assert actual_primary_keys[AlloyElement] == [
        "alloy_id",
        "atomic_number",
    ]
    assert actual_primary_keys[User] == ["user_id"]
    assert actual_primary_keys[Role] == ["role_id"]


def test_model_relationships_configure_successfully():
    # Arrange
    expected_component_model = AlloyElement

    # Act
    configure_mappers()

    # Assert
    assert Element.alloy_links.property.mapper.class_ is expected_component_model
    assert Alloy.element_links.property.mapper.class_ is expected_component_model
    assert Alloy.mint_products.property.mapper.class_ is MintProduct
    assert MintProduct.alloy.property.mapper.class_ is Alloy
    # The supertype/subtype pair: one product, at most one coin.
    assert MintProduct.coin.property.mapper.class_ is Coin
    assert MintProduct.coin.property.uselist is False
    assert Coin.mint_product.property.mapper.class_ is MintProduct
    assert MintProduct.component_links.property.mapper.class_ is MintProductComponent
    assert User.roles.property.mapper.class_ is Role
    assert Role.users.property.mapper.class_ is User
