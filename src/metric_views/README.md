# Metric View definitions

Each `*.metric_view.sql` file contains one complete Databricks Metric View
definition. `{{catalog_name}}` and `{{schema_name}}` are rendered by
`src/09_deploy_metric_views.py`, which submits the resulting DDL through the
Statement Execution API so the YAML indentation is preserved.

The definitions intentionally have no `materialization` block. The first release
keeps Metric Views logical while runtime and dashboard query profiles are
collected; materialization can be reviewed separately if a proven hot path
justifies Lakeflow compute cost.

Design rules:

- one conformed fact or current-state inventory source per Metric View;
- only many-to-one joins to conformed dimensions;
- atomic measures first, then composed ratios through `MEASURE()`;
- complete comments, display names, synonyms, and applicable display formats;
- warehouse SQL cost and LLM token cost remain separate measures;
- user identities are exposed through masked principal dimensions.
