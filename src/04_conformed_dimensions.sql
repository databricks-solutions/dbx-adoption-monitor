-- Conformed Type 1 dimensions.
-- API-derived natural keys are always scoped by workspace_id. Existing adb_* tables
-- remain untouched and continue to serve the legacy dashboard contract.

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_workspace') (
  workspace_id BIGINT NOT NULL COMMENT 'Databricks workspace identifier.',
  workspace_name STRING COMMENT 'Current workspace display name.',
  workspace_url STRING COMMENT 'Workspace URL when this is the deployment workspace.',
  is_deployment_workspace BOOLEAN NOT NULL COMMENT 'True for the workspace running this bundle.',
  updated_at TIMESTAMP NOT NULL COMMENT 'Time this Type 1 row was refreshed.'
) USING DELTA
COMMENT 'Current-state workspace dimension. Natural key: workspace_id.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_workspace')
WITH ctx AS (
  SELECT workspace_id, workspace_url
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.model_deployment_context')
),
workspace_rows AS (
  SELECT
    CAST(w.workspace_id AS BIGINT) AS workspace_id,
    w.workspace_name,
    CASE WHEN CAST(w.workspace_id AS BIGINT) = ctx.workspace_id THEN ctx.workspace_url END AS workspace_url,
    CAST(CAST(w.workspace_id AS BIGINT) = ctx.workspace_id AS BOOLEAN) AS is_deployment_workspace
  FROM system.access.workspaces_latest w
  CROSS JOIN ctx
  UNION ALL
  SELECT ctx.workspace_id, NULL, ctx.workspace_url, TRUE
  FROM ctx
  WHERE NOT EXISTS (
    SELECT 1
    FROM system.access.workspaces_latest w
    WHERE CAST(w.workspace_id AS BIGINT) = ctx.workspace_id
  )
  UNION ALL
  SELECT workspace_id, concat('Workspace ', workspace_id), NULL, FALSE
  FROM (
    SELECT CAST(workspace_id AS BIGINT) AS workspace_id
    FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactAppUsage')
    UNION
    SELECT CAST(workspace_id AS BIGINT)
    FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactServingUsage')
    UNION
    SELECT CAST(workspace_id AS BIGINT)
    FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactVectorSearchCost')
    UNION
    SELECT CAST(workspace_id AS BIGINT)
    FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactGenieTokenUsage')
    UNION
    SELECT CAST(workspace_id AS BIGINT)
    FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dbsql_cost_per_query_table')
    UNION
    SELECT CAST(workspace_id AS BIGINT)
    FROM system.access.audit
    WHERE event_time >= date_sub(current_date(), :lookback_days)
  )
  WHERE workspace_id IS NOT NULL
)
SELECT
  workspace_id,
  MAX_BY(
    workspace_name,
    CASE
      WHEN workspace_url IS NOT NULL THEN 3
      WHEN workspace_name NOT LIKE 'Workspace %' THEN 2
      ELSE 1
    END
  ),
  MAX(workspace_url),
  BOOL_OR(is_deployment_workspace),
  current_timestamp()
FROM workspace_rows
GROUP BY workspace_id;

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_date') (
  date_day DATE NOT NULL COMMENT 'Calendar date.',
  date_week DATE NOT NULL COMMENT 'Monday-starting calendar week.',
  date_month DATE NOT NULL COMMENT 'First day of the calendar month.',
  date_quarter DATE NOT NULL COMMENT 'First day of the calendar quarter.',
  date_year INT NOT NULL COMMENT 'Calendar year number.',
  month_name STRING NOT NULL COMMENT 'Full calendar month name.',
  day_of_week INT NOT NULL COMMENT 'ISO day of week where Monday is 1 and Sunday is 7.',
  is_weekend BOOLEAN NOT NULL COMMENT 'True for Saturday or Sunday.'
) USING DELTA
COMMENT 'Calendar dimension covering the configured lookback window through today. Natural key: date_day.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_date')
SELECT
  d AS date_day,
  CAST(date_trunc('WEEK', d) AS DATE) AS date_week,
  CAST(date_trunc('MONTH', d) AS DATE) AS date_month,
  CAST(date_trunc('QUARTER', d) AS DATE) AS date_quarter,
  year(d) AS date_year,
  date_format(d, 'MMMM') AS month_name,
  weekday(d) + 1 AS day_of_week,
  weekday(d) >= 5 AS is_weekend
