def test_health_is_public_and_does_not_query_database(app):
    with app.test_client() as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json == {"status": "ok"}
