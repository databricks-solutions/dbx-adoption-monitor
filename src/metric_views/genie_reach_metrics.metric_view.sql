CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.genie_reach_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.fact_genie_space_access_event'
  comment: "Governed Genie reach metrics from atomic space-open and space-create audit events. Conversation depth and cost are intentionally modeled separately."
  joins:
    - name: dim_space
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_genie_space'
      'on': source.workspace_id = dim_space.workspace_id AND source.space_id = dim_space.space_id
    - name: dim_workspace
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_workspace'
      'on': source.workspace_id = dim_workspace.workspace_id
    - name: dim_principal
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_principal'
      'on': source.principal_id = dim_principal.principal_id
  dimensions:
    - name: Space ID
      expr: source.space_id
      comment: "Genie space identifier within a workspace."
      display_name: "Space ID"
      synonyms: ["Genie space ID", "agent ID"]
    - name: Space Name
      expr: dim_space.space_name
      comment: "Current Genie space display name."
      display_name: "Space Name"
      synonyms: ["Genie space", "Genie Agent"]
    - name: Activity Date
      expr: source.activity_date
      comment: "Calendar date of the Genie space reach event."
      display_name: "Activity Date"
      synonyms: ["view date", "event date"]
      format:
        type: date
        date_format: year_month_day
    - name: Activity Month
      expr: "DATE_TRUNC('MONTH', source.activity_date)"
      comment: "Calendar month of the Genie space reach event."
      display_name: "Activity Month"
      synonyms: ["month"]
      format:
        type: date
        date_format: locale_short_month
    - name: Action Type
      expr: source.action_type
      comment: "OPEN or CREATE Genie space reach action."
      display_name: "Action Type"
      synonyms: ["reach action"]
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace in which the Genie reach event occurred."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
    - name: Viewer
      expr: dim_principal.principal_email_masked
      comment: "Masked identity that opened or created the Genie space."
      display_name: "Viewer"
      synonyms: ["Genie user", "actor"]
  measures:
    - name: Space Opens
      expr: SUM(source.open_count)
      comment: "Total audited Genie space opens."
      display_name: "Space Opens"
      synonyms: ["views", "Genie views"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Spaces Created
      expr: SUM(source.create_count)
      comment: "Total audited Genie space creation events."
      display_name: "Spaces Created"
      synonyms: ["space creations"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Unique Genie Viewers
      expr: COUNT(DISTINCT source.principal_id) FILTER (WHERE source.action_type = 'OPEN')
      comment: "Distinct principals that opened Genie spaces."
      display_name: "Unique Genie Viewers"
      synonyms: ["unique users", "Genie users"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Viewed Genie Spaces
      expr: COUNT(DISTINCT struct(source.workspace_id, source.space_id)) FILTER (WHERE source.action_type = 'OPEN')
      comment: "Distinct Genie spaces with at least one audited open."
      display_name: "Viewed Genie Spaces"
      synonyms: ["active spaces"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
$$
