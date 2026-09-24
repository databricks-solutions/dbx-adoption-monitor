CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.app_inventory_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_app'
  comment: "Governed current-state Databricks Apps inventory and access-grant metrics."
  joins:
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
      expr: source.app_name
      comment: "Current Databricks App display name."
      display_name: "App Name"
      synonyms: ["application", "Databricks App"]
    - name: App Status
      expr: "COALESCE(source.app_status, 'UNKNOWN')"
      comment: "Current app deployment status."
      display_name: "App Status"
      synonyms: ["deployment status"]
    - name: Compute Status
      expr: "COALESCE(source.compute_status, 'UNKNOWN')"
      comment: "Current Databricks App compute status."
      display_name: "Compute Status"
      synonyms: ["compute state"]
    - name: Created Date
      expr: "CAST(source.create_time AS DATE)"
      comment: "Calendar date on which the app was created."
      display_name: "Created Date"
      synonyms: ["creation date"]
      format:
        type: date
        date_format: year_month_day
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace containing the Databricks App."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
  measures:
    - name: Apps
      expr: COUNT(DISTINCT struct(source.workspace_id, source.app_id))
      comment: "Distinct Databricks Apps in the current inventory."
      display_name: "Apps"
      synonyms: ["applications"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: User Access Grants
      expr: SUM(COALESCE(source.num_users_with_access, 0))
      comment: "Total current direct user grants across inventoried apps."
      display_name: "User Access Grants"
      synonyms: ["users with access"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Group Access Grants
      expr: SUM(COALESCE(source.num_groups_with_access, 0))
      comment: "Total current group grants across inventoried apps."
      display_name: "Group Access Grants"
      synonyms: ["groups with access"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Running Apps
      expr: COUNT(DISTINCT struct(source.workspace_id, source.app_id)) FILTER (WHERE upper(COALESCE(source.compute_status, '')) IN ('ACTIVE', 'RUNNING'))
      comment: "Distinct apps whose current compute status is ACTIVE or RUNNING."
      display_name: "Running Apps"
      synonyms: ["active apps"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
$$
