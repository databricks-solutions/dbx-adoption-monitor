CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.genie_token_cost_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.fact_genie_token_usage_daily'
  comment: "Governed Genie LLM token DBU and USD cost metrics by product surface, channel, user, free or paid tier, and Genie Agent space."
  joins:
    - name: dim_space
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_genie_space'
      'on': source.workspace_id = dim_space.workspace_id AND source.agent_id = dim_space.space_id
    - name: dim_workspace
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_workspace'
      'on': source.workspace_id = dim_workspace.workspace_id
    - name: dim_principal
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_principal'
      'on': source.principal_id = dim_principal.principal_id
  dimensions:
    - name: Genie Surface
      expr: "COALESCE(source.genie_surface, 'UNKNOWN')"
      comment: "Genie product surface: GENIE_CODE, GENIE_ONE, or GENIE_AGENTS."
      display_name: "Genie Surface"
      synonyms: ["product", "Genie product"]
    - name: Genie Channel
      expr: "COALESCE(source.genie_channel, 'UNKNOWN')"
      comment: "UI or API channel that generated token usage."
      display_name: "Genie Channel"
      synonyms: ["channel"]
    - name: Space ID
      expr: source.agent_id
      comment: "Genie Agent space identifier; null for Genie Code and Genie One."
      display_name: "Space ID"
      synonyms: ["Genie space ID", "agent ID"]
    - name: Space Name
      expr: dim_space.space_name
      comment: "Current Genie Agent space name; null for Genie Code and Genie One."
      display_name: "Space Name"
      synonyms: ["Genie space", "Genie Agent"]
    - name: Offering
      expr: source.genie_offering
      comment: "Genie billing offering recorded in product features."
      display_name: "Offering"
      synonyms: ["offering type"]
    - name: Tier
      expr: source.tier
      comment: "FREE or PAID token billing tier derived from the SKU."
      display_name: "Tier"
      synonyms: ["free or paid"]
    - name: SKU Name
      expr: source.sku_name
      comment: "Genie token billing SKU."
      display_name: "SKU Name"
      synonyms: ["SKU", "billing SKU"]
    - name: Cloud Region
      expr: source.cloud_region
      comment: "Region encoded in the paid Genie token SKU."
      display_name: "Cloud Region"
      synonyms: ["region"]
    - name: Usage Date
      expr: source.usage_date
      comment: "Calendar date of Genie token billing usage."
      display_name: "Usage Date"
      synonyms: ["token date", "billing date"]
      format:
        type: date
        date_format: year_month_day
    - name: Usage Month
      expr: "DATE_TRUNC('MONTH', source.usage_date)"
      comment: "Calendar month of Genie token billing usage."
      display_name: "Usage Month"
      synonyms: ["month"]
      format:
        type: date
        date_format: locale_short_month
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace associated with Genie token usage."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
    - name: User
      expr: dim_principal.principal_email_masked
      comment: "Masked identity attributed to Genie token usage."
      display_name: "User"
      synonyms: ["token user", "principal"]
  measures:
    - name: Genie Token DBUs
      expr: SUM(source.token_dbus)
      comment: "Total DBUs recorded for Genie LLM token usage."
      display_name: "Genie Token DBUs"
      synonyms: ["token DBUs", "LLM consumption"]
      format:
        type: number
        decimal_places:
          type: max
          places: 2
    - name: Genie Token Cost USD
      expr: SUM(source.token_cost_usd)
      comment: "Total Genie LLM token cost at effective USD list price."
      display_name: "Genie Token Cost (USD)"
      synonyms: ["token cost", "LLM cost"]
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 2
    - name: Token Usage Records
      expr: SUM(source.usage_records)
      comment: "Total billing usage records contributing to Genie token metrics."
      display_name: "Token Usage Records"
      synonyms: ["billing records"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Free Token DBUs
      expr: SUM(source.token_dbus) FILTER (WHERE source.tier = 'FREE')
      comment: "Token DBUs recorded against the GENIE_FREE_USAGE SKU."
      display_name: "Free Token DBUs"
      synonyms: ["free-tier DBUs"]
      format:
        type: number
        decimal_places:
          type: max
          places: 2
    - name: Paid Token DBUs
      expr: SUM(source.token_dbus) FILTER (WHERE source.tier = 'PAID')
      comment: "Token DBUs recorded against paid Genie inference SKUs."
      display_name: "Paid Token DBUs"
      synonyms: ["billable token DBUs"]
      format:
        type: number
        decimal_places:
          type: max
          places: 2
    - name: Active Token Users
      expr: COUNT(DISTINCT source.principal_id)
      comment: "Distinct identities with Genie token usage."
      display_name: "Active Token Users"
      synonyms: ["token users"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Paid DBU Share
      expr: "TRY_DIVIDE(MEASURE(`Paid Token DBUs`), MEASURE(`Genie Token DBUs`))"
      comment: "Share of Genie token DBUs recorded against paid SKUs."
      display_name: "Paid DBU Share"
      synonyms: ["paid usage percentage"]
      format:
        type: percentage
        decimal_places:
          type: max
          places: 2
$$
