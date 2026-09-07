CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.app_authentication_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.fact_app_authentication_event'
  comment: "Governed successful Databricks Apps OAuth authentication metrics from atomic audit events."
  joins:
    - name: dim_workspace
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_workspace'
      'on': source.workspace_id = dim_workspace.workspace_id
    - name: dim_principal
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_principal'
      'on': source.principal_id = dim_principal.principal_id
  dimensions:
    - name: Activity Date
      expr: source.activity_date
      comment: "Calendar date of the successful app authentication."
      display_name: "Activity Date"
      synonyms: ["login date", "authentication date"]
      format:
        type: date
        date_format: year_month_day
    - name: Activity Month
      expr: "DATE_TRUNC('MONTH', source.activity_date)"
      comment: "Calendar month of the successful app authentication."
      display_name: "Activity Month"
      synonyms: ["month"]
      format:
        type: date
        date_format: locale_short_month
    - name: Authentication Action
      expr: source.action_name
      comment: "OAuth audit action recorded for Databricks Apps authentication."
      display_name: "Authentication Action"
      synonyms: ["login action"]
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace in which the app authentication occurred."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
    - name: User
      expr: dim_principal.principal_email_masked
      comment: "Masked identity that authenticated to a Databricks App."
      display_name: "User"
      synonyms: ["app user"]
  measures:
    - name: Successful App Authentications
      expr: SUM(source.authentication_event_count)
      comment: "Total successful Databricks Apps OAuth authentication events."
      display_name: "Successful App Authentications"
      synonyms: ["app logins", "login events"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Unique Authenticated App Users
      expr: COUNT(DISTINCT source.principal_id)
      comment: "Distinct principals with successful Databricks Apps authentication events."
      display_name: "Unique Authenticated App Users"
      synonyms: ["unique app users"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
$$
