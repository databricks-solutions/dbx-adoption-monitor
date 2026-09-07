CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.genie_space_adoption_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.fact_genie_space_daily_summary'
  comment: Governed additive daily Genie-space scorecard spanning reach, conversation depth, SQL warehouse cost, message-cost coverage, and LLM
    token cost.
  joins:
    - name: dim_space
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_genie_space'
      'on': source.workspace_id = dim_space.workspace_id AND source.space_id = dim_space.space_id
    - name: dim_workspace
      source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.dim_workspace'
      'on': source.workspace_id = dim_workspace.workspace_id
  dimensions:
    - name: Space ID
      expr: source.space_id
      comment: Genie space identifier within a workspace.
      display_name: Space ID
      synonyms:
        - Genie space ID
        - agent ID
    - name: Space Name
      expr: dim_space.space_name
      comment: Current Genie space display name.
      display_name: Space Name
      synonyms:
        - Genie space
        - Genie Agent
    - name: Activity Date
      expr: source.activity_date
      comment: Calendar date shared across Genie reach, conversation, warehouse-cost, and token-cost streams.
      display_name: Activity Date
      synonyms:
        - date
        - usage date
      format:
        type: date
        date_format: year_month_day
    - name: Activity Month
      expr: DATE_TRUNC('MONTH', source.activity_date)
      comment: Calendar month shared across Genie metric streams.
      display_name: Activity Month
      synonyms:
        - month
      format:
        type: date
        date_format: locale_short_month
    - name: Workspace ID
      expr: source.workspace_id
      comment: Workspace containing or billing the Genie space.
      display_name: Workspace ID
      synonyms:
        - workspace
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: Current display name of the workspace.
      display_name: Workspace Name
      synonyms:
        - workspace
  measures:
    - name: Active Genie Spaces
      expr: COUNT(DISTINCT struct(source.workspace_id, source.space_id)) FILTER (WHERE source.question_count > 0 OR source.space_open_count > 0 OR source.total_space_warehouse_cost_usd
        > 0 OR source.token_dbus > 0)
      comment: Distinct Genie spaces with reach, question, warehouse-cost, or token activity.
      display_name: Active Genie Spaces
      synonyms:
        - active spaces
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Space Opens
      expr: SUM(source.space_open_count)
      comment: Total audited Genie space opens.
      display_name: Space Opens
      synonyms:
        - views
        - reach
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Spaces Created
      expr: SUM(source.space_create_count)
      comment: Total audited Genie space creation events.
      display_name: Spaces Created
      synonyms:
        - space creations
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Questions
      expr: SUM(source.question_count)
      comment: Total Genie user questions returned by the Conversation API.
      display_name: Questions
      synonyms:
        - messages
        - prompts
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Completed Questions
      expr: SUM(source.completed_question_count)
      comment: Total Genie questions with COMPLETED status.
      display_name: Completed Questions
      synonyms:
        - successful questions
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Positive Ratings
      expr: SUM(source.positive_feedback_count)
      comment: Total positive Genie message ratings.
      display_name: Positive Ratings
      synonyms:
        - thumbs up
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Negative Ratings
      expr: SUM(source.negative_feedback_count)
      comment: Total negative Genie message ratings.
      display_name: Negative Ratings
      synonyms:
        - thumbs down
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Feedback Comments
      expr: SUM(source.feedback_comment_count)
      comment: Total free-text comments attached to rated Genie messages.
      display_name: Feedback Comments
      synonyms:
        - comments
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Message Statements
      expr: SUM(source.message_statement_count)
      comment: Total SQL statements attached to API-visible Genie messages.
      display_name: Message Statements
      synonyms:
        - question queries
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Statements Missing Cost
      expr: SUM(source.statements_missing_cost_count)
      comment: Message statements not yet present in complete query-cost history.
      display_name: Statements Missing Cost
      synonyms:
        - cost gaps
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Message Warehouse Cost USD
      expr: SUM(source.message_warehouse_cost_usd)
      comment: Attributed warehouse cost for the API-covered conversational subset.
      display_name: Message Warehouse Cost (USD)
      synonyms:
        - per-question cost
        - message cost
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 2
    - name: Message Warehouse DBUs
      expr: SUM(source.message_warehouse_dbus)
      comment: Attributed warehouse DBUs for the API-covered conversational subset.
      display_name: Message Warehouse DBUs
      synonyms:
        - question DBUs
      format:
        type: number
        decimal_places:
          type: max
          places: 2
    - name: Total Space Warehouse Cost USD
      expr: SUM(source.total_space_warehouse_cost_usd)
      comment: Complete Genie-space SQL warehouse cost from query history.
      display_name: Total Space Warehouse Cost (USD)
      synonyms:
        - Genie warehouse cost
        - space cost
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 2
    - name: Total Space Warehouse DBUs
      expr: SUM(source.total_space_warehouse_dbus)
      comment: Complete Genie-space SQL warehouse DBUs from query history.
      display_name: Total Space Warehouse DBUs
      synonyms:
        - Genie warehouse DBUs
      format:
        type: number
        decimal_places:
          type: max
          places: 2
    - name: Conversational Warehouse Cost USD
      expr: SUM(source.conversational_warehouse_cost_usd)
      comment: Warehouse cost linked to API-visible Genie user questions.
      display_name: Conversational Warehouse Cost (USD)
      synonyms:
        - usage cost
        - question cost
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 2
    - name: Authoring Warehouse Cost USD
      expr: SUM(source.authoring_warehouse_cost_usd)
      comment: Warehouse cost classified as Genie space authoring or profiling.
      display_name: Authoring Warehouse Cost (USD)
      synonyms:
        - profiling cost
        - setup cost
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 2
    - name: Overhead Warehouse Cost USD
      expr: SUM(source.overhead_warehouse_cost_usd)
      comment: Warehouse cost classified as metadata, schema probe, or otherwise unattributed.
      display_name: Overhead Warehouse Cost (USD)
      synonyms:
        - unattributed cost
        - metadata cost
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 2
    - name: Genie Token DBUs
      expr: SUM(source.token_dbus)
      comment: Genie Agent LLM token DBUs attributed directly to the space.
      display_name: Genie Token DBUs
      synonyms:
        - token DBUs
        - LLM consumption
      format:
        type: number
        decimal_places:
          type: max
          places: 2
    - name: Genie Token Cost USD
      expr: SUM(source.token_cost_usd)
      comment: Genie Agent LLM token cost attributed directly to the space.
      display_name: Genie Token Cost (USD)
      synonyms:
        - token cost
        - LLM cost
      format:
        type: currency
        currency_code: USD
        decimal_places:
          type: max
          places: 2
    - name: Free Token DBUs
      expr: SUM(source.free_token_dbus)
      comment: Genie Agent token DBUs recorded against the free-tier SKU.
      display_name: Free Token DBUs
      synonyms:
        - free-tier DBUs
      format:
        type: number
        decimal_places:
          type: max
          places: 2
    - name: Paid Token DBUs
      expr: SUM(source.paid_token_dbus)
      comment: Genie Agent token DBUs recorded against paid SKUs.
      display_name: Paid Token DBUs
      synonyms:
        - billable token DBUs
      format:
        type: number
        decimal_places:
          type: max
          places: 2
    - name: Statement Cost Coverage
      expr: TRY_DIVIDE(MEASURE(`Message Statements`) - MEASURE(`Statements Missing Cost`), MEASURE(`Message Statements`))
      comment: Share of API-visible message statements matched to complete query-cost history.
      display_name: Statement Cost Coverage
      synonyms:
        - cost coverage rate
      format:
        type: percentage
        decimal_places:
          type: max
          places: 2
    - name: Conversational Cost Share
      expr: TRY_DIVIDE(MEASURE(`Conversational Warehouse Cost USD`), MEASURE(`Total Space Warehouse Cost USD`))
      comment: Share of complete Genie warehouse cost linked to API-visible user questions.
      display_name: Conversational Cost Share
      synonyms:
        - usage cost percentage
      format:
        type: percentage
        decimal_places:
          type: max
          places: 2
    - name: Positive Rating Rate
      expr: TRY_DIVIDE(MEASURE(`Positive Ratings`), MEASURE(`Positive Ratings`) + MEASURE(`Negative Ratings`))
      comment: Positive ratings divided by all explicit positive and negative ratings.
      display_name: Positive Rating Rate
      synonyms:
        - thumbs-up rate
        - satisfaction rate
      format:
        type: percentage
        decimal_places:
          type: max
          places: 2
$$
