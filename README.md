# Databricks Adoption Monitor

An Asset Bundle that inventories and measures adoption of AI/BI Dashboards,
Genie, Databricks Apps, Model Serving, registered models, and Vector Search.
The workflow publishes a conformed dimensional model and governed Unity Catalog
Metric Views, then serves them through an AI/BI dashboard.

## Deploy

Prerequisites:

- Unity Catalog with access to the required `system.*` tables;
- a writable target catalog and schema;
- a SQL warehouse;
- Databricks CLI authentication for the target workspace.

Validate, deploy, and run with environment-specific overrides:

```bash
databricks bundle validate --strict \
  --var="catalog_name=<catalog>,schema_name=<schema>,my_warehouse_id=<warehouse-id>"
databricks bundle deploy \
  --var="catalog_name=<catalog>,schema_name=<schema>,my_warehouse_id=<warehouse-id>"
databricks bundle run adoption_dash_job \
  --var="catalog_name=<catalog>,schema_name=<schema>,my_warehouse_id=<warehouse-id>"
```

The default `lookback_days` is 365. Genie conversation comments can be disabled
for very large workspaces with `enable_genie_feedback_comments=false`.

## Data and semantics

- `src/01_get_metadata.ipynb` refreshes legacy workspace-API metadata tables.
- `src/02_*.sql` refreshes the legacy physical facts.
- `src/04_conformed_dimensions.sql` through
  `src/08_verify_conformed_model.sql` publish and verify the conformed model.
- `src/metric_views/` contains governed semantic definitions.
- `src/dashboards/lh_adoption_dashboard.lvdash.json` queries Metric Views and
  includes the Vector Search page.

See [the conformed model guide](docs/conformed-model-and-metric-views.md) and
[the cost attribution reference](docs/data-model-and-cost-attribution.md).

## Upgrading from the legacy model

The current release dual-publishes every existing `adb_*`, `mvFact*`, and
`*_table` physical table for one major-release compatibility window. Existing
custom readers continue to work after upgrade, while the bundled dashboard uses
Metric Views.

An old workflow version only refreshes the legacy model. The upgraded workflow
must run to refresh both models. Legacy object retirement is intentionally
deferred until downstream usage has been inventoried and a separate major
release is approved.

## Development

```bash
uv run --isolated --with-requirements requirements-dev.txt pytest
```

Runtime SQL invariants execute as part of the bundle workflow.

## Help and license

For questions or bugs, open a GitHub issue. Databricks support does not cover
this solution. See `LICENSE.md` and `NOTICE.md` for licensing terms.
