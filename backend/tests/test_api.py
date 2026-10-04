import importlib
import os
import tempfile
import unittest

from fastapi.testclient import TestClient


class PriceHudApiTest(unittest.TestCase):
    def test_device_authorization_quote_and_revocation(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["DATABASE_URL"] = f"sqlite:///{directory}/pricehud.db"
            os.environ["ADMIN_API_KEY"] = "admin-secret-at-least-twenty-four-characters"
            os.environ["AGENT_API_KEY"] = "agent-secret-at-least-twenty-four-characters"
            os.environ["TOKEN_PEPPER"] = "pepper-secret-at-least-twenty-four-characters"
            import backend.app.main as api

            api = importlib.reload(api)
            with TestClient(api.app) as client:
                self.assertEqual(client.get("/health").status_code, 200)
                self.assertEqual(client.get("/v1/quotes/XAUUSD").status_code, 401)

                code_response = client.post(
                    "/v1/admin/activation-codes",
                    headers={"X-Admin-Key": os.environ["ADMIN_API_KEY"]},
                    json={"max_activations": 1, "expires_in_days": 1},
                )
                self.assertEqual(code_response.status_code, 200)
                activation_code = code_response.json()["activation_code"]

                activate_response = client.post(
                    "/v1/devices/activate",
                    json={"activation_code": activation_code, "device_label": "test phone"},
                )
                self.assertEqual(activate_response.status_code, 201)
                token = activate_response.json()["access_token"]
                headers = {"Authorization": f"Bearer {token}"}
                self.assertEqual(
                    client.post(
                        "/v1/devices/activate",
                        json={"activation_code": activation_code, "device_label": "second phone"},
                    ).status_code,
                    401,
                )

                self.assertEqual(
                    client.post("/v1/agent/quotes", json={"quotes": []}).status_code,
                    401,
                )

                publish_response = client.post(
                    "/v1/agent/quotes",
                    headers={"X-Agent-Key": os.environ["AGENT_API_KEY"]},
                    json={
                        "quotes": [
                            {"symbol": "XAUUSD", "bid": 2310.1, "ask": 2310.5, "time_msc": 1234567890}
                        ]
                    },
                )
                self.assertEqual(publish_response.status_code, 204)
                quote_response = client.get("/v1/quotes/XAUUSD", headers=headers)
                self.assertEqual(quote_response.status_code, 200)
                self.assertEqual(quote_response.json()["midpoint"], 2310.3)

                self.assertEqual(client.delete("/v1/devices/me", headers=headers).status_code, 204)
                self.assertEqual(client.get("/v1/quotes/XAUUSD", headers=headers).status_code, 401)
            api.engine.dispose()
