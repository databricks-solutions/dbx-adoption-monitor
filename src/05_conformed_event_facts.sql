-- Re-aggregation-safe event facts. Each row represents one source event or one
-- Genie user question, so distinct-user measures remain correct at any time grain.

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_dashboard_view_event') (
  dashboard_view_event_id STRING NOT NULL COMMENT 'Deterministic event key derived from the audit request.',
  workspace_id BIGINT NOT NULL COMMENT 'Workspace in which the dashboard was viewed.',
  dashboard_id STRING NOT NULL COMMENT 'Viewed dashboard identifier.',
  principal_id STRING COMMENT 'Hashed viewer identity key.',
  viewed_at TIMESTAMP NOT NULL COMMENT 'Audit event timestamp.',
  viewed_date DATE NOT NULL COMMENT 'Audit event calendar date.',
  view_type STRING NOT NULL COMMENT 'DRAFT or PUBLISHED dashboard view.',
  view_count BIGINT NOT NULL COMMENT 'Additive event counter; always 1.'
) USING DELTA
PARTITIONED BY (viewed_date)
COMMENT 'Atomic AI/BI dashboard view events from system.access.audit. Grain: one audit request.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_dashboard_view_event')
SELECT DISTINCT
  sha2(concat_ws(
    '|',
    CAST(a.workspace_id AS STRING),
    COALESCE(a.request_id, ''),
    CAST(a.event_time AS STRING),
    a.action_name,
    a.request_params['dashboard_id'],
    COALESCE(lower(trim(a.user_identity.email)), '')
  ), 256) AS dashboard_view_event_id,
  CAST(a.workspace_id AS BIGINT) AS workspace_id,
  a.request_params['dashboard_id'] AS dashboard_id,
  CASE
    WHEN a.user_identity.email IS NOT NULL THEN sha2(lower(trim(a.user_identity.email)), 256)
  END AS principal_id,
  a.event_time AS viewed_at,
  a.event_date AS viewed_date,
  CASE WHEN a.action_name = 'getPublishedDashboard' THEN 'PUBLISHED' ELSE 'DRAFT' END AS view_type,
  CAST(1 AS BIGINT) AS view_count
FROM system.access.audit a
WHERE a.service_name = 'dashboards'
  AND a.action_name IN ('getDashboard', 'getPublishedDashboard')
  AND a.request_params['dashboard_id'] IS NOT NULL
  AND a.event_time >= date_sub(current_date(), :lookback_days);

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_access_event') (
  genie_access_event_id STRING NOT NULL COMMENT 'Deterministic event key derived from the audit request.',
  workspace_id BIGINT NOT NULL COMMENT 'Workspace in which the Genie action occurred.',
  space_id STRING NOT NULL COMMENT 'Genie space identifier.',
  principal_id STRING COMMENT 'Hashed actor identity key.',
  activity_at TIMESTAMP NOT NULL COMMENT 'Audit event timestamp.',
  activity_date DATE NOT NULL COMMENT 'Audit event calendar date.',
  action_type STRING NOT NULL COMMENT 'OPEN or CREATE Genie-space action.',
  open_count BIGINT NOT NULL COMMENT 'Additive space-open counter.',
  create_count BIGINT NOT NULL COMMENT 'Additive space-create counter.'
) USING DELTA
PARTITIONED BY (activity_date)
COMMENT 'Atomic Genie reach events from system.access.audit. Grain: one audit request.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_access_event')
SELECT DISTINCT
  sha2(concat_ws(
    '|',
    CAST(a.workspace_id AS STRING),
    COALESCE(a.request_id, ''),
    CAST(a.event_time AS STRING),
    a.action_name,
    a.request_params['space_id'],
    COALESCE(lower(trim(a.user_identity.email)), '')
  ), 256) AS genie_access_event_id,
  CAST(a.workspace_id AS BIGINT) AS workspace_id,
  a.request_params['space_id'] AS space_id,
  CASE
    WHEN a.user_identity.email IS NOT NULL THEN sha2(lower(trim(a.user_identity.email)), 256)
  END AS principal_id,
  a.event_time AS activity_at,
  a.event_date AS activity_date,
  CASE WHEN a.action_name = 'genieCreateSpace' THEN 'CREATE' ELSE 'OPEN' END AS action_type,
  CAST(a.action_name IN ('getSpace', 'genieGetSpace') AS BIGINT) AS open_count,
  CAST(a.action_name = 'genieCreateSpace' AS BIGINT) AS create_count