FROM (
  SELECT explode(sequence(date_sub(current_date(), :lookback_days), current_date(), INTERVAL 1 DAY)) AS d
);

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_principal') (
  principal_id STRING NOT NULL COMMENT 'Stable SHA-256 key derived from the normalized principal email or name.',
  principal_email STRING NOT NULL COMMENT 'Raw principal email or service-principal name. Treat as personal data.',
  principal_email_masked STRING NOT NULL COMMENT 'Masked identity suitable for broadly shared dashboard views.',
  principal_domain STRING COMMENT 'Email domain when the principal is an email address.',
  is_system_principal BOOLEAN NOT NULL COMMENT 'True for Databricks system identities.',
  updated_at TIMESTAMP NOT NULL COMMENT 'Time this Type 1 row was refreshed.'
) USING DELTA
COMMENT 'Current-state principal dimension assembled from audit, Genie, token, and SQL-query identities. Natural key: principal_id.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_principal')
WITH identities AS (
  SELECT user_identity.email AS principal_email
  FROM system.access.audit
  WHERE event_time >= date_sub(current_date(), :lookback_days)
  UNION
  SELECT user_email
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_genie_messages')
  UNION
  SELECT user_email
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactGenieTokenUsage')
  UNION
  SELECT executed_by
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dbsql_cost_per_query_table')
),
normalized AS (
  SELECT lower(trim(principal_email)) AS principal_email
  FROM identities
  WHERE principal_email IS NOT NULL AND trim(principal_email) <> ''
)
SELECT
  sha2(principal_email, 256) AS principal_id,
  principal_email,
  CASE
    WHEN instr(principal_email, '@') > 0
      THEN concat(substr(principal_email, 1, 2), '***@', element_at(split(principal_email, '@'), -1))
    ELSE concat(substr(principal_email, 1, 2), '***')
  END AS principal_email_masked,
  CASE WHEN instr(principal_email, '@') > 0 THEN element_at(split(principal_email, '@'), -1) END AS principal_domain,
  principal_email IN ('system-user', 'system_user') AS is_system_principal,
  current_timestamp() AS updated_at
