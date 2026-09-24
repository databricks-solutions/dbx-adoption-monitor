CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.app_activity_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.fact_app_activity_event'
  comment: "Governed Databricks Apps lifecycle activity metrics from atomic audit events, including re-aggregation-safe distinct user counts."
  joins:
    - name: dim_app
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_app'
      'on': source.workspace_id = dim_app.workspace_id AND source.app_id = dim_app.app_id
    - name: dim_workspace
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_workspace'
      'on': source.workspace_id = dim_workspace.workspace_id
    - name: dim_principal
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_principal'
      'on': source.principal_id = dim_principal.principal_id
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
    - name: Activity Date
      expr: source.activity_date
      comment: "Calendar date on which the app lifecycle action occurred."
      display_name: "Activity Date"
      synonyms: ["usage date", "event date"]
      format:
        type: date
        date_format: year_month_day
    - name: Activity Month
      expr: "DATE_TRUNC('MONTH', source.activity_date)"
      comment: "Calendar month in which the app lifecycle action occurred."
      display_name: "Activity Month"
      synonyms: ["month"]
      format:
        type: date
        date_format: locale_short_month
    - name: Action Name
      expr: source.action_name
      comment: "Apps audit action, such as deployApplication, startApp, or stopApp."
      display_name: "Action Name"
      synonyms: ["app action", "lifecycle action"]
    - name: App Status
      expr: dim_app.app_status
      comment: "Current application deployment status."
      display_name: "App Status"
      synonyms: ["deployment status"]
    - name: Compute Status
      expr: dim_app.compute_status
      comment: "Current Databricks App compute status."
      display_name: "Compute Status"
      synonyms: ["app compute state"]
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace identifier in which the app action occurred."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
    - name: Actor
      expr: dim_principal.principal_email_masked
      comment: "Masked identity that performed the app lifecycle action."
      display_name: "Actor"
      synonyms: ["user", "app user"]
  measures:
    - name: App Lifecycle Events
      expr: SUM(source.lifecycle_event_count)
      comment: "Total Databricks Apps lifecycle audit events."
      display_name: "App Lifecycle Events"
      synonyms: ["app events", "actions"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Active Apps
      expr: COUNT(DISTINCT struct(source.workspace_id, source.app_id))
      comment: "Distinct apps with at least one lifecycle event."
      display_name: "Active Apps"
      synonyms: ["used apps"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Unique App Users
      expr: COUNT(DISTINCT source.principal_id)
      comment: "Distinct principals performing app lifecycle actions."
      display_name: "Unique App Users"
      synonyms: ["unique users", "app actors"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: App Deployments
      expr: SUM(source.lifecycle_event_count) FILTER (WHERE lower(source.action_name) LIKE '%deploy%')
      comment: "Lifecycle actions whose audit action name indicates an app deployment."
      display_name: "App Deployments"
      synonyms: ["deploys"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: App Starts
      expr: SUM(source.lifecycle_event_count) FILTER (WHERE lower(source.action_name) LIKE '%start%')
      comment: "Lifecycle actions whose audit action name indicates an app start."
      display_name: "App Starts"
      synonyms: ["starts"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: App Stops
      expr: SUM(source.lifecycle_event_count) FILTER (WHERE lower(source.action_name) LIKE '%stop%')
      comment: "Lifecycle actions whose audit action name indicates an app stop."
      display_name: "App Stops"
      synonyms: ["stops"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
$$