FROM system.access.audit a
WHERE a.service_name = 'aibiGenie'
  AND a.action_name IN ('getSpace', 'genieGetSpace', 'genieCreateSpace')
  AND a.request_params['space_id'] IS NOT NULL
  AND a.event_time >= date_sub(current_date(), :lookback_days);

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_activity_event') (
  app_activity_event_id STRING NOT NULL COMMENT 'Deterministic event key derived from the audit request.',
  workspace_id BIGINT NOT NULL COMMENT 'Workspace in which the app action occurred.',
  app_id STRING NOT NULL COMMENT 'Resolved app identifier; __AUDIT_NAME__ hash fallback is used when the name is absent or ambiguous.',
  app_name STRING NOT NULL COMMENT 'App name carried by the audit request.',
  principal_id STRING COMMENT 'Hashed actor identity key.',
  activity_at TIMESTAMP NOT NULL COMMENT 'Audit event timestamp.',
  activity_date DATE NOT NULL COMMENT 'Audit event calendar date.',
  action_name STRING NOT NULL COMMENT 'Apps audit action such as deployApplication, startApp, or stopApp.',
  lifecycle_event_count BIGINT NOT NULL COMMENT 'Additive app lifecycle-event counter; always 1.'
) USING DELTA
PARTITIONED BY (activity_date)
COMMENT 'Atomic Databricks Apps lifecycle events from system.access.audit. Grain: one audit request.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_activity_event')
WITH audit_events AS (
  SELECT
    a.*,
    COALESCE(
      a.request_params['name'],
      a.request_params['app_name'],
      get_json_object(a.request_params['app'], '$.name')
    ) AS app_name
  FROM system.access.audit a
  WHERE a.service_name = 'apps'
    AND a.event_time >= date_sub(current_date(), :lookback_days)
),
app_lookup AS (
  SELECT workspace_id, app_name, MAX(app_id) AS app_id
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_app')
  WHERE app_id NOT LIKE '__AUDIT_NAME__:%'
  GROUP BY workspace_id, app_name
  HAVING COUNT(DISTINCT app_id) = 1
)
SELECT DISTINCT
  sha2(concat_ws(
    '|',
    CAST(a.workspace_id AS STRING),
    COALESCE(a.request_id, ''),
    CAST(a.event_time AS STRING),
    a.action_name,
    a.app_name,
    COALESCE(lower(trim(a.user_identity.email)), '')
  ), 256) AS app_activity_event_id,
  CAST(a.workspace_id AS BIGINT) AS workspace_id,
  COALESCE(
    d.app_id,
    concat('__AUDIT_NAME__:', sha2(lower(trim(a.app_name)), 256))
  ) AS app_id,
  a.app_name,
  CASE
    WHEN a.user_identity.email IS NOT NULL THEN sha2(lower(trim(a.user_identity.email)), 256)
  END AS principal_id,
  a.event_time AS activity_at,
  a.event_date AS activity_date,
  a.action_name,
  CAST(1 AS BIGINT) AS lifecycle_event_count
FROM audit_events a
LEFT JOIN app_lookup d
  ON d.workspace_id = CAST(a.workspace_id AS BIGINT)
  AND d.app_name = a.app_name
