from sqlalchemy.orm import configure_mappers

from models import Alloy, AlloyElement, Base, Coin, Element, Role, User


def test_all_models_are_registered_with_shared_metadata():
    # Arrange
    expected_tables = {
        "alloys",
        "alloy_elements",
        "coins",
        "elements",
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
        Coin: ["coin_id"],
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
    assert actual_primary_keys[Coin] == [
        "coin_id"
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
    assert Alloy.coins.property.mapper.class_ is Coin
    assert Coin.alloy.property.mapper.class_ is Alloy
    assert User.roles.property.mapper.class_ is Role
    assert Role.users.property.mapper.class_ is User
