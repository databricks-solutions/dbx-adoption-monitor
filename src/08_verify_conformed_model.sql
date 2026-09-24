-- Runtime invariants for the conformed model and the one-release dual-publish contract.

WITH expected(table_name, table_type) AS (
  SELECT * FROM VALUES
    ('adb_apps', 'MANAGED'),
    ('adb_dashboard_schedules', 'MANAGED'),
    ('adb_dashboard_subscriptions', 'MANAGED'),
    ('adb_dashboards', 'MANAGED'),
    ('adb_genie_conversations', 'MANAGED'),
    ('adb_genie_message_comments', 'MANAGED'),
    ('adb_genie_message_statements', 'MANAGED'),
    ('adb_genie_messages', 'MANAGED'),
    ('adb_genie_spaces', 'MANAGED'),
    ('adb_models', 'MANAGED'),
    ('adb_serving_endpoints', 'MANAGED'),
    ('dbsql_cost_per_query_table', 'MANAGED'),
    ('genie_cost_categorised', 'VIEW'),
    ('genie_cost_per_message_table', 'MANAGED'),
    ('mvfactappusage', 'MANAGED'),
    ('mvfactdashboardusage', 'MANAGED'),
    ('mvfactgenietokenusage', 'MANAGED'),
    ('mvfactgenieusage', 'MANAGED'),
    ('mvfactservingusage', 'MANAGED'),
    ('mvfactvectorsearchcost', 'MANAGED')
)
SELECT assert_true(COUNT(*) = 0, 'All 20 legacy objects must retain their physical object types')
FROM expected e
LEFT JOIN IDENTIFIER(:catalog_name || '.information_schema.tables') a
  ON lower(a.table_name) = e.table_name
  AND a.table_schema = :schema_name
WHERE a.table_name IS NULL OR a.table_type <> e.table_type;

SELECT assert_true(COUNT(*) = 0, 'dim_workspace key must be unique')
FROM (
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_workspace')
  GROUP BY workspace_id HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'dim_dashboard key must be unique')
FROM (
  SELECT workspace_id, dashboard_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_dashboard')
  GROUP BY ALL HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'dim_app key must be unique')
FROM (
  SELECT workspace_id, app_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_app')
  GROUP BY ALL HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'dim_genie_space key must be unique')
FROM (
  SELECT workspace_id, space_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_genie_space')
  GROUP BY ALL HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'dim_serving_endpoint key must be unique')
FROM (
  SELECT workspace_id, endpoint_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_serving_endpoint')
  GROUP BY ALL HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'dim_vector_search_endpoint key must be unique')
FROM (
  SELECT workspace_id, endpoint_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_vector_search_endpoint')
  GROUP BY ALL HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'fact_dashboard_view_event key must be unique')
FROM (
  SELECT dashboard_view_event_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_dashboard_view_event')
  GROUP BY dashboard_view_event_id HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'fact_genie_space_access_event key must be unique')
FROM (
  SELECT genie_access_event_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_access_event')
  GROUP BY genie_access_event_id HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'fact_app_activity_event key must be unique')
FROM (
  SELECT app_activity_event_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_activity_event')
  GROUP BY app_activity_event_id HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'fact_app_authentication_event key must be unique')
FROM (
  SELECT app_authentication_event_id
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_authentication_event')
  GROUP BY app_authentication_event_id HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'fact_app_permission_change_event key must be unique')
FROM (
  SELECT app_permission_event_id
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_permission_change_event')
  GROUP BY app_permission_event_id HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'fact_genie_message key must be unique')
FROM (
  SELECT workspace_id, message_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message')
  GROUP BY ALL HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'fact_vector_search_daily grain must be unique')
FROM (
  SELECT workspace_id, endpoint_id, usage_date, sku_name
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_vector_search_daily')
  GROUP BY ALL HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'fact_genie_token_usage_daily grain must be unique')
FROM (
  SELECT
    workspace_id, principal_id, genie_surface, genie_channel, agent_id,
    genie_offering, tier, sku_name, usage_date
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_token_usage_daily')
  GROUP BY ALL HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'fact_app_daily grain must be unique')
FROM (
  SELECT workspace_id, app_id, usage_date
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_daily')
  GROUP BY ALL HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'fact_serving_endpoint_daily grain must be unique')
FROM (
  SELECT workspace_id, endpoint_id, usage_date
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_serving_endpoint_daily')
  GROUP BY ALL HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'statement-grain cost facts must be unique')
FROM (
  SELECT statement_id
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_dbsql_query_cost')
  GROUP BY statement_id HAVING COUNT(*) > 1
  UNION ALL
  SELECT statement_id
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_query_cost_category')
  GROUP BY statement_id HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'fact_genie_message_cost grain must be unique')
FROM (
  SELECT workspace_id, message_id
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message_cost')
  GROUP BY ALL HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'fact_genie_space_daily_summary grain must be unique')
FROM (
  SELECT workspace_id, space_id, activity_date
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_daily_summary')
  GROUP BY ALL HAVING COUNT(*) > 1
);

SELECT assert_true(COUNT(*) = 0, 'dashboard events must resolve to dim_dashboard')
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_dashboard_view_event') f
LEFT JOIN IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_dashboard') d
  USING (workspace_id, dashboard_id)
WHERE d.dashboard_id IS NULL;

SELECT assert_true(COUNT(*) = 0, 'Genie access events must resolve to dim_genie_space')
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_access_event') f
LEFT JOIN IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_genie_space') d
  USING (workspace_id, space_id)
WHERE d.space_id IS NULL;

SELECT assert_true(COUNT(*) = 0, 'app activity events must resolve to dim_app')
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_activity_event') f
LEFT JOIN IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_app') d
  USING (workspace_id, app_id)
