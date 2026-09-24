# Databricks notebook source
"""Render and deploy committed Metric View DDL without altering YAML indentation."""

import time
from pathlib import Path
from typing import TYPE_CHECKING, Any

from databricks.sdk import WorkspaceClient  # type: ignore

if TYPE_CHECKING:
    dbutils: Any


for parameter in ("catalog_name", "schema_name", "my_warehouse_id"):
    dbutils.widgets.text(parameter, "")

catalog_name = dbutils.widgets.get("catalog_name")
schema_name = dbutils.widgets.get("schema_name")
warehouse_id = dbutils.widgets.get("my_warehouse_id")

for label, value in (("catalog_name", catalog_name), ("schema_name", schema_name)):
    if not value or "\x00" in value:
        raise ValueError(f"{label} must be a non-empty Unity Catalog identifier")
if not warehouse_id:
    raise ValueError("my_warehouse_id is required")

context = dbutils.notebook.entry_point.getDbutils().notebook().getContext()
workspace_notebook_path = context.notebookPath().get()
metric_view_dir = (
    Path("/Workspace") / Path(workspace_notebook_path.lstrip("/")).parent / "metric_views"
)
definition_paths = sorted(metric_view_dir.glob("*.metric_view.sql"))
if not definition_paths:
    raise FileNotFoundError(f"No *.metric_view.sql definitions found in {metric_view_dir}")

w = WorkspaceClient()


def quote_identifier(value: str) -> str:
    return f"`{value.replace('`', '``')}`"


def yaml_single_quoted_identifier(value: str) -> str:
    return quote_identifier(value).replace("'", "''")


def state_value(response) -> str:
    state = response.status.state
    return getattr(state, "value", str(state)).upper()


for definition_path in definition_paths:
    statement = (
        definition_path.read_text()
        .replace(
            "{{catalog_yaml_identifier}}",
            yaml_single_quoted_identifier(catalog_name),
        )
        .replace(
            "{{schema_yaml_identifier}}",
            yaml_single_quoted_identifier(schema_name),
        )
        .replace("{{catalog_name}}", quote_identifier(catalog_name))
        .replace("{{schema_name}}", quote_identifier(schema_name))
    )
    if "{{" in statement or "}}" in statement:
        raise ValueError(f"Unresolved template token in {definition_path.name}")

    response = w.statement_execution.execute_statement(
        statement=statement,
        warehouse_id=warehouse_id,
        wait_timeout="50s",
    )
    while state_value(response) in {"PENDING", "RUNNING"}:
        time.sleep(2)
        response = w.statement_execution.get_statement(response.statement_id)

    if state_value(response) != "SUCCEEDED":
        error = response.status.error
        raise RuntimeError(
            f"Metric View deployment failed for {definition_path.name}: {error}"
        )
    print(f"Deployed {definition_path.name} ({response.statement_id})")
