from types import SimpleNamespace
from unittest.mock import MagicMock

from services import auth_service
from services.exceptions import BusinessValidationError
from conftest import make_token

# A valid passphrase under the length-based policy in dtos/auth_dto.py.
VALID_PASSPHRASE = "a sentence i will remember"


def _user(user_id: int = 1, username: str = "student", roles: tuple[str, ...] = ("Customer",)):
    return SimpleNamespace(
        user_id=user_id,
        username=username,
        roles=[SimpleNamespace(name=role) for role in roles],
    )


def test_register_creates_customer_and_returns_token(client, monkeypatch):
    register = MagicMock(return_value=_user())
    monkeypatch.setattr(auth_service, "register", register)

    response = client.post(
        "/api/auth/register",
        json={"username": "new_student", "password": VALID_PASSPHRASE},
    )

    assert response.status_code == 201
    assert response.get_json()["user"]["roles"] == ["Customer"]
    assert response.get_json()["token_type"] == "Bearer"
    register.assert_called_once_with("new_student", VALID_PASSPHRASE)


def test_register_rejects_duplicate_username(client, monkeypatch):
    monkeypatch.setattr(
        auth_service,
        "register",
        MagicMock(side_effect=BusinessValidationError(["That username is already in use."])),
    )

    response = client.post(
        "/api/auth/register",
        json={"username": "student", "password": VALID_PASSPHRASE},
    )

    assert response.status_code == 400
    assert response.get_json()["errors"] == ["That username is already in use."]


def test_login_returns_token_for_valid_credentials(client, monkeypatch):
    authenticate = MagicMock(return_value=_user(2, "admin", ("Admin",)))
    monkeypatch.setattr(auth_service, "authenticate", authenticate)

    response = client.post(
        "/api/auth/login",
        json={"username": "admin", "password": "password"},
    )

    assert response.status_code == 200
    assert response.get_json()["user"] == {
        "user_id": 2,
        "username": "admin",
        "roles": ["Admin"],
    }
    authenticate.assert_called_once_with("admin", "password")


def test_login_rejects_invalid_credentials(client, monkeypatch):
    monkeypatch.setattr(auth_service, "authenticate", MagicMock(return_value=None))

    response = client.post(
        "/api/auth/login",
        json={"username": "admin", "password": "incorrect"},
    )

    assert response.status_code == 401
    assert response.get_json() == {"error": "Invalid username or password."}


def test_me_returns_claims_from_access_token(client):
    response = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {make_token('Customer')}"},
    )

    assert response.status_code == 200
    assert response.get_json() == {
        "user_id": 1,
        "username": "test-admin",
        "roles": ["Customer"],
    }


def test_catalog_request_without_token_is_rejected(client):
    response = client.get("/api/elements", headers={"Authorization": ""})

    assert response.status_code == 401


def test_customer_cannot_create_catalog_data(client):
    response = client.post(
        "/api/elements",
        headers={"Authorization": f"Bearer {make_token('Customer')}"},
        json={"atomic_number": 29, "name": "Copper", "symbol": "Cu"},
    )

    assert response.status_code == 403