WHERE a.app_name IS NOT NULL;

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace containing the Genie message.',
  space_id STRING NOT NULL COMMENT 'Genie space identifier.',
  conversation_id STRING NOT NULL COMMENT 'Genie conversation identifier.',
  message_id STRING NOT NULL COMMENT 'Genie message identifier.',
  principal_id STRING COMMENT 'Hashed identity of the user asking the question.',
  created_at TIMESTAMP COMMENT 'Message creation timestamp.',
  activity_date DATE COMMENT 'Message creation calendar date.',
  status STRING COMMENT 'Terminal or current Genie message status.',
  feedback_rating STRING NOT NULL COMMENT 'POSITIVE, NEGATIVE, or NONE.',
  question_count BIGINT NOT NULL COMMENT 'Additive user-question counter; always 1.',
  completed_question_count BIGINT NOT NULL COMMENT 'Additive completed-question counter.',
  positive_feedback_count BIGINT NOT NULL COMMENT 'Additive positive-feedback counter.',
  negative_feedback_count BIGINT NOT NULL COMMENT 'Additive negative-feedback counter.',
  statement_count BIGINT NOT NULL COMMENT 'Number of SQL statements attached to the message.',
  comment_count BIGINT NOT NULL COMMENT 'Number of feedback comments attached to the message.',
  attachment_count BIGINT NOT NULL COMMENT 'Number of Genie response attachments.',
  has_error BOOLEAN NOT NULL COMMENT 'True when the Genie response carries an error.'
) USING DELTA
PARTITIONED BY (activity_date)
COMMENT 'Atomic Genie question and feedback fact. Grain: workspace_id plus message_id. Raw question and response text are intentionally excluded.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message')
WITH ctx AS (
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.model_deployment_context')
),
statement_counts AS (
  SELECT message_id, COUNT(*) AS statement_count
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_genie_message_statements')
  GROUP BY message_id
),
comment_counts AS (
  SELECT message_id, COUNT(*) AS comment_count
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_genie_message_comments')
  GROUP BY message_id
)
SELECT
  ctx.workspace_id,
  m.space_id,
  m.conversation_id,
  m.message_id,
  CASE WHEN m.user_email IS NOT NULL THEN sha2(lower(trim(m.user_email)), 256) END AS principal_id,
  m.created_timestamp AS created_at,
  CAST(m.created_timestamp AS DATE) AS activity_date,
  CAST(m.status AS STRING) AS status,
  COALESCE(CAST(m.feedback_rating AS STRING), 'NONE') AS feedback_rating,
  CAST(1 AS BIGINT) AS question_count,
  CAST(COALESCE(CAST(m.status AS STRING), '') = 'COMPLETED' AS BIGINT) AS completed_question_count,
  CAST(COALESCE(CAST(m.feedback_rating AS STRING), 'NONE') = 'POSITIVE' AS BIGINT) AS positive_feedback_count,
  CAST(COALESCE(CAST(m.feedback_rating AS STRING), 'NONE') = 'NEGATIVE' AS BIGINT) AS negative_feedback_count,
  CAST(COALESCE(s.statement_count, m.num_statements, 0) AS BIGINT) AS statement_count,
  CAST(COALESCE(c.comment_count, 0) AS BIGINT) AS comment_count,
  CAST(COALESCE(m.num_attachments, 0) AS BIGINT) AS attachment_count,
  CAST(
    m.error_type IS NOT NULL
    OR m.error_message IS NOT NULL
    OR upper(COALESCE(CAST(m.status AS STRING), '')) IN ('FAILED', 'ERROR')
    AS BOOLEAN
  ) AS has_error
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_genie_messages') m
CROSS JOIN ctx
LEFT JOIN statement_counts s ON s.message_id = m.message_id
LEFT JOIN comment_counts c ON c.message_id = m.message_id
WHERE m.space_id IS NOT NULL
  AND m.conversation_id IS NOT NULL
  AND m.message_id IS NOT NULL
  AND m.created_timestamp >= date_sub(current_date(), :lookback_days);

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.bridge_genie_message_statement') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace containing the Genie message.',
  space_id STRING NOT NULL COMMENT 'Genie space identifier.',
  conversation_id STRING NOT NULL COMMENT 'Genie conversation identifier.',
  message_id STRING NOT NULL COMMENT 'Genie message identifier.',
  statement_id STRING NOT NULL COMMENT 'SQL statement identifier from the Genie attachment.',
  attachment_id STRING COMMENT 'Genie attachment identifier.',
  attachment_index INT COMMENT 'Attachment ordinal within the message.',
  principal_id STRING COMMENT 'Hashed identity of the user asking the question.',
  created_at TIMESTAMP COMMENT 'Message creation timestamp.'
) USING DELTA
COMMENT 'Normalized Genie message-to-SQL-statement bridge. Grain: workspace_id plus message_id plus statement_id.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.bridge_genie_message_statement')
SELECT
  ctx.workspace_id,
  s.space_id,
  s.conversation_id,
  s.message_id,
  s.statement_id,
  s.attachment_id,
  s.attachment_index,
  CASE WHEN s.user_email IS NOT NULL THEN sha2(lower(trim(s.user_email)), 256) END AS principal_id,
  s.created_timestamp AS created_at
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_genie_message_statements') s
CROSS JOIN IDENTIFIER(:catalog_name || '.' || :schema_name || '.model_deployment_context') ctx
WHERE s.space_id IS NOT NULL
  AND s.message_id IS NOT NULL
  AND s.statement_id IS NOT NULL
  AND s.created_timestamp >= date_sub(current_date(), :lookback_days);

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_authentication_event') (
  app_authentication_event_id STRING NOT NULL COMMENT 'Deterministic event key derived from the audit request.',
  workspace_id BIGINT NOT NULL COMMENT 'Workspace in which the app authentication occurred.',
  principal_id STRING COMMENT 'Hashed authenticated identity key.',
  activity_at TIMESTAMP NOT NULL COMMENT 'Audit event timestamp.',
  activity_date DATE NOT NULL COMMENT 'Audit event calendar date.',
  action_name STRING NOT NULL COMMENT 'OAuth audit action used by Databricks Apps authentication.',
  authentication_event_count BIGINT NOT NULL COMMENT 'Additive successful authentication-event counter; always 1.'
) USING DELTA
PARTITIONED BY (activity_date)
COMMENT 'Atomic successful Databricks Apps OAuth authentication events. Grain: one audit request.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_authentication_event')
SELECT DISTINCT
  sha2(concat_ws(
    '|',
    CAST(a.workspace_id AS STRING),
    COALESCE(a.request_id, ''),
    CAST(a.event_time AS STRING),
    a.action_name,
    COALESCE(lower(trim(a.user_identity.email)), '')
  ), 256),
  CAST(a.workspace_id AS BIGINT),
  CASE WHEN a.user_identity.email IS NOT NULL THEN sha2(lower(trim(a.user_identity.email)), 256) END,
  a.event_time,
  a.event_date,
  a.action_name,
  CAST(1 AS BIGINT)
