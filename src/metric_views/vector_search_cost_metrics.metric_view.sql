CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.vector_search_cost_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.fact_vector_search_daily'
  comment: "Governed Vector Search DBU and USD cost metrics, including explicit attribution coverage for index-maintenance billing rows."
  joins:
    - name: dim_endpoint
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_vector_search_endpoint'
      'on': source.workspace_id = dim_endpoint.workspace_id AND source.endpoint_id = dim_endpoint.endpoint_id
    - name: dim_workspace
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_workspace'
      'on': source.workspace_id = dim_workspace.workspace_id
  dimensions:
    - name: Endpoint ID
      expr: source.endpoint_id
      comment: "Vector Search endpoint identifier or __UNATTRIBUTED__ for maintenance cost."
      display_name: "Endpoint ID"
      synonyms: ["Vector Search endpoint ID"]
    - name: Endpoint Name
      expr: dim_endpoint.endpoint_name
      comment: "Vector Search endpoint name or explicit unattributed maintenance label."
      display_name: "Endpoint Name"
      synonyms: ["Vector Search endpoint", "index endpoint"]
    - name: SKU Name
      expr: source.sku_name
      comment: "Billing SKU carrying Vector Search or index-maintenance usage."
      display_name: "SKU Name"
      synonyms: ["SKU", "billing SKU"]
    - name: Attribution Status
      expr: "CASE WHEN source.is_attributed THEN 'ATTRIBUTED' ELSE 'UNATTRIBUTED' END"
      comment: "Whether billing metadata identifies a specific Vector Search endpoint."
      display_name: "Attribution Status"
      synonyms: ["cost attribution", "coverage status"]
    - name: Usage Date
      expr: source.usage_date
      comment: "Calendar date of Vector Search billing usage."
      display_name: "Usage Date"
      synonyms: ["billing date"]
      format:
        type: date
        date_format: year_month_day
    - name: Usage Month
      expr: "DATE_TRUNC('MONTH', source.usage_date)"
      comment: "Calendar month of Vector Search billing usage."
      display_name: "Usage Month"
      synonyms: ["month"]
      format:
        type: date
        date_format: locale_short_month
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace associated with the Vector Search billing usage."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
  measures:
    - name: Vector Search DBUs
      expr: SUM(source.dbus)
      comment: "Total Databricks Units billed to Vector Search and related index maintenance."
      display_name: "Vector Search DBUs"
      synonyms: ["DBUs", "Vector Search consumption"]
      format:
        type: number
        decimal_places:
          type: max
          places: 2
    - name: Vector Search Cost USD
      expr: SUM(source.dollars)
      comment: "Total Vector Search and index-maintenance cost at effective USD list price."
      display_name: "Vector Search Cost (USD)"
      synonyms: ["Vector Search cost", "index cost"]
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 2
    - name: Attributed Cost USD
      expr: SUM(source.dollars) FILTER (WHERE source.is_attributed)
      comment: "USD cost carrying a specific Vector Search endpoint identifier."
      display_name: "Attributed Cost (USD)"
      synonyms: ["endpoint-attributed cost"]
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 2
    - name: Unattributed Cost USD
      expr: SUM(source.dollars) FILTER (WHERE NOT source.is_attributed)
      comment: "USD cost without an endpoint identifier, typically index-maintenance compute."
      display_name: "Unattributed Cost (USD)"
      synonyms: ["maintenance cost", "unmapped cost"]
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 2
    - name: Active Vector Search Endpoints
      expr: COUNT(DISTINCT struct(source.workspace_id, source.endpoint_id)) FILTER (WHERE source.is_attributed)
      comment: "Distinct identified Vector Search endpoints with billed usage."
      display_name: "Active Vector Search Endpoints"
      synonyms: ["active endpoints"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Cost Attribution Rate
      expr: "TRY_DIVIDE(MEASURE(`Attributed Cost USD`), MEASURE(`Vector Search Cost USD`))"
      comment: "Share of Vector Search USD cost attributed to a specific endpoint."
      display_name: "Cost Attribution Rate"
      synonyms: ["attribution coverage"]
      format:
        type: percentage
        decimal_places:
          type: max
          places: 2
$$
