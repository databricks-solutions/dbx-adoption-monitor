"""Static contract tests for the conformed dimensional model."""
import re

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


def test_app_usage_audit_aggregates_by_canonical_id(repo_root: Path) -> None:
    """Regression guard for the fact_app_daily grain.

    Audit lifecycle events must be mapped to the canonical app_id and then
    aggregated by id, so an app seen under more than one name on the same day
    collapses to a single (app_id, usage_date, workspace_id) row instead of
    fanning out through the billing full-outer-join and breaking the grain.
    Also keeps the source public-safe (parameterised, no workspace-specific
    catalog/schema).
    """
    contents = (repo_root / "src" / "02_mvFactAppUsage.sql").read_text()
    assert "field_eng_slc" not in contents
    assert ":catalog_name" in contents
    assert ":schema_name" in contents
    assert "GROUP BY coalesce(x.app_id" in contents


def test_dim_app_audit_fallback_matches_event_fact_resolution(repo_root: Path) -> None:
    """Regression guard for the fact_app_activity_event -> dim_app referential check.

    fact_app_activity_event (05) mints an ``__AUDIT_NAME__`` id whenever an audit
    name does not map to exactly one non-audit app_id in dim_app's *resolved* rows
    (one canonical name per app_id). dim_app (04) must decide whether to emit that
    same fallback member off the identical, per-app_id-resolved name count -- not off
    raw base_candidates, where a renamed app can appear under several names and make a
    name look uniquely resolvable when it is not. Counting over raw candidates
    reintroduces the orphan __AUDIT_NAME__ id that breaks the resolution assertion.
    """
    contents = (repo_root / "src" / "04_conformed_dimensions.sql").read_text()
    assert "resolved_base_apps" in contents
    assert "FROM resolved_base_apps" in contents


def test_audit_derived_facts_read_shared_snapshot_not_live_audit(repo_root: Path) -> None:
    """Regression guard for the audit eventual-consistency race.

    system.access.audit is eventually consistent, so a dimension (04) and its event fact (05),
    running as separate tasks that each read audit live, can observe different row sets and leave
    a fact referencing a dimension member that did not yet exist -- breaking the "must resolve to
    dim_*" invariants in 08. 04 must materialise the audit slice once as stg_conformed_audit_events
    and the event facts (05) must read that committed table rather than system.access.audit.
    dim_principal in 04 is allowed to keep reading audit directly (no invariant depends on it).
    """
    dims = (repo_root / "src" / "04_conformed_dimensions.sql").read_text()
    facts = (repo_root / "src" / "05_conformed_event_facts.sql").read_text()

    assert "stg_conformed_audit_events" in dims
    assert "stg_conformed_audit_events" in facts

    # 05 must not read system.access.audit in a FROM/JOIN. Strip SQL string literals and
    # line comments first so descriptive COMMENT text / prose mentioning audit does not count.
    def _strip_noise(line: str) -> str:
        line = re.sub(r"'[^']*'", "", line)  # remove 'single-quoted' literals
        return line.split("--", 1)[0]  # remove trailing line comment

    live_reads = [
        line
        for line in facts.splitlines()
        if re.search(r"\b(from|join)\s+system\.access\.audit\b", _strip_noise(line), re.IGNORECASE)
    ]
    assert not live_reads, f"event facts must read the staged snapshot, not live audit: {live_reads}"


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
