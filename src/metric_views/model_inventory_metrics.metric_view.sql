CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.model_inventory_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_uc_model'
  comment: "Governed current-state Unity Catalog registered-model inventory and access-grant metrics."
  joins:
    - name: dim_workspace
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_workspace'
      'on': source.workspace_id = dim_workspace.workspace_id
  dimensions:
    - name: Model Key
      expr: source.model_key
      comment: "Stable key for workspace and full registered-model name."
      display_name: "Model Key"
      synonyms: ["registered model key"]
    - name: Full Model Name
      expr: source.full_name
      comment: "Three-level Unity Catalog registered-model name."
      display_name: "Full Model Name"
      synonyms: ["registered model", "model full name"]
    - name: Model Name
      expr: source.model_name
      comment: "Unqualified registered-model name."
      display_name: "Model Name"
      synonyms: ["model"]
    - name: Catalog Name
      expr: source.catalog_name
      comment: "Unity Catalog containing the registered model."
      display_name: "Catalog Name"
      synonyms: ["catalog"]
    - name: Schema Name
      expr: source.schema_name
      comment: "Unity Catalog schema containing the registered model."
      display_name: "Schema Name"
      synonyms: ["schema", "database"]
    - name: Owner
      expr: source.owner
      comment: "Current registered-model owner."
      display_name: "Owner"
      synonyms: ["model owner"]
    - name: Created Date
      expr: "CAST(source.created_at AS DATE)"
      comment: "Calendar date on which the registered model was created."
      display_name: "Created Date"
      synonyms: ["creation date"]
      format:
        type: date
        date_format: year_month_day
    - name: Updated Date
      expr: "CAST(source.updated_at AS DATE)"
      comment: "Calendar date on which the registered model was most recently updated."
      display_name: "Updated Date"
      synonyms: ["last updated date"]
      format:
        type: date
        date_format: year_month_day
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace that performed the registered-model inventory crawl."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
  measures:
    - name: Registered Models
      expr: COUNT(DISTINCT source.model_key)
      comment: "Distinct Unity Catalog registered models in the current inventory."
      display_name: "Registered Models"
      synonyms: ["models"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: User Access Grants
      expr: SUM(COALESCE(source.num_users_with_access, 0))
      comment: "Total current direct user grants across registered models."
      display_name: "User Access Grants"
      synonyms: ["users with access"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Group Access Grants
      expr: SUM(COALESCE(source.num_groups_with_access, 0))
      comment: "Total current group grants across registered models."
      display_name: "Group Access Grants"
      synonyms: ["groups with access"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
$$
