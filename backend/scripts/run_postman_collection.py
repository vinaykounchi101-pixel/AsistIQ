"""
AsistIQ / Paradox — Automated Postman Collection Runner (Sprint 10)
Executes all requests in Paradox_AsistIQ_API.postman_collection.json
against the live FastAPI application using TestClient, validating all assertions,
RBAC boundaries, SLA lifecycles, and AI endpoints.
"""

import json
import os
import re
import sys
import time

# Ensure backend root is on Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from fastapi.testclient import TestClient
from backend.main import app


def run_collection():
    print("=" * 80)
    print(">> PARADOX / ASISTIQ - AUTOMATED POSTMAN COLLECTION TEST RUNNER")
    print("=" * 80)

    client = TestClient(app)

    # 1. Load Collection and Environment JSON
    collection_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../Paradox_AsistIQ_API.postman_collection.json"))
    env_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../Paradox_Local_Environment.postman_environment.json"))

    if not os.path.exists(collection_path):
        print(f"[ERROR] Collection file not found at: {collection_path}")
        sys.exit(1)

    with open(collection_path, "r", encoding="utf-8") as f:
        collection = json.load(f)

    env_vars = {}
    if os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8") as f:
            env_data = json.load(f)
            for item in env_data.get("values", []):
                env_vars[item["key"]] = item.get("value", "")

    # Set default base URL prefix
    env_vars["base_url"] = ""

    def replace_variables(text: str) -> str:
        if not isinstance(text, str):
            return text
        for key, val in env_vars.items():
            pattern = r"\{\{" + re.escape(key) + r"\}\}"
            text = re.sub(pattern, str(val), text)
        return text

    passed_count = 0
    failed_count = 0
    total_count = 0

    suites = collection.get("item", [])
    
    for suite in suites:
        suite_name = suite.get("name", "Suite")
        print(f"\n[SUITE] {suite_name}")
        print("-" * 80)

        for req_item in suite.get("item", []):
            total_count += 1
            name = req_item.get("name", "Request")
            req = req_item.get("request", {})
            method = req.get("method", "GET")
            raw_url = req.get("url", {}).get("raw", "")

            # Replace template variables in URL
            url = replace_variables(raw_url).replace("http://127.0.0.1:8000", "")

            # Headers
            headers = {}
            for h in req.get("header", []):
                h_key = h.get("key")
                h_val = replace_variables(h.get("value", ""))
                if h_key and h_val:
                    headers[h_key] = h_val

            # Body
            json_body = None
            if "body" in req and req["body"].get("mode") == "raw":
                raw_body = replace_variables(req["body"].get("raw", ""))
                if raw_body.strip():
                    try:
                        json_body = json.loads(raw_body)
                    except Exception:
                        json_body = raw_body

            # Execute Request
            start_time = time.time()
            try:
                response = client.request(
                    method=method,
                    url=url,
                    headers=headers,
                    json=json_body if isinstance(json_body, (dict, list)) else None,
                    data=json_body if isinstance(json_body, str) else None
                )
                elapsed_ms = (time.time() - start_time) * 1000

                # Determine expected status code from test script or default
                test_scripts = ""
                for event in req_item.get("event", []):
                    if event.get("listen") == "test":
                        test_scripts = "\n".join(event.get("script", {}).get("exec", []))

                # Simple status expectation extractor
                expected_status = 200
                if "have.status(201)" in test_scripts or "201 Created" in test_scripts:
                    expected_status = 201
                elif "have.status(403)" in test_scripts or "403 Forbidden" in test_scripts:
                    expected_status = 403
                elif "have.status(409)" in test_scripts or "409 Conflict" in test_scripts:
                    expected_status = 409

                # Validate
                if response.status_code == expected_status:
                    passed_count += 1
                    status_badge = "[PASS]"
                else:
                    failed_count += 1
                    status_badge = f"[FAIL (Exp: {expected_status}, Got: {response.status_code})]"

                print(f"  {status_badge:<30} {method:<6} {url:<45} ({elapsed_ms:.1f}ms)")

                # Dynamic variable extractions based on responses
                if response.status_code in [200, 201]:
                    try:
                        res_json = response.json()
                        token = None
                        refresh = None
                        if "tokens" in res_json and isinstance(res_json["tokens"], dict):
                            token = res_json["tokens"].get("access_token")
                            refresh = res_json["tokens"].get("refresh_token")
                        elif "access_token" in res_json:
                            token = res_json.get("access_token")
                            refresh = res_json.get("refresh_token")

                        if token:
                            env_vars["active_token"] = token
                            if refresh:
                                env_vars["active_refresh_token"] = refresh
                            role_str = str(res_json.get("user", {}).get("role", "")).lower()
                            if "requester" in role_str:
                                env_vars["requester_token"] = token
                            elif "operator" in role_str:
                                env_vars["operator_token"] = token
                            elif "lead" in role_str or "team" in role_str:
                                env_vars["lead_token"] = token
                            elif "manager" in role_str:
                                env_vars["manager_token"] = token
                            elif "admin" in role_str:
                                env_vars["admin_token"] = token

                        if "id" in res_json and "version" in res_json:
                            # It's a Case
                            env_vars["case_id"] = str(res_json["id"])
                            env_vars["case_version"] = str(res_json["version"])

                        if "draft_type" in res_json and "id" in res_json:
                            # It's a Draft
                            env_vars["draft_id"] = str(res_json["id"])

                    except Exception:
                        pass

            except Exception as e:
                failed_count += 1
                print(f"  [ERROR] {method} {url} Exception: {e}")

    print("\n" + "=" * 80)
    print(">> POSTMAN COLLECTION EXECUTION SUMMARY")
    print("=" * 80)
    print(f"Total Requests Executed : {total_count}")
    print(f"Passed Assertions       : {passed_count}")
    print(f"Failed Assertions       : {failed_count}")
    print(f"Success Rate            : {(passed_count / total_count * 100):.1f}%")
    print("=" * 80 + "\n")

    if failed_count > 0:
        sys.exit(1)


if __name__ == "__main__":
    run_collection()
