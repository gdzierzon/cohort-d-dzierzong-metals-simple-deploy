from unittest.mock import MagicMock

from conftest import make_token
from services import auth_service


def test_admin_can_list_users(client, monkeypatch):
    users = [
        {"user_id": 1, "username": "admin", "roles": ["Customer", "Admin"]},
        {"user_id": 2, "username": "collector", "roles": ["Customer"]},
    ]
    monkeypatch.setattr(auth_service, "list_users", MagicMock(return_value=users))

    response = client.get("/api/users")

    assert response.status_code == 200
    assert response.get_json() == users


def test_customer_cannot_list_users(client):
    response = client.get(
        "/api/users",
        headers={"Authorization": f"Bearer {make_token('Customer')}"},
    )

    assert response.status_code == 403


def test_admin_can_grant_admin_permission(client, monkeypatch):
    updated = {"user_id": 2, "username": "collector", "roles": ["Customer", "Admin"]}
    update_permission = MagicMock(return_value=updated)
    monkeypatch.setattr(auth_service, "set_admin_permission", update_permission)

    response = client.put("/api/users/2/admin", json={"is_admin": True})

    assert response.status_code == 200
    assert response.get_json() == updated
    update_permission.assert_called_once_with(2, True)


def test_admin_can_remove_another_users_admin_permission(client, monkeypatch):
    updated = {"user_id": 2, "username": "collector", "roles": ["Customer"]}
    update_permission = MagicMock(return_value=updated)
    monkeypatch.setattr(auth_service, "set_admin_permission", update_permission)

    response = client.put("/api/users/2/admin", json={"is_admin": False})

    assert response.status_code == 200
    assert response.get_json() == updated
    update_permission.assert_called_once_with(2, False)


def test_admin_cannot_remove_own_admin_permission(client, monkeypatch):
    update_permission = MagicMock()
    monkeypatch.setattr(auth_service, "set_admin_permission", update_permission)

    response = client.put("/api/users/1/admin", json={"is_admin": False})

    assert response.status_code == 400
    assert response.get_json()["error"] == "You cannot remove your own administrator permission."
    update_permission.assert_not_called()


def test_update_admin_permission_requires_boolean(client):
    response = client.put("/api/users/2/admin", json={"is_admin": "yes"})

    assert response.status_code == 400
    assert response.get_json()["errors"] == ["is_admin must be true or false."]


def test_update_admin_permission_returns_not_found(client, monkeypatch):
    monkeypatch.setattr(auth_service, "set_admin_permission", MagicMock(return_value=None))

    response = client.put("/api/users/999/admin", json={"is_admin": True})

    assert response.status_code == 404
