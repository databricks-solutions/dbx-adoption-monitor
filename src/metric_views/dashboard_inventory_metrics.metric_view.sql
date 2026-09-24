CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.dashboard_inventory_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_dashboard'
  comment: "Governed current-state AI/BI dashboard inventory metrics, including dashboards with no recent views."
  joins:
    - name: dim_workspace
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_workspace'
      'on': source.workspace_id = dim_workspace.workspace_id
  dimensions:
    - name: Dashboard ID
      expr: source.dashboard_id
      comment: "Stable Lakeview dashboard identifier within a workspace."
      display_name: "Dashboard ID"
      synonyms: ["Lakeview dashboard ID"]
    - name: Dashboard Name
      expr: source.dashboard_name
      comment: "Current AI/BI dashboard display name."
      display_name: "Dashboard Name"
      synonyms: ["Lakeview dashboard", "dashboard"]
    - name: Lifecycle State
      expr: "COALESCE(source.lifecycle_state, 'UNKNOWN')"
      comment: "Current dashboard lifecycle state."
      display_name: "Lifecycle State"
      synonyms: ["dashboard state", "status"]
    - name: Warehouse ID
      expr: source.warehouse_id
      comment: "SQL warehouse configured for the dashboard."
      display_name: "Warehouse ID"
      synonyms: ["dashboard warehouse"]
    - name: Created Date
      expr: "CAST(source.create_time AS DATE)"
      comment: "Calendar date on which the dashboard was created."
      display_name: "Created Date"
      synonyms: ["creation date"]
      format:
        type: date
        date_format: year_month_day
    - name: Updated Date
      expr: "CAST(source.update_time AS DATE)"
      comment: "Calendar date on which the dashboard was most recently updated."
      display_name: "Updated Date"
      synonyms: ["last updated date"]
      format:
        type: date
        date_format: year_month_day
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace containing the dashboard."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
  measures:
    - name: Dashboards
      expr: COUNT(DISTINCT struct(source.workspace_id, source.dashboard_id))
      comment: "Distinct dashboards in the current inventory."
      display_name: "Dashboards"
      synonyms: ["AI/BI dashboards", "Lakeview dashboards"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Dashboards with Warehouses
      expr: COUNT(DISTINCT struct(source.workspace_id, source.dashboard_id)) FILTER (WHERE source.warehouse_id IS NOT NULL)
      comment: "Distinct dashboards with a configured SQL warehouse."
      display_name: "Dashboards with Warehouses"
      synonyms: ["configured dashboards"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
$$
