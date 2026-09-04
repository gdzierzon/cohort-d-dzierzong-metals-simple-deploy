from database import SessionFactory, engine
from database.connection import env_file


def test_database_package_exports_configured_engine():
    # Arrange
    expected_driver = "postgresql+psycopg"

    # Act
    actual_driver = engine.url.drivername
    bound_engine = SessionFactory.kw["bind"]

    # Assert
    assert actual_driver == expected_driver
    assert bound_engine is engine


def test_environment_file_is_resolved_from_module_root():
    # Arrange
    expected_file_name = ".env"
    expected_parent_name = "module_06_mvc_architecture_final"

    # Act
    actual_file_name = env_file.name
    actual_parent_name = env_file.parent.name

    # Assert
    assert actual_file_name == expected_file_name
    assert actual_parent_name == expected_parent_name