WHERE d.app_id IS NULL;

SELECT assert_true(COUNT(*) = 0, 'all conformed fact workspace keys must resolve')
FROM (
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_dashboard_view_event')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_access_event')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_activity_event')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_authentication_event')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_permission_change_event')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_feedback_comment')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.bridge_genie_message_statement')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_daily')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_serving_endpoint_daily')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_vector_search_daily')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_token_usage_daily')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_dbsql_query_cost')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message_cost')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_query_cost_category')
  UNION
  SELECT workspace_id FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_daily_summary')
) f
LEFT JOIN IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_workspace') d
  USING (workspace_id)
WHERE d.workspace_id IS NULL;

SELECT assert_true(COUNT(*) = 0, 'all populated fact dates must resolve to dim_date')
FROM (
  SELECT viewed_date AS date_key FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_dashboard_view_event')
  UNION
  SELECT activity_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_activity_event')
  UNION
  SELECT activity_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_authentication_event')
  UNION
  SELECT activity_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_permission_change_event')
  UNION
  SELECT activity_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_access_event')
  UNION
  SELECT activity_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message')
  UNION
  SELECT activity_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_feedback_comment')
  UNION
  SELECT usage_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_daily')
  UNION
  SELECT usage_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_serving_endpoint_daily')
  UNION
  SELECT usage_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_vector_search_daily')
  UNION
  SELECT usage_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_token_usage_daily')
  UNION
  SELECT query_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_dbsql_query_cost')
  UNION
  SELECT activity_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message_cost')
  UNION
  SELECT activity_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_query_cost_category')
  UNION
  SELECT activity_date FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_daily_summary')
) f
LEFT JOIN IDENTIFIER(:catalog_name || '.' || :schema_name || '.dim_date') d
  ON f.date_key = d.date_day
WHERE f.date_key IS NOT NULL AND d.date_day IS NULL;

SELECT assert_true(COUNT(*) = 0, 'conformed measures must be non-negative')
FROM (
  SELECT dbus AS dbus, dollars AS dollars
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_daily')
  UNION ALL
  SELECT dbus, dollars
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_serving_endpoint_daily')
  UNION ALL
  SELECT dbus, dollars
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_vector_search_daily')
)
WHERE COALESCE(dbus, -1) < 0 OR COALESCE(dollars, -1) < 0;

SELECT assert_true(COUNT(*) = 0, 'Genie and DBSQL cost measures must be non-negative and non-null')
FROM (
  SELECT token_dbus AS dbus, token_cost_usd AS dollars
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_token_usage_daily')
  UNION ALL
  SELECT query_attributed_dbus, query_attributed_dollars
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_dbsql_query_cost')
  UNION ALL
  SELECT warehouse_dbus, warehouse_cost_usd
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message_cost')
  UNION ALL
  SELECT warehouse_dbus, warehouse_cost_usd
  FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_query_cost_category')
)
WHERE COALESCE(dbus, -1) < 0 OR COALESCE(dollars, -1) < 0;

SELECT assert_true(
  ABS(
    (SELECT COALESCE(SUM(dollars), 0) FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_app_daily'))
    -
    (SELECT COALESCE(SUM(dollars), 0) FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactAppUsage'))
  ) < 0.01,
  'fact_app_daily dollars must reconcile to legacy mvFactAppUsage'
);

SELECT assert_true(
  ABS(
    (SELECT COALESCE(SUM(dollars), 0) FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_serving_endpoint_daily'))
    -
    (SELECT COALESCE(SUM(dollars), 0) FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactServingUsage'))
  ) < 0.01,
  'fact_serving_endpoint_daily dollars must reconcile to legacy mvFactServingUsage'
);

SELECT assert_true(
  ABS(
    (SELECT COALESCE(SUM(dollars), 0) FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_vector_search_daily'))
    -
    (SELECT COALESCE(SUM(dollars), 0) FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactVectorSearchCost'))
  ) < 0.01,
  'fact_vector_search_daily dollars must reconcile to legacy mvFactVectorSearchCost'
);

SELECT assert_true(
  ABS(
    (SELECT COALESCE(SUM(token_cost_usd), 0)
     FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_token_usage_daily'))
    -
    (SELECT COALESCE(SUM(CAST(token_cost_usd AS DECIMAL(38,6))), 0)
     FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.mvFactGenieTokenUsage')
     WHERE usage_date >= date_sub(current_date(), :lookback_days))
  ) < 0.01,
  'fact_genie_token_usage_daily cost must reconcile to legacy mvFactGenieTokenUsage'
);

SELECT assert_true(
  ABS(
    (SELECT COALESCE(SUM(total_space_warehouse_cost_usd), 0)
     FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_daily_summary'))
    -
    (SELECT COALESCE(SUM(warehouse_cost_usd), 0)
     FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_query_cost_category'))
  ) < 0.01,
  'Genie summary warehouse cost must reconcile to categorized statement cost'
);

SELECT assert_true(
  (SELECT COALESCE(SUM(conversational_warehouse_cost_usd), 0)
   FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_daily_summary'))
  <=
  (SELECT COALESCE(SUM(total_space_warehouse_cost_usd), 0)
   FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_space_daily_summary')) + 0.01,
  'Conversational Genie warehouse cost must be a subset of total space warehouse cost'
);

SELECT assert_true(
  (SELECT COALESCE(SUM(warehouse_cost_usd), 0)
   FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_message_cost'))
  <=
  (SELECT COALESCE(SUM(warehouse_cost_usd), 0)
   FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.fact_genie_query_cost_category')
   WHERE cost_category = 'CONVERSATIONAL') + 0.01,
  'API-covered message warehouse cost must be a subset of conversational warehouse cost'
);
