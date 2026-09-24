-- Stable conformed cost and usage facts. Legacy physical tables remain in place;
-- these projections provide consistent names, null members, and grains for Metric Views.

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_daily') (
  app_id STRING,
  app_name STRING,
  usage_date DATE,
  workspace_id BIGINT,
  workspace_name STRING,
  dbus DECIMAL(38,6),
  dollars DECIMAL(38,6),
  lifecycle_events BIGINT,
  distinct_users BIGINT
) USING DELTA
PARTITIONED BY (workspace_id)
COMMENT 'Daily Databricks Apps cost and lifecycle summary. Grain: workspace_id plus app_id plus usage_date.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_daily')
SELECT
  app_id, app_name, usage_date, workspace_id, workspace_name,
  dbus, dollars, lifecycle_events, distinct_users
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactAppUsage');

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_serving_endpoint_daily') (
  endpoint_id STRING,
  endpoint_name STRING,
  served_entity_id STRING,
  entity_type STRING,
  entity_name STRING,
  entity_version STRING,
  entity_count INT,
  usage_date DATE,
  workspace_id BIGINT,
  workspace_name STRING,
  request_count BIGINT,
  input_tokens BIGINT,
  output_tokens BIGINT,
  dbus DECIMAL(38,6),
  dollars DECIMAL(38,6)
) USING DELTA
PARTITIONED BY (workspace_id, entity_type)
COMMENT 'Daily Model Serving endpoint request, token, DBU, and USD measures. Grain: workspace_id plus endpoint_id plus usage_date.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_serving_endpoint_daily')
SELECT
  endpoint_id, endpoint_name, served_entity_id, entity_type, entity_name,
  entity_version, entity_count, usage_date, workspace_id, workspace_name,
  request_count, input_tokens, output_tokens, dbus, dollars
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactServingUsage');

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_vector_search_daily') (
  endpoint_id STRING NOT NULL COMMENT 'Vector Search endpoint identifier or __UNATTRIBUTED__ for index-maintenance billing.',
  endpoint_name STRING NOT NULL COMMENT 'Endpoint name or explicit unattributed label.',
  usage_date DATE NOT NULL COMMENT 'Calendar date of the billing usage.',
  workspace_id BIGINT NOT NULL COMMENT 'Workspace associated with the billing usage.',
  workspace_name STRING COMMENT 'Current workspace display name.',
  sku_name STRING NOT NULL COMMENT 'Vector Search or related maintenance SKU.',
  dbus DECIMAL(38,6) NOT NULL COMMENT 'Additive Databricks Units consumed.',
  dollars DECIMAL(38,6) NOT NULL COMMENT 'Additive USD list-price cost.',
  is_attributed BOOLEAN NOT NULL COMMENT 'True when billing metadata identifies a Vector Search endpoint.'
) USING DELTA
PARTITIONED BY (usage_date)
COMMENT 'Daily Vector Search billing fact with an explicit unattributed member. Grain: workspace_id plus endpoint_id plus usage_date plus sku_name.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_vector_search_daily')
SELECT
  COALESCE(endpoint_id, '__UNATTRIBUTED__') AS endpoint_id,
  endpoint_name,
  usage_date,
  workspace_id,
  workspace_name,
  sku_name,
  dbus,
  dollars,
  endpoint_id IS NOT NULL AS is_attributed
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactVectorSearchCost');

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_token_usage_daily') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace associated with Genie token usage.',
  principal_id STRING COMMENT 'Hashed identity attributed to Genie token usage.',
  genie_surface STRING COMMENT 'Genie product surface: GENIE_CODE, GENIE_ONE, or GENIE_AGENTS.',
  genie_channel STRING COMMENT 'UI or API token-usage channel.',
  agent_id STRING COMMENT 'Genie Agent space identifier; null for Genie Code and Genie One.',
  space_name STRING COMMENT 'Genie Agent space name; null for Genie Code and Genie One.',
  genie_offering STRING COMMENT 'Genie billing offering recorded in product features.',
  tier STRING NOT NULL COMMENT 'FREE or PAID token billing tier.',
  sku_name STRING NOT NULL COMMENT 'Genie token billing SKU.',
  cloud_region STRING COMMENT 'Region encoded in the paid token SKU.',
  usage_date DATE NOT NULL COMMENT 'Calendar date of token billing usage.',
  token_dbus DECIMAL(38,6) NOT NULL COMMENT 'Additive DBUs recorded for Genie LLM token usage.',
  token_cost_usd DECIMAL(38,6) NOT NULL COMMENT 'Additive Genie LLM token cost at effective USD list price.',
  usage_records BIGINT NOT NULL COMMENT 'Additive billing usage-record count.'
) USING DELTA
PARTITIONED BY (usage_date)
COMMENT 'Daily Genie LLM token DBU and USD cost with conformed workspace and principal keys. Grain: workspace, principal, surface, channel, agent, offering, tier, SKU, and day.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_token_usage_daily')
SELECT
  CAST(workspace_id AS BIGINT),
  CASE WHEN user_email IS NOT NULL THEN sha2(lower(trim(user_email)), 256) END,
  genie_surface,
  genie_channel,
  agent_id,
  space_name,
  genie_offering,
  tier,
  sku_name,
  cloud_region,
  usage_date,
  CAST(token_dbus AS DECIMAL(38,6)),
  CAST(token_cost_usd AS DECIMAL(38,6)),
  CAST(usage_records AS BIGINT)
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactGenieTokenUsage')
WHERE usage_date >= date_sub(current_date(), :lookback_days);

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_dbsql_query_cost') (
  statement_id STRING NOT NULL COMMENT 'Databricks SQL statement identifier.',
  query_source_id STRING COMMENT 'Identifier of the job, dashboard, query, notebook, alert, or Genie space that issued the statement.',
  query_source_type STRING COMMENT 'Databricks source category for the statement.',
  client_application STRING COMMENT 'Client application recorded in query history.',
  executed_principal_id STRING COMMENT 'Hashed key of the principal that executed the statement.',
  warehouse_id STRING NOT NULL COMMENT 'SQL warehouse identifier.',
  workspace_id BIGINT NOT NULL COMMENT 'Workspace in which the statement executed.',
  start_time TIMESTAMP COMMENT 'Statement start timestamp.',
  end_time TIMESTAMP COMMENT 'Statement end timestamp.',
  query_date DATE COMMENT 'Statement start calendar date.',
  query_start_hour TIMESTAMP COMMENT 'Statement start hour.',
  duration_seconds DECIMAL(38,6) COMMENT 'Wall-clock statement duration in seconds.',
  query_work_duration_seconds DECIMAL(38,6) COMMENT 'Attributed query-work interval in seconds.',
  query_work_task_time_seconds DECIMAL(38,6) COMMENT 'Total query task duration used by the attribution model.',
  query_attributed_dollars DECIMAL(38,6) COMMENT 'Estimated additive USD warehouse cost attributed to this statement.',
  query_attributed_dbus DECIMAL(38,6) COMMENT 'Estimated additive warehouse DBUs attributed to this statement.',
  most_recent_billing_hour TIMESTAMP COMMENT 'Latest complete billing hour included by the attribution model.',
  has_billing_record BOOLEAN NOT NULL COMMENT 'True when the warehouse-hour billing record was available.'
) USING DELTA
PARTITIONED BY (query_date)
COMMENT 'Statement-grain DBSQL warehouse cost attribution fact. Grain: statement_id.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_dbsql_query_cost')
SELECT
  statement_id,
  query_source_id,
  query_source_type,
  client_application,
  CASE WHEN executed_by IS NOT NULL THEN sha2(lower(trim(executed_by)), 256) END AS executed_principal_id,
  warehouse_id,
  CAST(workspace_id AS BIGINT) AS workspace_id,
  start_time,
  end_time,
  CAST(start_time AS DATE) AS query_date,
  query_start_hour,
  CAST(COALESCE(duration_seconds, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(query_work_duration_seconds, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(query_work_task_time_seconds, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(query_attributed_dollars_estimation, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(query_attributed_dbus_estimation, 0) AS DECIMAL(38,6)),
  most_recent_billing_hour,
  billing_record_check = 'Has Billing Record'
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dbsql_cost_per_query_table')
WHERE start_time >= date_sub(current_date(), :lookback_days);

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message_cost') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace containing the Genie message.',
  space_id STRING NOT NULL COMMENT 'Genie space identifier.',
  conversation_id STRING NOT NULL COMMENT 'Genie conversation identifier.',
  message_id STRING NOT NULL COMMENT 'Genie message identifier.',
  activity_date DATE COMMENT 'Message creation calendar date.',
  principal_id STRING COMMENT 'Hashed identity of the user asking the question.',
  feedback_rating STRING COMMENT 'POSITIVE, NEGATIVE, or NONE.',
  statement_count BIGINT NOT NULL COMMENT 'Number of SQL statements attached to the message.',
  statements_missing_cost BIGINT NOT NULL COMMENT 'Statements not yet present in complete query-cost history.',
  warehouse_cost_usd DECIMAL(38,6) NOT NULL COMMENT 'Additive attributed SQL warehouse cost for all message statements.',
  warehouse_dbus DECIMAL(38,6) NOT NULL COMMENT 'Additive attributed SQL warehouse DBUs for all message statements.'
) USING DELTA
PARTITIONED BY (activity_date)
COMMENT 'Per-question Genie SQL warehouse-cost fact. Grain: workspace_id plus message_id. This is the API-covered conversational subset, not total space cost.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message_cost')
SELECT
  m.workspace_id,
  c.space_id,
  c.conversation_id,
  c.message_id,
  CAST(c.created_datetime AS DATE) AS activity_date,
  CASE WHEN c.user_email IS NOT NULL THEN sha2(lower(trim(c.user_email)), 256) END AS principal_id,
  c.feedback_rating,
  CAST(c.num_statements AS BIGINT),
  CAST(c.num_statements_missing_cost AS BIGINT),
  CAST(c.message_cost_usd AS DECIMAL(38,6)),
  CAST(c.message_dbus AS DECIMAL(38,6))
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.genie_cost_per_message_table') c
JOIN IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message') m
  ON m.space_id = c.space_id
  AND m.conversation_id = c.conversation_id
  AND m.message_id = c.message_id;

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_query_cost_category') (
  statement_id STRING NOT NULL COMMENT 'Databricks SQL statement identifier.',
  workspace_id BIGINT NOT NULL COMMENT 'Workspace in which the statement executed.',
  space_id STRING NOT NULL COMMENT 'Genie space identifier carried in query_source_id.',
  warehouse_id STRING NOT NULL COMMENT 'SQL warehouse identifier.',
  principal_id STRING COMMENT 'Hashed identity that executed the statement.',
  activity_at TIMESTAMP COMMENT 'Statement start timestamp.',
  activity_date DATE COMMENT 'Statement start calendar date.',
  cost_category STRING NOT NULL COMMENT 'CONVERSATIONAL, AUTHORING_PROFILING, SCHEMA_PROBE, METADATA_OTHER, or OTHER_UNATTRIBUTED.',
  cost_class STRING NOT NULL COMMENT 'USAGE, AUTHORING, or OVERHEAD_OR_UNATTRIBUTED.',
  statement_count BIGINT NOT NULL COMMENT 'Additive SQL statement counter; always 1.',
  warehouse_cost_usd DECIMAL(38,6) NOT NULL COMMENT 'Additive estimated SQL warehouse cost.',
  warehouse_dbus DECIMAL(38,6) NOT NULL COMMENT 'Additive estimated SQL warehouse DBUs.',
  query_work_seconds DECIMAL(38,6) NOT NULL COMMENT 'Additive query task-work duration in seconds.'
) USING DELTA
PARTITIONED BY (activity_date)
COMMENT 'Materialized classification of Genie SQL warehouse cost. Grain: statement_id.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_query_cost_category')
SELECT
  statement_id,
  CAST(workspace_id AS BIGINT),
  query_source_id,
  warehouse_id,
  CASE WHEN executed_by IS NOT NULL THEN sha2(lower(trim(executed_by)), 256) END,
  start_time,
  CAST(start_time AS DATE),
  genie_cost_category,
  genie_cost_class,
  CAST(1 AS BIGINT),
  CAST(COALESCE(query_attributed_dollars_estimation, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(query_attributed_dbus_estimation, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(query_work_task_time_seconds, 0) AS DECIMAL(38,6))
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.genie_cost_categorised')
WHERE start_time >= date_sub(current_date(), :lookback_days);
