# Conformed model and Metric Views

The upgraded workflow dual-publishes the legacy physical tables and a governed
dimensional model. Existing `adb_*`, `mvFact*`, and `*_table` readers keep
working for one major release; new dashboard datasets use Metric Views.

## Model

All workspace API natural keys are scoped by `workspace_id`. Dimensions are
current-state Type 1 tables; historical activity is retained in facts.

- `dim_workspace`, `dim_date`, and `dim_principal` are shared dimensions.
  Principal keys are SHA-256 hashes of normalized identities. Metric Views expose
  masked identity values by default.
- Entity dimensions are `dim_dashboard`, `dim_app`, `dim_genie_space`,
  `dim_genie_conversation`, `dim_serving_endpoint`,
  `dim_vector_search_endpoint`, and `dim_uc_model`.
- App audit events map to a canonical App ID only when the workspace/name
  crosswalk is unique. Unmatched or reused names receive an explicit
  `__AUDIT_NAME__` member instead of being assigned to an arbitrary App.
- Distribution detail is retained in `dim_dashboard_schedule` and
  `bridge_dashboard_subscription`.
- Re-aggregation-safe event facts are `fact_dashboard_view_event`,
  `fact_app_activity_event`, `fact_app_authentication_event`,
  `fact_app_permission_change_event`, `fact_genie_space_access_event`,
  `fact_genie_message`, and `fact_genie_feedback_comment`.
- Stable cost facts are `fact_app_daily`, `fact_serving_endpoint_daily`,
  `fact_vector_search_daily`, `fact_dbsql_query_cost`,
  `fact_genie_message_cost`, `fact_genie_query_cost_category`, and
  `fact_genie_token_usage_daily`.
- `fact_genie_space_daily_summary` is the only multi-source summary. Its grain
  is `workspace_id × space_id × activity_date`, and every stored measure is
  additive. Distinct users remain on the atomic Metric Views.

The configured `lookback_days` applies to conformed event and cost facts.
Genie token billing is only available from 2026-07-08, regardless of a longer
lookback.

## Cost semantics

Warehouse SQL cost and Genie LLM token cost are independent measures:

- complete Genie space warehouse cost comes from categorized query history;
- message warehouse cost is only the Conversation API-covered subset;
- `Statements Missing Cost` exposes query-history/billing lag;
- Genie Agent token cost is directly space-attributed by `agent_id`;
- Genie Code and Genie One token usage is user-scoped and has no space ID.

Do not add warehouse and token DBUs together as if they were one workload unit.
USD measures may be compared, but should remain separately labelled.

## Metric Views

Definitions live in `src/metric_views/*.metric_view.sql`. They use one fact
source each and declarative many-to-one joins to dimensions. The bundle runner
renders catalog/schema placeholders and submits each complete definition through
the Statement Execution API so YAML indentation is preserved.

No Metric View is materialized in this release. Materialization requires a
separate content, performance, and Lakeflow cost review based on observed query
profiles.

Queries use dimensions directly and measures through `MEASURE()`:

```sql
SELECT
  `Workspace Name`,
  `Usage Month`,
  MEASURE(`Serving Cost USD`) AS serving_cost_usd,
  MEASURE(`Inference Requests`) AS inference_requests
FROM serving_adoption_metrics
GROUP BY ALL;
```

## Compatibility window

The upgraded workflow refreshes both legacy and conformed objects. Running an
older bundle version refreshes only legacy objects. Legacy objects remain
physical tables with their existing names and schemas during the compatibility
window; removal or conversion requires a separately approved major release.

Before that release:

1. inventory custom queries that still read legacy objects;
2. migrate those readers to the documented Metric Views;
3. compare row counts and semantic measures;
4. approve legacy retirement explicitly.