FROM system.access.audit a
WHERE a.action_name IN (
    'workspaceInHouseOAuthClientAuthentication',
    'mintOAuthToken',
    'mintOAuthAuthorizationCode'
  )
  AND COALESCE(a.request_params['client_id'], '') <> 'databricks-cli'
  AND a.response.status_code = 200
  AND a.event_time >= date_sub(current_date(), :lookback_days);

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_permission_change_event') (
  app_permission_event_id STRING NOT NULL COMMENT 'Deterministic key for one grantee entry in an app ACL change request.',
  workspace_id BIGINT NOT NULL COMMENT 'Workspace in which the app permission changed.',
  app_id STRING NOT NULL COMMENT 'App object identifier or name from the ACL request.',
  actor_principal_id STRING COMMENT 'Hashed identity that changed the ACL.',
  grantee_principal_id STRING NOT NULL COMMENT 'Hashed user or group grantee identifier.',
  grantee_type STRING NOT NULL COMMENT 'USER or GROUP ACL grantee type.',
  activity_at TIMESTAMP NOT NULL COMMENT 'Audit event timestamp.',
  activity_date DATE NOT NULL COMMENT 'Audit event calendar date.',
  permission_level STRING NOT NULL COMMENT 'Permission level present in the submitted app ACL.',
  permission_change_count BIGINT NOT NULL COMMENT 'Additive ACL-entry change counter; always 1.'
) USING DELTA
PARTITIONED BY (activity_date)
COMMENT 'Atomic Databricks Apps ACL changes exploded to one row per grantee entry. Grain: one audit request plus grantee.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_permission_change_event')
SELECT DISTINCT
  sha2(concat_ws(
    '|',
    CAST(a.workspace_id AS STRING),
    COALESCE(a.request_id, ''),
    COALESCE(a.request_params['request_object_id'], ''),
    COALESCE(acl_entry.user_name, acl_entry.group_name, ''),
    COALESCE(acl_entry.permission_level, '')
  ), 256),
  CAST(a.workspace_id AS BIGINT),
  a.request_params['request_object_id'],
  CASE WHEN a.user_identity.email IS NOT NULL THEN sha2(lower(trim(a.user_identity.email)), 256) END,
  sha2(lower(trim(COALESCE(acl_entry.user_name, acl_entry.group_name))), 256),
  CASE WHEN acl_entry.user_name IS NOT NULL THEN 'USER' ELSE 'GROUP' END,
  a.event_time,
  a.event_date,
  acl_entry.permission_level,
  CAST(1 AS BIGINT)
