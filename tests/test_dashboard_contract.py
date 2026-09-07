"""Static migration checks for the AI/BI dashboard."""

import json
from pathlib import Path

from scripts.generate_dashboard_contract import build_contract, walk  # type: ignore


LEGACY_OBJECTS = {
    "adb_genie_messages",
    "adb_genie_message_comments",
    "adb_genie_spaces",
    "dbsql_cost_per_query_table",
    "genie_cost_categorised",
    "genie_cost_per_message_table",
    "mvFactAppUsage",
    "mvFactDashboardUsage",
    "mvFactGenieTokenUsage",
    "mvFactGenieUsage",
    "mvFactServingUsage",
}


def _json(path: Path) -> dict:
    return json.loads(path.read_text())


def test_legacy_dashboard_contract_is_frozen(repo_root: Path) -> None:
    contract = _json(
        repo_root
        / "src"
        / "dashboards"
        / "lh_adoption_dashboard.legacy_contract.json"
    )
    assert contract["dataset_count"] == 31
    assert contract["page_count"] == 8
    assert contract["widget_count"] == 75


def test_dashboard_uses_metric_views_for_every_dataset(repo_root: Path) -> None:
    dashboard = _json(
        repo_root / "src" / "dashboards" / "lh_adoption_dashboard.lvdash.json"
    )
    assert len(dashboard["datasets"]) == 32
    assert len(dashboard["pages"]) == 9

    for dataset in dashboard["datasets"]:
        sql = "".join(dataset["queryLines"])
        assert "_metrics" in sql, f"{dataset['name']} does not query a Metric View"
        assert "system." not in sql.lower()
        assert "catalog" not in dataset
        assert "schema" not in dataset
        for object_name in LEGACY_OBJECTS:
            assert object_name.lower() not in sql.lower()


def test_dashboard_contract_matches_dashboard(repo_root: Path) -> None:
    dashboard_path = (
        repo_root / "src" / "dashboards" / "lh_adoption_dashboard.lvdash.json"
    )
    contract_path = (
        repo_root / "src" / "dashboards" / "lh_adoption_dashboard.contract.json"
    )
    assert build_contract(_json(dashboard_path)) == _json(contract_path)
    dashboard_text = dashboard_path.read_text()
    assert '"title": "Message ID"' in dashboard_text
    assert '"title": "Most Expensive Messages"' in dashboard_text
    assert "field_eng_slc" not in dashboard_text


def test_widget_encodings_reference_bound_fields(repo_root: Path) -> None:
    dashboard = _json(
        repo_root / "src" / "dashboards" / "lh_adoption_dashboard.lvdash.json"
    )
    for page in dashboard["pages"]:
        for layout_item in page.get("layout", []):
            widget = layout_item.get("widget", {})
            bound_fields = {
                field["name"]
                for node in walk(widget)
                if node.get("datasetName")
                for field in node.get("fields", [])
                if isinstance(field, dict) and field.get("name")
            }
            encoding_fields = {
                node["fieldName"]
                for node in walk(widget.get("spec", {}))
                if isinstance(node.get("fieldName"), str)
            }
            assert encoding_fields <= bound_fields, (
                f"{page['displayName']}.{widget.get('name')} has unbound encodings: "
                f"{sorted(encoding_fields - bound_fields)}"
            )


def test_vector_search_page_contract(repo_root: Path) -> None:
    dashboard = _json(
        repo_root / "src" / "dashboards" / "lh_adoption_dashboard.lvdash.json"
    )
    vector_page = next(
        page for page in dashboard["pages"] if page["displayName"] == "Vector Search"
    )
    sql = "".join(
        next(
            dataset for dataset in dashboard["datasets"] if dataset["name"] == "vs_usage"
        )["queryLines"]
    )
    assert len(vector_page["layout"]) == 5
    assert "vector_search_cost_metrics" in sql
    assert "MEASURE(`Vector Search DBUs`)" in sql
    assert "MEASURE(`Vector Search Cost USD`)" in sql
    assert "`SKU Name`" in sql
