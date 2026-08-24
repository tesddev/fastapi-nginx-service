from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_health_returns_200_and_correct_structure():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert "status" in data
    assert data["status"] == "broken"
    assert "timestamp" in data


def test_root_returns_200():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "API is running"}


def test_me_returns_200_and_expected_keys():
    response = client.get("/me")
    assert response.status_code == 200
    data = response.json()
    for key in ("name", "email", "github", "stage"):
        assert key in data
