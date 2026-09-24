CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.dashboard_adoption_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.fact_dashboard_view_event'
  comment: "Governed AI/BI dashboard reach metrics from atomic audit events. Distinct viewers re-aggregate correctly across arbitrary date ranges."
  joins:
    - name: dim_dashboard
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_dashboard'
      'on': source.workspace_id = dim_dashboard.workspace_id AND source.dashboard_id = dim_dashboard.dashboard_id
    - name: dim_workspace
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_workspace'
      'on': source.workspace_id = dim_workspace.workspace_id
    - name: dim_principal
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_principal'
      'on': source.principal_id = dim_principal.principal_id
  dimensions:
    - name: Dashboard ID
      expr: source.dashboard_id
      comment: "Stable Lakeview dashboard identifier within a workspace."
      display_name: "Dashboard ID"
      synonyms: ["Lakeview dashboard ID"]
    - name: Dashboard Name
      expr: dim_dashboard.dashboard_name
      comment: "Current AI/BI dashboard display name."
      display_name: "Dashboard Name"
      synonyms: ["Lakeview dashboard", "dashboard"]
    - name: View Date
      expr: source.viewed_date
      comment: "Calendar date on which a dashboard view occurred."
      display_name: "View Date"
      synonyms: ["viewed date", "activity date"]
      format:
        type: date
        date_format: year_month_day
    - name: View Month
      expr: "DATE_TRUNC('MONTH', source.viewed_date)"
      comment: "Calendar month in which a dashboard view occurred."
      display_name: "View Month"
      synonyms: ["month"]
      format:
        type: date
        date_format: locale_short_month
    - name: View Type
      expr: source.view_type
      comment: "Whether the view used the draft editor or the published dashboard."
      display_name: "View Type"
      synonyms: ["draft or published", "publication state"]
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace identifier in which the dashboard view occurred."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
    - name: Viewer
      expr: dim_principal.principal_email_masked
      comment: "Masked identity of the dashboard viewer."
      display_name: "Viewer"
      synonyms: ["user", "consumer"]
  measures:
    - name: Dashboard Views
      expr: SUM(source.view_count)
      comment: "Total dashboard view events."
      display_name: "Dashboard Views"
      synonyms: ["views", "opens"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Draft Dashboard Views
      expr: SUM(source.view_count) FILTER (WHERE source.view_type = 'DRAFT')
      comment: "Dashboard views opened in the draft editor."
      display_name: "Draft Dashboard Views"
      synonyms: ["draft views"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Published Dashboard Views
      expr: SUM(source.view_count) FILTER (WHERE source.view_type = 'PUBLISHED')
      comment: "Views of published AI/BI dashboards."
      display_name: "Published Dashboard Views"
      synonyms: ["published views"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Unique Dashboard Viewers
      expr: COUNT(DISTINCT source.principal_id)
      comment: "Distinct principals that viewed dashboards in the selected scope."
      display_name: "Unique Dashboard Viewers"
      synonyms: ["unique viewers", "dashboard users"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Viewed Dashboards
      expr: COUNT(DISTINCT struct(source.workspace_id, source.dashboard_id))
      comment: "Distinct dashboards with at least one view event."
      display_name: "Viewed Dashboards"
      synonyms: ["active dashboards"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
$$
