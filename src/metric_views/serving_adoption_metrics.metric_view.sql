CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.serving_adoption_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.fact_serving_endpoint_daily'
  comment: "Governed Model Serving endpoint metrics combining request and token activity with endpoint-grain DBU and USD cost."
  joins:
    - name: dim_endpoint
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_serving_endpoint'
      'on': source.workspace_id = dim_endpoint.workspace_id AND source.endpoint_id = dim_endpoint.endpoint_id
    - name: dim_workspace
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_workspace'
      'on': source.workspace_id = dim_workspace.workspace_id
  dimensions:
    - name: Endpoint ID
      expr: source.endpoint_id
      comment: "Model Serving endpoint identifier within a workspace."
      display_name: "Endpoint ID"
      synonyms: ["serving endpoint ID"]
    - name: Endpoint Name
      expr: dim_endpoint.endpoint_name
      comment: "Current Model Serving endpoint display name."
      display_name: "Endpoint Name"
      synonyms: ["serving endpoint"]
    - name: Entity Type
      expr: "COALESCE(source.entity_type, 'UNATTRIBUTED')"
      comment: "Representative served-entity category, or UNATTRIBUTED when serving metadata is unavailable."
      display_name: "Entity Type"
      synonyms: ["model type", "served entity type"]
    - name: Entity Name
      expr: source.entity_name
      comment: "Representative served model or entity name for the endpoint."
      display_name: "Entity Name"
      synonyms: ["model name", "served model"]
    - name: Entity Version
      expr: source.entity_version
      comment: "Representative served model version when versioned."
      display_name: "Entity Version"
      synonyms: ["model version"]
    - name: Usage Date
      expr: source.usage_date
      comment: "Calendar date of serving requests or billing usage."
      display_name: "Usage Date"
      synonyms: ["request date", "billing date"]
      format:
        type: date
        date_format: year_month_day
    - name: Usage Month
      expr: "DATE_TRUNC('MONTH', source.usage_date)"
      comment: "Calendar month of serving requests or billing usage."
      display_name: "Usage Month"
      synonyms: ["month"]
      format:
        type: date
        date_format: locale_short_month
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace associated with the serving activity."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
  measures:
    - name: Inference Requests
      expr: SUM(source.request_count)
      comment: "Total Model Serving inference requests captured by endpoint usage tracking."
      display_name: "Inference Requests"
      synonyms: ["requests", "invocations"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Input Tokens
      expr: SUM(source.input_tokens)
      comment: "Total input tokens for tracked Model Serving requests."
      display_name: "Input Tokens"
      synonyms: ["prompt tokens"]
      format:
        type: number
        abbreviation: compact
        decimal_places:
          type: max
          places: 1
    - name: Output Tokens
      expr: SUM(source.output_tokens)
      comment: "Total output tokens for tracked Model Serving requests."
      display_name: "Output Tokens"
      synonyms: ["completion tokens"]
      format:
        type: number
        abbreviation: compact
        decimal_places:
          type: max
          places: 1
    - name: Total Tokens
      expr: SUM(source.input_tokens) + SUM(source.output_tokens)
      comment: "Total input and output tokens for tracked Model Serving requests."
      display_name: "Total Tokens"
      synonyms: ["tokens"]
      format:
        type: number
        abbreviation: compact
        decimal_places:
          type: max
          places: 1
    - name: Serving DBUs
      expr: SUM(source.dbus)
      comment: "Total Databricks Units billed to Model Serving."
      display_name: "Serving DBUs"
      synonyms: ["DBUs", "serving consumption"]
      format:
        type: number
        decimal_places:
          type: max
          places: 2
    - name: Serving Cost USD
      expr: SUM(source.dollars)
      comment: "Total Model Serving cost at effective USD list price."
      display_name: "Serving Cost (USD)"
      synonyms: ["serving cost", "dollars"]
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 2
    - name: Active Serving Endpoints
      expr: COUNT(DISTINCT struct(source.workspace_id, source.endpoint_id))
      comment: "Distinct serving endpoints with request or billing activity."
      display_name: "Active Serving Endpoints"
      synonyms: ["active endpoints"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Cost per Tracked Request
      expr: "TRY_DIVIDE(MEASURE(`Serving Cost USD`), MEASURE(`Inference Requests`))"
      comment: "Average USD list-price cost per request where endpoint usage tracking is present."
      display_name: "Cost per Tracked Request"
      synonyms: ["cost per request"]
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 6
$$