FROM normalized
GROUP BY ALL;

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_dashboard') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace containing the dashboard.',
  dashboard_id STRING NOT NULL COMMENT 'Lakeview dashboard identifier.',
  dashboard_name STRING NOT NULL COMMENT 'Current dashboard display name or a stable fallback.',
  create_time TIMESTAMP COMMENT 'Dashboard creation time from the Lakeview API.',
  update_time TIMESTAMP COMMENT 'Most recent dashboard update time from the Lakeview API.',
  lifecycle_state STRING COMMENT 'Current dashboard lifecycle state.',
  warehouse_id STRING COMMENT 'Warehouse configured for the dashboard.',
  updated_at TIMESTAMP NOT NULL COMMENT 'Time this Type 1 row was refreshed.'
) USING DELTA
COMMENT 'Current-state AI/BI dashboard dimension. Natural key: workspace_id plus dashboard_id.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_dashboard')
WITH ctx AS (
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.model_deployment_context')
),
candidates AS (
  SELECT
    ctx.workspace_id,
    d.dashboard_id,
    d.display_name AS dashboard_name,
    d.create_time,
    d.update_time,
    d.lifecycle_state,
    d.warehouse_id,
    1 AS source_priority
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_dashboards') d
  CROSS JOIN ctx
  WHERE d.dashboard_id IS NOT NULL
  UNION ALL
  SELECT
    CAST(a.workspace_id AS BIGINT),
    a.request_params['dashboard_id'],
    concat('Dashboard ', a.request_params['dashboard_id']),
    NULL,
    NULL,
    NULL,
    NULL,
    2
  FROM system.access.audit a
  WHERE a.service_name = 'dashboards'
    AND a.request_params['dashboard_id'] IS NOT NULL
    AND a.event_time >= date_sub(current_date(), :lookback_days)
),
ranked AS (
  SELECT *, row_number() OVER (
    PARTITION BY workspace_id, dashboard_id
    ORDER BY source_priority, update_time DESC NULLS LAST
  ) AS row_num
  FROM candidates
)
SELECT workspace_id, dashboard_id, dashboard_name, create_time, update_time, lifecycle_state, warehouse_id, current_timestamp()
FROM ranked
WHERE row_num = 1;

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_app') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace containing or billing the app.',
  app_id STRING NOT NULL COMMENT 'Databricks App identifier; __AUDIT_NAME__ hash fallback is used only when an audit name cannot resolve uniquely.',
  app_name STRING NOT NULL COMMENT 'Current Databricks App display name.',
  create_time TIMESTAMP COMMENT 'App creation time from the Apps API.',
  update_time TIMESTAMP COMMENT 'Most recent Apps API update time.',
  creator_principal_id STRING COMMENT 'Hashed key of the app creator.',
  app_status STRING COMMENT 'Current app lifecycle status.',
  compute_status STRING COMMENT 'Current app compute status.',
  num_users_with_access INT COMMENT 'Current number of directly granted users.',
  num_groups_with_access INT COMMENT 'Current number of granted groups.',
  updated_at TIMESTAMP NOT NULL COMMENT 'Time this Type 1 row was refreshed.'
) USING DELTA
COMMENT 'Current-state Databricks Apps dimension. Natural key: workspace_id plus app_id.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_app')
WITH ctx AS (
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.model_deployment_context')
),
base_candidates AS (
  SELECT
    ctx.workspace_id,
    COALESCE(CAST(a.id AS STRING), a.name) AS app_id,
    a.name AS app_name,
    a.create_time,
    a.update_time,
    sha2(lower(trim(a.creator)), 256) AS creator_principal_id,
    a.app_status,
    a.compute_status,
    a.num_users_with_access,
    a.num_groups_with_access,
    1 AS source_priority
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_apps') a
  CROSS JOIN ctx
  WHERE a.name IS NOT NULL
  UNION ALL
  SELECT
    f.workspace_id,
    f.app_id,
    f.app_name,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    2
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactAppUsage') f
),
canonical_name_counts AS (
  SELECT workspace_id, app_name, COUNT(DISTINCT app_id) AS app_id_count
  FROM base_candidates
  GROUP BY ALL
),
audit_names AS (
  SELECT
    CAST(workspace_id AS BIGINT) AS workspace_id,
    COALESCE(
      request_params['name'],
      request_params['app_name'],
      get_json_object(request_params['app'], '$.name')
    ) AS app_name,
    MIN(event_time) AS first_seen_at,
    MAX(event_time) AS last_seen_at
  FROM system.access.audit
  WHERE service_name = 'apps'
    AND event_time >= date_sub(current_date(), :lookback_days)
  GROUP BY ALL
),
candidates AS (
  SELECT * FROM base_candidates
  UNION ALL
  SELECT
    a.workspace_id,
    concat('__AUDIT_NAME__:', sha2(lower(trim(a.app_name)), 256)) AS app_id,
    a.app_name,
    a.first_seen_at,
    a.last_seen_at,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    3
  FROM audit_names a
  LEFT JOIN canonical_name_counts c
    USING (workspace_id, app_name)
  WHERE a.app_name IS NOT NULL
    AND COALESCE(c.app_id_count, 0) <> 1
),
ranked AS (
  SELECT *, row_number() OVER (
    PARTITION BY workspace_id, app_id
    ORDER BY source_priority, update_time DESC NULLS LAST
  ) AS row_num
  FROM candidates
)
SELECT
  workspace_id, app_id, app_name, create_time, update_time, creator_principal_id,
  app_status, compute_status, num_users_with_access, num_groups_with_access, current_timestamp()
