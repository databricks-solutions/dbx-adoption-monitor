-- Cross-source daily Genie summary. Every stored measure is additive; ratios and
-- distinct-user metrics are calculated in Metric Views from atomic facts.

CREATE TABLE IF NOT EXISTS IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_daily_summary') (
  workspace_id BIGINT NOT NULL COMMENT 'Workspace containing or billing the Genie space.',
  space_id STRING NOT NULL COMMENT 'Genie space identifier.',
  activity_date DATE NOT NULL COMMENT 'Calendar date shared across reach, question, SQL-cost, and token streams.',
  space_open_count BIGINT NOT NULL COMMENT 'Additive Genie space opens from audit.',
  space_create_count BIGINT NOT NULL COMMENT 'Additive Genie space creation events from audit.',
  question_count BIGINT NOT NULL COMMENT 'Additive user questions from the Conversation API.',
  completed_question_count BIGINT NOT NULL COMMENT 'Additive completed Genie questions.',
  positive_feedback_count BIGINT NOT NULL COMMENT 'Additive positive message ratings.',
  negative_feedback_count BIGINT NOT NULL COMMENT 'Additive negative message ratings.',
  feedback_comment_count BIGINT NOT NULL COMMENT 'Additive message feedback comments.',
  message_statement_count BIGINT NOT NULL COMMENT 'Additive SQL statements attached to API-visible messages.',
  statements_missing_cost_count BIGINT NOT NULL COMMENT 'API-visible message statements not yet found in complete query-cost history.',
  message_warehouse_cost_usd DECIMAL(38,6) NOT NULL COMMENT 'Attributed warehouse cost for the API-covered conversational subset.',
  message_warehouse_dbus DECIMAL(38,6) NOT NULL COMMENT 'Attributed warehouse DBUs for the API-covered conversational subset.',
  total_space_warehouse_cost_usd DECIMAL(38,6) NOT NULL COMMENT 'Complete Genie-space warehouse cost from query history.',
  total_space_warehouse_dbus DECIMAL(38,6) NOT NULL COMMENT 'Complete Genie-space warehouse DBUs from query history.',
  conversational_warehouse_cost_usd DECIMAL(38,6) NOT NULL COMMENT 'Warehouse cost linked to API-visible Genie messages.',
  authoring_warehouse_cost_usd DECIMAL(38,6) NOT NULL COMMENT 'Warehouse cost classified as Genie authoring or profiling.',
  overhead_warehouse_cost_usd DECIMAL(38,6) NOT NULL COMMENT 'Warehouse cost classified as metadata, schema probe, or otherwise unattributed.',
  token_dbus DECIMAL(38,6) NOT NULL COMMENT 'Genie Agent token DBUs attributed directly to the space.',
  token_cost_usd DECIMAL(38,6) NOT NULL COMMENT 'Genie Agent token USD cost attributed directly to the space.',
  free_token_dbus DECIMAL(38,6) NOT NULL COMMENT 'Token DBUs recorded against the free-tier SKU.',
  paid_token_dbus DECIMAL(38,6) NOT NULL COMMENT 'Token DBUs recorded against paid SKUs.'
) USING DELTA
PARTITIONED BY (activity_date)
COMMENT 'Additive daily Genie-space summary across reach, conversation depth, SQL warehouse cost, and LLM token cost. Grain: workspace_id plus space_id plus activity_date.';

