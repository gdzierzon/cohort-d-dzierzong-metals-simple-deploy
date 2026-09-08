from pathlib import Path

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
    project_root = Path(__file__).resolve().parents[3]
    expected_env_file = project_root / ".env"

    # Act
    actual_env_file = env_file

    # Assert
    assert actual_env_file == expected_env_file