FROM system.access.audit a
LATERAL VIEW explode(
  from_json(
    a.request_params['access_control_list'],
    'array<struct<user_name:string,permission_level:string,group_name:string>>'
  )
) exploded AS acl_entry
WHERE a.action_name = 'changeAppsAcl'
  AND a.request_params['request_object_type'] = 'apps'
  AND a.request_params['request_object_id'] IS NOT NULL
  AND COALESCE(acl_entry.user_name, acl_entry.group_name) IS NOT NULL
  AND acl_entry.permission_level IS NOT NULL
  AND a.event_time >= date_sub(current_date(), :lookback_days);

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_feedback_comment') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace containing the Genie feedback comment.',
  message_comment_id STRING NOT NULL COMMENT 'Genie message comment identifier.',
  space_id STRING NOT NULL COMMENT 'Genie space identifier.',
  conversation_id STRING NOT NULL COMMENT 'Genie conversation identifier.',
  message_id STRING NOT NULL COMMENT 'Genie message identifier.',
  author_id STRING COMMENT 'Comment author identifier returned by the Genie API.',
  comment_text STRING NOT NULL COMMENT 'Free-text feedback comment; may contain sensitive user-provided content.',
  created_at TIMESTAMP COMMENT 'Comment creation timestamp.',
  activity_date DATE COMMENT 'Comment creation calendar date.',
  comment_count BIGINT NOT NULL COMMENT 'Additive feedback-comment counter; always 1.'
) USING DELTA
PARTITIONED BY (activity_date)
COMMENT 'Atomic Genie feedback comments. Grain: workspace_id plus message_comment_id. Access should be restricted because comment_text is user-provided.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_feedback_comment')
SELECT
  ctx.workspace_id,
  c.message_comment_id,
  c.space_id,
  c.conversation_id,
  c.message_id,
  CAST(c.user_id AS STRING),
  c.comment_text,
  c.created_timestamp,
  CAST(c.created_timestamp AS DATE),
  CAST(1 AS BIGINT)
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.adb_genie_message_comments') c
CROSS JOIN IDENTIFIER(:catalog_name || '.' || :schema_name || '.model_deployment_context') ctx
WHERE c.message_comment_id IS NOT NULL
  AND c.space_id IS NOT NULL
  AND c.conversation_id IS NOT NULL
  AND c.message_id IS NOT NULL
  AND c.comment_text IS NOT NULL
  AND c.created_timestamp >= date_sub(current_date(), :lookback_days);
