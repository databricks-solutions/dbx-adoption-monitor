"""Static contract tests for the conformed dimensional model."""

from pathlib import Path

import yaml


CONFORMED_TASKS = {
    "Set_Deployment_Context",
    "Publish_Conformed_Dimensions",
    "Publish_Conformed_Event_Facts",
    "Publish_Conformed_Cost_Facts",
    "Publish_Genie_Space_Daily_Summary",
    "Verify_Conformed_Model",
    "Deploy_Metric_Views",
    "Verify_Metric_Views",
}

LEGACY_TASKS = {
    "Ingest_Metadata",
    "Process_MatVews",
    "Process_Genie",
    "Process_Genie_Token_Usage",
    "Process_ServingUsage",
    "Process_VectorSearchCost",
    "Process_Apps",
    "Process_dbsql_cost_per_query",
    "Process_genie_cost_per_message",
    "Process_genie_cost_categorised",
}


def _workflow(repo_root: Path) -> dict:
    return yaml.safe_load(
        (repo_root / "deployment_resources" / "workflows.yml").read_text()
    )["resources"]["jobs"]["adoption_dash_job"]


def test_conformed_sources_are_committed(repo_root: Path) -> None:
    expected = {
        "src/03_set_deployment_context.py",
        "src/04_conformed_dimensions.sql",
        "src/05_conformed_event_facts.sql",
        "src/06_conformed_cost_facts.sql",
        "src/07_genie_space_daily_summary.sql",
        "src/08_verify_conformed_model.sql",
        "src/09_deploy_metric_views.py",
        "src/10_verify_metric_views.sql",
    }
    missing = [path for path in sorted(expected) if not (repo_root / path).is_file()]
    assert not missing, f"Missing conformed model sources: {missing}"


def test_workflow_dual_publishes_legacy_and_conformed_models(repo_root: Path) -> None:
    task_keys = {task["task_key"] for task in _workflow(repo_root)["tasks"]}
    assert LEGACY_TASKS <= task_keys
    assert CONFORMED_TASKS <= task_keys


def test_conformed_model_uses_portable_identifiers(repo_root: Path) -> None:
    source_paths = [
        repo_root / "src" / "04_conformed_dimensions.sql",
        repo_root / "src" / "05_conformed_event_facts.sql",
        repo_root / "src" / "06_conformed_cost_facts.sql",
        repo_root / "src" / "07_genie_space_daily_summary.sql",
    ]
    for path in source_paths:
        contents = path.read_text()
        assert "field_eng_slc" not in contents
        assert ":catalog_name" in contents
        assert ":schema_name" in contents


def test_conformed_tables_preserve_stable_identity(repo_root: Path) -> None:
    for name in (
        "04_conformed_dimensions.sql",
        "05_conformed_event_facts.sql",
        "06_conformed_cost_facts.sql",
        "07_genie_space_daily_summary.sql",
    ):
        contents = (repo_root / "src" / name).read_text().upper()
        assert "CREATE OR REPLACE TABLE" not in contents
        assert "CREATE TABLE IF NOT EXISTS" in contents
        assert "INSERT OVERWRITE" in contents
