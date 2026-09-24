-- Smoke queries for every governed Metric View.

SELECT assert_true(COUNT(*) = 17, 'Expected exactly 17 adoption-monitor Metric Views')
FROM IDENTIFIER(:catalog_name || '.information_schema.tables')
WHERE table_schema = :schema_name
  AND table_type = 'METRIC_VIEW'
  AND table_name IN (
    'app_activity_metrics',
    'app_authentication_metrics',
    'app_cost_metrics',
    'app_inventory_metrics',
    'app_permission_metrics',
    'dashboard_adoption_metrics',
    'dashboard_inventory_metrics',
    'genie_conversation_metrics',
    'genie_feedback_metrics',
    'genie_message_cost_metrics',
    'genie_reach_metrics',
    'genie_space_adoption_metrics',
    'genie_token_cost_metrics',
    'genie_warehouse_cost_metrics',
    'model_inventory_metrics',
    'serving_adoption_metrics',
    'vector_search_cost_metrics'
  );

SELECT `Activity Date`, MEASURE(`App Lifecycle Events`) AS events
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.app_activity_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Activity Date`, MEASURE(`Successful App Authentications`) AS authentications
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.app_authentication_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Usage Date`, MEASURE(`App Cost USD`) AS cost_usd
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.app_cost_metrics')
GROUP BY ALL LIMIT 1;

SELECT `App Status`, MEASURE(`Apps`) AS apps
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.app_inventory_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Permission Level`, MEASURE(`Permission Changes`) AS changes
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.app_permission_metrics')
GROUP BY ALL LIMIT 1;

SELECT `View Date`, MEASURE(`Dashboard Views`) AS views
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dashboard_adoption_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Lifecycle State`, MEASURE(`Dashboards`) AS dashboards
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.dashboard_inventory_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Activity Date`, MEASURE(`Questions`) AS questions
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.genie_conversation_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Activity Date`, MEASURE(`Feedback Comments`) AS comments
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.genie_feedback_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Activity Date`, MEASURE(`Message Warehouse Cost USD`) AS cost_usd
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.genie_message_cost_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Activity Date`, MEASURE(`Space Opens`) AS opens
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.genie_reach_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Activity Date`, MEASURE(`Total Space Warehouse Cost USD`) AS warehouse_cost_usd
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.genie_space_adoption_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Usage Date`, MEASURE(`Genie Token DBUs`) AS token_dbus
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.genie_token_cost_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Cost Category`, MEASURE(`Genie Warehouse Cost USD`) AS warehouse_cost_usd
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.genie_warehouse_cost_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Catalog Name`, MEASURE(`Registered Models`) AS registered_models
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.model_inventory_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Usage Date`, MEASURE(`Inference Requests`) AS requests
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.serving_adoption_metrics')
GROUP BY ALL LIMIT 1;

SELECT `Usage Date`, MEASURE(`Vector Search Cost USD`) AS cost_usd
FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.vector_search_cost_metrics')
GROUP BY ALL LIMIT 1;
