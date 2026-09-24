CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.app_cost_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.fact_app_daily'
  comment: "Governed daily Databricks Apps consumption metrics. Cost comes from system.billing.usage and remains separate from atomic lifecycle activity."
  joins:
    - name: dim_app
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_app'
      'on': source.workspace_id = dim_app.workspace_id AND source.app_id = dim_app.app_id
    - name: dim_workspace
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_workspace'
      'on': source.workspace_id = dim_workspace.workspace_id
  dimensions:
    - name: App ID
      expr: source.app_id
      comment: "Stable Databricks App identifier within a workspace."
      display_name: "App ID"
      synonyms: ["application ID"]
    - name: App Name
      expr: dim_app.app_name
      comment: "Current Databricks App display name."
      display_name: "App Name"
      synonyms: ["application", "Databricks App"]
    - name: Usage Date
      expr: source.usage_date
      comment: "Calendar date of Databricks Apps billing usage."
      display_name: "Usage Date"
      synonyms: ["billing date", "activity date"]
      format:
        type: date
        date_format: year_month_day
    - name: Usage Month
      expr: "DATE_TRUNC('MONTH', source.usage_date)"
      comment: "Calendar month of Databricks Apps billing usage."
      display_name: "Usage Month"
      synonyms: ["month"]
      format:
        type: date
        date_format: locale_short_month
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace associated with Databricks Apps billing usage."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
  measures:
    - name: App DBUs
      expr: SUM(source.dbus)
      comment: "Total Databricks Units consumed by Apps."
      display_name: "App DBUs"
      synonyms: ["DBUs", "app consumption"]
      format:
        type: number
        decimal_places:
          type: max
          places: 2
    - name: App Cost USD
      expr: SUM(source.dollars)
      comment: "Total Databricks Apps cost at effective USD list price."
      display_name: "App Cost (USD)"
      synonyms: ["app cost", "dollars"]
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 2
    - name: Billed Apps
      expr: COUNT(DISTINCT struct(source.workspace_id, source.app_id)) FILTER (WHERE source.dbus > 0)
      comment: "Distinct apps with positive billed DBU usage."
      display_name: "Billed Apps"
      synonyms: ["apps with cost"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Average Cost per Billed App
      expr: "MEASURE(`App Cost USD`) / NULLIF(MEASURE(`Billed Apps`), 0)"
      comment: "Average USD list-price cost per distinct billed app."
      display_name: "Average Cost per Billed App"
      synonyms: ["cost per app"]
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 2
$$
