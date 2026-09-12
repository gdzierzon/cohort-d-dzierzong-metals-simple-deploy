import os
import sys
from decimal import Decimal
from pathlib import Path

import pytest
import jwt


PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

TEST_JWT_SECRET = "test-jwt-secret-that-is-long-enough-for-hs256"

os.environ.setdefault("DB_USER", "test_user")
os.environ.setdefault("DB_PASSWORD", "test_password")
os.environ.setdefault("DB_HOST", "localhost")
os.environ.setdefault("DB_PORT", "5432")
os.environ.setdefault("DB_NAME", "test_metals")


@pytest.fixture
def app():
    from app import create_app

    flask_app = create_app()
    flask_app.config.update(
        TESTING=True,
        JWT_SECRET_KEY=TEST_JWT_SECRET,
        JWT_EXPIRATION_MINUTES=60,
        REFRESH_ROLES_ON_AUTHORIZATION=False,
    )
    return flask_app


@pytest.fixture
def client(app):
    client = app.test_client()
    client.environ_base["HTTP_AUTHORIZATION"] = f"Bearer {make_token('Admin')}"
    return client


def make_token(*roles: str) -> str:
    return jwt.encode(
        {
            "sub": "1",
            "username": "test-admin",
            "roles": list(roles),
        },
        TEST_JWT_SECRET,
        algorithm="HS256",
    )


@pytest.fixture
def element_response_dto():
    from dtos import ElementResponseDTO

    return ElementResponseDTO(
        atomic_number=29,
        name="Copper",
        symbol="Cu",
        melting_point_f=Decimal("1984"),
        boiling_point_f=Decimal("4652"),
        color="reddish",
        density=Decimal("8.96"),
        category="TRANSITION_METAL",
        state_at_room_temp="SOLID",
        is_toxic=False,
        is_magnetic=False,
        common_uses="wiring",
    )


@pytest.fixture
def alloy_response_dto():
    from dtos import AlloyResponseDTO

    return AlloyResponseDTO(
        alloy_id=2,
        name="Bronze",
        color="bronze",
        alloy_family="COPPER",
        description="Copper alloy",
        uses=["BEARING", "DECORATIVE"],
    )


@pytest.fixture
def alloy_element_response_dto():
    from dtos import AlloyElementResponseDTO

    return AlloyElementResponseDTO(
        alloy_id=2,
        atomic_number=29,
        percent_of_alloy=Decimal("88"),
    )


@pytest.fixture
def coin_response_dto():
    from dtos import CoinResponseDTO

    return CoinResponseDTO(
        coin_id=1,
        name="Test Coin",
        country="USA",
        mint="Test Mint",
        year_introduced=2000,
        alloy_id=2,
        gross_weight_g=Decimal("10"),
        face_value=Decimal("1"),
        face_value_currency_code="USD",
    )
