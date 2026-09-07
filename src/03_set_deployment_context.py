# Databricks notebook source
"""Persist workspace-scoped deployment context for downstream SQL tasks."""

from typing import TYPE_CHECKING, Any

from databricks.sdk import WorkspaceClient  # type: ignore

if TYPE_CHECKING:
    dbutils: Any
    spark: Any


dbutils.widgets.text("catalog_name", "")
dbutils.widgets.text("schema_name", "")

catalog_name = dbutils.widgets.get("catalog_name")
schema_name = dbutils.widgets.get("schema_name")

for label, value in (("catalog_name", catalog_name), ("schema_name", schema_name)):
    if not value or "\x00" in value:
        raise ValueError(f"{label} must be a non-empty Unity Catalog identifier")

w = WorkspaceClient()
workspace_id = int(w.get_workspace_id())
workspace_url = w.config.host.rstrip("/")
quoted_catalog = f"`{catalog_name.replace('`', '``')}`"
quoted_schema = f"`{schema_name.replace('`', '``')}`"
context_table = f"{quoted_catalog}.{quoted_schema}.`model_deployment_context`"

spark.sql(
    f"""
    CREATE TABLE IF NOT EXISTS {context_table} (
      workspace_id BIGINT NOT NULL COMMENT 'Workspace ID of the bundle deployment.',
      workspace_url STRING NOT NULL COMMENT 'Workspace URL of the bundle deployment.',
      refreshed_at TIMESTAMP NOT NULL COMMENT 'Time at which deployment context was refreshed.'
    )
    USING DELTA
    COMMENT 'Single-row internal context used to scope workspace API metadata before publishing conformed dimensions.'
    """
)

spark.sql(
    f"""
    INSERT OVERWRITE {context_table}
    SELECT
      CAST({workspace_id} AS BIGINT),
      '{workspace_url.replace("'", "''")}',
      current_timestamp()
    """
)

print(f"Published deployment context for workspace {workspace_id} to {context_table}")