INSERT OVERWRITE IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_daily_summary')
WITH reach AS (
  SELECT
    workspace_id,
    space_id,
    activity_date,
    SUM(open_count) AS space_open_count,
    SUM(create_count) AS space_create_count
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_access_event')
  GROUP BY ALL
),
messages AS (
  SELECT
    workspace_id,
    space_id,
    activity_date,
    SUM(question_count) AS question_count,
    SUM(completed_question_count) AS completed_question_count,
    SUM(positive_feedback_count) AS positive_feedback_count,
    SUM(negative_feedback_count) AS negative_feedback_count,
    SUM(comment_count) AS feedback_comment_count,
    SUM(statement_count) AS message_statement_count
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message')
  WHERE activity_date IS NOT NULL
  GROUP BY ALL
),
message_cost AS (
  SELECT
    workspace_id,
    space_id,
    activity_date,
    SUM(statements_missing_cost) AS statements_missing_cost_count,
    SUM(warehouse_cost_usd) AS message_warehouse_cost_usd,
    SUM(warehouse_dbus) AS message_warehouse_dbus
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message_cost')
  WHERE activity_date IS NOT NULL
  GROUP BY ALL
),
warehouse_cost AS (
  SELECT
    workspace_id,
    space_id,
    activity_date,
    SUM(warehouse_cost_usd) AS total_space_warehouse_cost_usd,
    SUM(warehouse_dbus) AS total_space_warehouse_dbus,
    SUM(warehouse_cost_usd) FILTER (WHERE cost_class = 'USAGE') AS conversational_warehouse_cost_usd,
    SUM(warehouse_cost_usd) FILTER (WHERE cost_class = 'AUTHORING') AS authoring_warehouse_cost_usd,
    SUM(warehouse_cost_usd) FILTER (WHERE cost_class = 'OVERHEAD_OR_UNATTRIBUTED') AS overhead_warehouse_cost_usd
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_query_cost_category')
  WHERE activity_date IS NOT NULL
  GROUP BY ALL
),
tokens AS (
  SELECT
    CAST(workspace_id AS BIGINT) AS workspace_id,
    agent_id AS space_id,
    usage_date AS activity_date,
    SUM(token_dbus) AS token_dbus,
    SUM(token_cost_usd) AS token_cost_usd,
    SUM(token_dbus) FILTER (WHERE tier = 'FREE') AS free_token_dbus,
    SUM(token_dbus) FILTER (WHERE tier = 'PAID') AS paid_token_dbus
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_token_usage_daily')
  WHERE agent_id IS NOT NULL AND usage_date IS NOT NULL
  GROUP BY ALL
),
keys AS (
  SELECT workspace_id, space_id, current_date() AS activity_date
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_genie_space')
  UNION
  SELECT workspace_id, space_id, activity_date FROM reach
  UNION
  SELECT workspace_id, space_id, activity_date FROM messages
  UNION
  SELECT workspace_id, space_id, activity_date FROM message_cost
  UNION
  SELECT workspace_id, space_id, activity_date FROM warehouse_cost
  UNION
  SELECT workspace_id, space_id, activity_date FROM tokens
)
SELECT
  k.workspace_id,
  k.space_id,
  k.activity_date,
  COALESCE(r.space_open_count, 0),
  COALESCE(r.space_create_count, 0),
  COALESCE(m.question_count, 0),
  COALESCE(m.completed_question_count, 0),
  COALESCE(m.positive_feedback_count, 0),
  COALESCE(m.negative_feedback_count, 0),
  COALESCE(m.feedback_comment_count, 0),
  COALESCE(m.message_statement_count, 0),
  COALESCE(mc.statements_missing_cost_count, 0),
  CAST(COALESCE(mc.message_warehouse_cost_usd, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(mc.message_warehouse_dbus, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(wc.total_space_warehouse_cost_usd, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(wc.total_space_warehouse_dbus, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(wc.conversational_warehouse_cost_usd, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(wc.authoring_warehouse_cost_usd, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(wc.overhead_warehouse_cost_usd, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(t.token_dbus, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(t.token_cost_usd, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(t.free_token_dbus, 0) AS DECIMAL(38,6)),
  CAST(COALESCE(t.paid_token_dbus, 0) AS DECIMAL(38,6))
FROM keys k
LEFT JOIN reach r USING (workspace_id, space_id, activity_date)
LEFT JOIN messages m USING (workspace_id, space_id, activity_date)
LEFT JOIN message_cost mc USING (workspace_id, space_id, activity_date)
LEFT JOIN warehouse_cost wc USING (workspace_id, space_id, activity_date)
LEFT JOIN tokens t USING (workspace_id, space_id, activity_date);
