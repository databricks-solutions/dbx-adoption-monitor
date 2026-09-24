"""Static validation for source-controlled Databricks Metric Views."""

from pathlib import Path

import yaml


EXPECTED_METRIC_VIEWS = {
    "app_activity_metrics",
    "app_authentication_metrics",
    "app_cost_metrics",
    "app_inventory_metrics",
    "app_permission_metrics",
    "dashboard_adoption_metrics",
    "dashboard_inventory_metrics",
    "genie_conversation_metrics",
    "genie_feedback_metrics",
    "genie_message_cost_metrics",
    "genie_reach_metrics",
    "genie_space_adoption_metrics",
    "genie_token_cost_metrics",
    "genie_warehouse_cost_metrics",
    "model_inventory_metrics",
    "serving_adoption_metrics",
    "vector_search_cost_metrics",
}


def _definitions(repo_root: Path) -> dict[str, tuple[str, dict]]:
    definitions = {}
    for path in sorted((repo_root / "src" / "metric_views").glob("*.metric_view.sql")):
        sql = path.read_text()
        yaml_text = sql.split("AS $$", 1)[1].rsplit("$$", 1)[0]
        payload = yaml.safe_load(
            yaml_text.replace(
                "{{catalog_yaml_identifier}}", "`catalog-name`"
            ).replace(
                "{{schema_yaml_identifier}}", "`schema-name`"
            )
        )
        definitions[path.name.removesuffix(".metric_view.sql")] = (sql, payload)
    return definitions


def test_metric_view_inventory_is_complete(repo_root: Path) -> None:
    assert set(_definitions(repo_root)) == EXPECTED_METRIC_VIEWS


def test_metric_view_semantics_are_ai_ready(repo_root: Path) -> None:
    for name, (sql, payload) in _definitions(repo_root).items():
        assert name.endswith("_metrics")
        assert f".{name}\nWITH METRICS" in sql
        assert payload["version"] == 1.1
        assert isinstance(payload["source"], str)
        assert payload["comment"]
        assert payload["dimensions"]
        assert payload["measures"]
        assert "materialization" not in payload

        for field in (*payload["dimensions"], *payload["measures"]):
            assert field["name"]
            assert field["expr"]
            assert field["comment"], f"{name}.{field['name']} is missing a comment"
            assert field["display_name"], (
                f"{name}.{field['name']} is missing a display name"
            )


def test_metric_view_deployer_preserves_statement_text(repo_root: Path) -> None:
    deployer = (repo_root / "src" / "09_deploy_metric_views.py").read_text()
    assert "statement_execution.execute_statement" in deployer
    assert "experimental aitools" not in deployer
    assert "*.metric_view.sql" in deployer
    assert "quote_identifier" in deployer
    assert "yaml_single_quoted_identifier" in deployer