FROM ranked
WHERE row_num = 1;

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_genie_space') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace containing or billing the Genie space.',
  space_id STRING NOT NULL COMMENT 'Genie space identifier.',
  space_name STRING NOT NULL COMMENT 'Current Genie space name or a stable fallback.',
  description STRING COMMENT 'Current Genie space description.',
  warehouse_id STRING COMMENT 'SQL warehouse configured for the Genie space.',
  updated_at TIMESTAMP NOT NULL COMMENT 'Time this Type 1 row was refreshed.'
) USING DELTA
COMMENT 'Current-state Genie space dimension. Natural key: workspace_id plus space_id.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_genie_space')
WITH ctx AS (
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.model_deployment_context')
),
candidates AS (
  SELECT ctx.workspace_id, s.space_id, s.name AS space_name, s.description, s.warehouse_id, 1 AS source_priority
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_genie_spaces') s
  CROSS JOIN ctx
  WHERE s.space_id IS NOT NULL
  UNION ALL
  SELECT workspace_id, space_id, genie_space, NULL, NULL, 2
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactGenieUsage')
  WHERE space_id IS NOT NULL
  UNION ALL
  SELECT CAST(workspace_id AS BIGINT), agent_id, COALESCE(space_name, concat('Genie space ', agent_id)), NULL, NULL, 3
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactGenieTokenUsage')
  WHERE agent_id IS NOT NULL
  UNION ALL
  SELECT CAST(workspace_id AS BIGINT), query_source_id, concat('Genie space ', query_source_id), NULL, warehouse_id, 4
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dbsql_cost_per_query_table')
  WHERE query_source_type = 'GENIE SPACE' AND query_source_id IS NOT NULL AND query_source_id <> 'UNKNOWN'
  UNION ALL
  SELECT
    CAST(workspace_id AS BIGINT),
    request_params['space_id'],
    concat('Genie space ', request_params['space_id']),
    NULL,
    NULL,
    5
  FROM system.access.audit
  WHERE service_name = 'aibiGenie'
    AND request_params['space_id'] IS NOT NULL
    AND event_time >= date_sub(current_date(), :lookback_days)
),
ranked AS (
  SELECT *, row_number() OVER (
    PARTITION BY workspace_id, space_id
    ORDER BY source_priority, space_name
  ) AS row_num
  FROM candidates
)
SELECT workspace_id, space_id, space_name, description, warehouse_id, current_timestamp()
FROM ranked
WHERE row_num = 1;

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_genie_conversation') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace containing the conversation.',
  space_id STRING NOT NULL COMMENT 'Genie space containing the conversation.',
  conversation_id STRING NOT NULL COMMENT 'Genie conversation identifier.',
  created_timestamp TIMESTAMP COMMENT 'Conversation creation timestamp.',
  updated_at TIMESTAMP NOT NULL COMMENT 'Time this Type 1 row was refreshed.'
) USING DELTA
COMMENT 'Current-state Genie conversation detail. Natural key: workspace_id plus space_id plus conversation_id.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_genie_conversation')
SELECT
  ctx.workspace_id,
  c.space_id,
  c.conversation_id,
  c.created_timestamp,
  current_timestamp()
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_genie_conversations') c
CROSS JOIN IDENTIFIER(:catalog_name || '.' || :schema_name || '.model_deployment_context') ctx
WHERE c.space_id IS NOT NULL AND c.conversation_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_serving_endpoint') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace containing or billing the serving endpoint.',
  endpoint_id STRING NOT NULL COMMENT 'Model Serving endpoint identifier.',
  endpoint_name STRING NOT NULL COMMENT 'Current endpoint display name or stable fallback.',
  creation_timestamp TIMESTAMP COMMENT 'Endpoint creation timestamp from the Serving API.',
  last_updated_timestamp TIMESTAMP COMMENT 'Most recent Serving API update time.',
  creator_principal_id STRING COMMENT 'Hashed key of the endpoint creator.',
  endpoint_state STRING COMMENT 'Current endpoint readiness state.',
  served_entity_count INT COMMENT 'Current number of served entities represented on the endpoint.',
  num_users_with_access INT COMMENT 'Current number of directly granted users.',
  num_groups_with_access INT COMMENT 'Current number of granted groups.',
  updated_at TIMESTAMP NOT NULL COMMENT 'Time this Type 1 row was refreshed.'
) USING DELTA
COMMENT 'Current-state Model Serving endpoint dimension. Natural key: workspace_id plus endpoint_id.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_serving_endpoint')
WITH ctx AS (
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.model_deployment_context')
),
candidates AS (
  SELECT
    ctx.workspace_id,
    COALESCE(CAST(e.id AS STRING), e.name) AS endpoint_id,
    e.name AS endpoint_name,
    e.creation_timestamp,
    e.last_updated_timestamp,
    sha2(lower(trim(CAST(e.creator AS STRING))), 256) AS creator_principal_id,
    CAST(e.state AS STRING) AS endpoint_state,
    NULL AS served_entity_count,
    e.num_users_with_access,
    e.num_groups_with_access,
    1 AS source_priority
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_serving_endpoints') e
  CROSS JOIN ctx
  WHERE e.name IS NOT NULL
  UNION ALL
  SELECT
    f.workspace_id,
    f.endpoint_id,
    f.endpoint_name,
    NULL,
    NULL,
    NULL,
    NULL,
    MAX(f.entity_count),
    NULL,
    NULL,
    2
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactServingUsage') f
  WHERE f.endpoint_id IS NOT NULL
  GROUP BY f.workspace_id, f.endpoint_id, f.endpoint_name
),
ranked AS (
  SELECT *, row_number() OVER (
    PARTITION BY workspace_id, endpoint_id
    ORDER BY source_priority, last_updated_timestamp DESC NULLS LAST
  ) AS row_num
  FROM candidates
)
SELECT
  workspace_id, endpoint_id, endpoint_name, creation_timestamp, last_updated_timestamp,
  creator_principal_id, endpoint_state, served_entity_count, num_users_with_access,
  num_groups_with_access, current_timestamp()
