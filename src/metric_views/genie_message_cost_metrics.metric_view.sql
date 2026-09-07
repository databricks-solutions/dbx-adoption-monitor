CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.genie_message_cost_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.fact_genie_message_cost'
  comment: "Governed per-question Genie SQL warehouse cost metrics for the Conversation API-covered subset, including explicit missing-cost coverage."
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
    - name: Conversation ID
      expr: source.conversation_id
      comment: "Genie conversation identifier."
      display_name: "Conversation ID"
      synonyms: ["chat ID"]
    - name: Message ID
      expr: source.message_id
      comment: "Genie user-question message identifier."
      display_name: "Message ID"
      synonyms: ["question ID"]
    - name: Feedback Rating
      expr: source.feedback_rating
      comment: "POSITIVE, NEGATIVE, or NONE message feedback rating."
      display_name: "Feedback Rating"
      synonyms: ["thumbs up or down", "rating"]
    - name: Activity Date
      expr: source.activity_date
      comment: "Calendar date on which the Genie question was asked."
      display_name: "Activity Date"
      synonyms: ["question date", "cost date"]
      format:
        type: date
        date_format: year_month_day
    - name: Activity Month
      expr: "DATE_TRUNC('MONTH', source.activity_date)"
      comment: "Calendar month in which the Genie question was asked."
      display_name: "Activity Month"
      synonyms: ["month"]
      format:
        type: date
        date_format: locale_short_month
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace containing the Genie message."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
    - name: User
      expr: dim_principal.principal_email_masked
      comment: "Masked identity that asked the Genie question."
      display_name: "User"
      synonyms: ["asker", "Genie user"]
  measures:
    - name: Costed Messages
      expr: COUNT(1)
      comment: "Genie messages with at least one SQL statement in the normalized bridge."
      display_name: "Costed Messages"
      synonyms: ["questions with SQL"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Message Warehouse Cost USD
      expr: SUM(source.warehouse_cost_usd)
      comment: "Attributed SQL warehouse cost across statements linked to Genie messages."
      display_name: "Message Warehouse Cost (USD)"
      synonyms: ["per-question cost", "message cost"]
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 4
    - name: Message Warehouse DBUs
      expr: SUM(source.warehouse_dbus)
      comment: "Attributed SQL warehouse DBUs across statements linked to Genie messages."
      display_name: "Message Warehouse DBUs"
      synonyms: ["question DBUs"]
      format:
        type: number
        decimal_places:
          type: max
          places: 4
    - name: Message Statements
      expr: SUM(source.statement_count)
      comment: "Total SQL statements linked to Genie messages."
      display_name: "Message Statements"
      synonyms: ["question queries"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Statements Missing Cost
      expr: SUM(source.statements_missing_cost)
      comment: "Message statements not yet present in complete query-cost history."
      display_name: "Statements Missing Cost"
      synonyms: ["cost gaps", "unmatched statements"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Statements with Cost
      expr: SUM(source.statement_count) - SUM(source.statements_missing_cost)
      comment: "Message statements successfully matched to query-cost history."
      display_name: "Statements with Cost"
      synonyms: ["matched statements"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Statement Cost Coverage
      expr: "TRY_DIVIDE(MEASURE(`Statements with Cost`), MEASURE(`Message Statements`))"
      comment: "Share of message statements matched to complete query-cost history."
      display_name: "Statement Cost Coverage"
      synonyms: ["cost coverage rate"]
      format:
        type: percentage
        decimal_places:
          type: max
          places: 2
    - name: Average Warehouse Cost per Message
      expr: "TRY_DIVIDE(MEASURE(`Message Warehouse Cost USD`), MEASURE(`Costed Messages`))"
      comment: "Average attributed SQL warehouse cost per API-visible Genie message."
      display_name: "Average Warehouse Cost per Message"
      synonyms: ["average question cost"]
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 4
$$
