CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.genie_conversation_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.fact_genie_message'
  comment: "Governed Genie conversation-depth, completion, SQL-generation, and feedback metrics from atomic user-question rows."
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
    - name: Activity Date
      expr: source.activity_date
      comment: "Calendar date on which the Genie question was asked."
      display_name: "Activity Date"
      synonyms: ["question date", "message date"]
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
    - name: Message Status
      expr: source.status
      comment: "Terminal or current Genie message execution status."
      display_name: "Message Status"
      synonyms: ["response status"]
    - name: Feedback Rating
      expr: source.feedback_rating
      comment: "POSITIVE, NEGATIVE, or NONE message feedback rating."
      display_name: "Feedback Rating"
      synonyms: ["thumbs up or down", "rating"]
    - name: Error Status
      expr: "CASE WHEN source.has_error THEN 'ERROR' ELSE 'NO_ERROR' END"
      comment: "Whether the Genie response carries an error."
      display_name: "Error Status"
      synonyms: ["failed response"]
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
    - name: Questions
      expr: SUM(source.question_count)
      comment: "Total Genie user questions."
      display_name: "Questions"
      synonyms: ["messages", "prompts"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Completed Questions
      expr: SUM(source.completed_question_count)
      comment: "Total Genie questions with COMPLETED status."
      display_name: "Completed Questions"
      synonyms: ["successful questions"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Conversations
      expr: COUNT(DISTINCT struct(source.workspace_id, source.conversation_id))
      comment: "Distinct Genie conversations containing user questions."
      display_name: "Conversations"
      synonyms: ["chats"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Unique Question Askers
      expr: COUNT(DISTINCT source.principal_id)
      comment: "Distinct principals that asked Genie questions."
      display_name: "Unique Question Askers"
      synonyms: ["unique users", "askers"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Positive Ratings
      expr: SUM(source.positive_feedback_count)
      comment: "Total positive Genie message ratings."
      display_name: "Positive Ratings"
      synonyms: ["thumbs up"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Negative Ratings
      expr: SUM(source.negative_feedback_count)
      comment: "Total negative Genie message ratings."
      display_name: "Negative Ratings"
      synonyms: ["thumbs down"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: SQL Statements Generated
      expr: SUM(source.statement_count)
      comment: "Total SQL statements attached to Genie messages."
      display_name: "SQL Statements Generated"
      synonyms: ["generated statements", "queries"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Feedback Comments
      expr: SUM(source.comment_count)
      comment: "Total free-text comments attached to rated Genie messages."
      display_name: "Feedback Comments"
      synonyms: ["comments"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Questions with Errors
      expr: SUM(source.question_count) FILTER (WHERE source.has_error)
      comment: "Total Genie questions carrying an error response."
      display_name: "Questions with Errors"
      synonyms: ["failed questions"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Completion Rate
      expr: "TRY_DIVIDE(MEASURE(`Completed Questions`), MEASURE(`Questions`))"
      comment: "Share of Genie questions that completed successfully."
      display_name: "Completion Rate"
      synonyms: ["success rate"]
      format:
        type: percentage
        decimal_places:
          type: max
          places: 2
    - name: Positive Rating Rate
      expr: "TRY_DIVIDE(MEASURE(`Positive Ratings`), MEASURE(`Positive Ratings`) + MEASURE(`Negative Ratings`))"
      comment: "Positive ratings divided by all explicit positive and negative ratings."
      display_name: "Positive Rating Rate"
      synonyms: ["thumbs-up rate", "satisfaction rate"]
      format:
        type: percentage
        decimal_places:
          type: max
          places: 2
$$
