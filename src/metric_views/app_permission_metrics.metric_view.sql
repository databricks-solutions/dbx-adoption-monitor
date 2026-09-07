CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.app_permission_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.fact_app_permission_change_event'
  comment: "Governed Databricks Apps ACL change metrics from atomic grantee entries in audit events."
  joins:
    - name: dim_workspace
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_workspace'
      'on': source.workspace_id = dim_workspace.workspace_id
    - name: dim_actor
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_principal'
      'on': source.actor_principal_id = dim_actor.principal_id
    - name: dim_grantee
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_principal'
      'on': source.grantee_principal_id = dim_grantee.principal_id
  dimensions:
    - name: App ID
      expr: source.app_id
      comment: "App object identifier or name carried by the ACL request."
      display_name: "App ID"
      synonyms: ["application"]
    - name: Permission Level
      expr: source.permission_level
      comment: "Permission level present in the submitted app ACL entry."
      display_name: "Permission Level"
      synonyms: ["access level"]
    - name: Grantee Type
      expr: source.grantee_type
      comment: "USER or GROUP app ACL grantee type."
      display_name: "Grantee Type"
      synonyms: ["principal type"]
    - name: Activity Date
      expr: source.activity_date
      comment: "Calendar date on which the app ACL changed."
      display_name: "Activity Date"
      synonyms: ["permission date", "event date"]
      format:
        type: date
        date_format: year_month_day
    - name: Activity Month
      expr: "DATE_TRUNC('MONTH', source.activity_date)"
      comment: "Calendar month in which the app ACL changed."
      display_name: "Activity Month"
      synonyms: ["month"]
      format:
        type: date
        date_format: locale_short_month
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace in which the app ACL changed."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
    - name: Changed By
      expr: dim_actor.principal_email_masked
      comment: "Masked identity that changed the app ACL."
      display_name: "Changed By"
      synonyms: ["sharing user", "actor"]
    - name: Grantee
      expr: "COALESCE(dim_grantee.principal_email_masked, concat(substr(source.grantee_principal_id, 1, 8), '…'))"
      comment: "Masked user grantee or hashed group grantee."
      display_name: "Grantee"
      synonyms: ["user or group with access"]
  measures:
    - name: Permission Changes
      expr: SUM(source.permission_change_count)
      comment: "Total app ACL grantee entries submitted in permission-change events."
      display_name: "Permission Changes"
      synonyms: ["ACL changes", "access changes"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Changed Apps
      expr: COUNT(DISTINCT struct(source.workspace_id, source.app_id))
      comment: "Distinct apps with ACL change activity."
      display_name: "Changed Apps"
      synonyms: ["apps with permission changes"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
$$