FROM ranked
WHERE row_num = 1;

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_vector_search_endpoint') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace billing the Vector Search endpoint.',
  endpoint_id STRING NOT NULL COMMENT 'Vector Search endpoint identifier or __UNATTRIBUTED__ for maintenance cost.',
  endpoint_name STRING NOT NULL COMMENT 'Vector Search endpoint display name or explicit unattributed label.',
  is_attributed BOOLEAN NOT NULL COMMENT 'False when billing metadata cannot identify an endpoint.',
  updated_at TIMESTAMP NOT NULL COMMENT 'Time this Type 1 row was refreshed.'
) USING DELTA
COMMENT 'Current-state Vector Search endpoint dimension including an explicit unattributed member. Natural key: workspace_id plus endpoint_id.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_vector_search_endpoint')
SELECT
  workspace_id,
  COALESCE(endpoint_id, '__UNATTRIBUTED__') AS endpoint_id,
  MAX(endpoint_name) AS endpoint_name,
  endpoint_id IS NOT NULL AS is_attributed,
  current_timestamp()
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactVectorSearchCost')
GROUP BY workspace_id, COALESCE(endpoint_id, '__UNATTRIBUTED__'), endpoint_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_uc_model') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace that performed the model inventory crawl.',
  model_key STRING NOT NULL COMMENT 'Stable SHA-256 key for workspace_id plus full model name.',
  full_name STRING NOT NULL COMMENT 'Three-level Unity Catalog model name.',
  model_name STRING NOT NULL COMMENT 'Unqualified registered-model name.',
  catalog_name STRING COMMENT 'Unity Catalog containing the registered model.',
  schema_name STRING COMMENT 'Unity Catalog schema containing the registered model.',
  created_at TIMESTAMP COMMENT 'Registered model creation time.',
  updated_at TIMESTAMP COMMENT 'Registered model update time.',
  owner STRING COMMENT 'Current registered-model owner.',
  model_comment STRING COMMENT 'Registered-model description.',
  num_users_with_access INT COMMENT 'Current number of directly granted users.',
  num_groups_with_access INT COMMENT 'Current number of granted groups.',
  refreshed_at TIMESTAMP NOT NULL COMMENT 'Time this Type 1 row was refreshed.'
) USING DELTA
COMMENT 'Current-state Unity Catalog registered-model inventory. Natural key: workspace_id plus full_name.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_uc_model')
SELECT
  ctx.workspace_id,
  sha2(concat(CAST(ctx.workspace_id AS STRING), '|', m.full_name), 256),
  m.full_name,
  m.name,
  m.catalog_name,
  m.schema_name,
  m.created_at,
  m.updated_at,
  m.owner,
  m.comment,
  m.num_users_with_access,
  m.num_groups_with_access,
  current_timestamp()
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_models') m
CROSS JOIN IDENTIFIER(:catalog_name || '.' || :schema_name || '.model_deployment_context') ctx
WHERE m.full_name IS NOT NULL;

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_dashboard_schedule') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace containing the dashboard schedule.',
  dashboard_id STRING NOT NULL COMMENT 'Scheduled dashboard identifier.',
  schedule_id STRING NOT NULL COMMENT 'Lakeview schedule identifier.',
  create_time STRING COMMENT 'Schedule creation time as returned by the API.',
  schedule_name STRING COMMENT 'Schedule display name.',
  pause_status STRING COMMENT 'Current schedule pause status.',
  updated_at TIMESTAMP NOT NULL COMMENT 'Time this Type 1 row was refreshed.'
) USING DELTA
COMMENT 'Current-state Lakeview schedule detail. Natural key: workspace_id plus dashboard_id plus schedule_id.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_dashboard_schedule')
SELECT
  ctx.workspace_id,
  s.dashboard_id,
  s.schedule_id,
  s.create_time,
  s.display_name,
  s.pause_status,
  current_timestamp()
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_dashboard_schedules') s
CROSS JOIN IDENTIFIER(:catalog_name || '.' || :schema_name || '.model_deployment_context') ctx
WHERE s.dashboard_id IS NOT NULL AND s.schedule_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.bridge_dashboard_subscription') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace containing the subscription.',
  dashboard_id STRING NOT NULL COMMENT 'Subscribed dashboard identifier.',
  schedule_id STRING NOT NULL COMMENT 'Schedule identifier.',
  subscription_id STRING NOT NULL COMMENT 'Lakeview subscription identifier.',
  create_time TIMESTAMP COMMENT 'Subscription creation time.',
  user_id STRING COMMENT 'Subscribed user identifier when applicable.',
  destination_id STRING COMMENT 'Subscribed destination identifier when applicable.'
) USING DELTA
COMMENT 'Lakeview schedule-to-subscriber bridge. Natural key: workspace_id plus dashboard_id plus schedule_id plus subscription_id.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.bridge_dashboard_subscription')
SELECT
  ctx.workspace_id,
  s.dashboard_id,
  s.schedule_id,
  s.subscription_id,
  s.create_time,
  s.user_id,
  s.destination_id
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_dashboard_subscriptions') s
CROSS JOIN IDENTIFIER(:catalog_name || '.' || :schema_name || '.model_deployment_context') ctx
WHERE s.dashboard_id IS NOT NULL AND s.schedule_id IS NOT NULL AND s.subscription_id IS NOT NULL;
