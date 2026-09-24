CREATE OR REPLACE VIEW {{catalog_name}}.{{schema_name}}.genie_feedback_metrics
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: '{{catalog_yaml_identifier}}.{{schema_yaml_identifier}}.fact_genie_feedback_comment'
  comment: "Governed Genie free-text feedback comment metrics. Comment text is user-provided and requires appropriately restricted access."
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
      comment: "Genie message identifier receiving the feedback comment."
      display_name: "Message ID"
      synonyms: ["question ID"]
    - name: Comment ID
      expr: source.message_comment_id
      comment: "Genie message feedback comment identifier."
      display_name: "Comment ID"
      synonyms: ["message comment ID"]
    - name: Comment Text
      expr: source.comment_text
      comment: "User-provided free-text Genie feedback. This field may contain sensitive information."
      display_name: "Comment Text"
      synonyms: ["feedback text", "reason"]
    - name: Created At
      expr: source.created_at
      comment: "Timestamp at which the feedback comment was created."
      display_name: "Created At"
      synonyms: ["comment timestamp"]
      format:
        type: date_time
        date_format: year_month_day
        time_format: locale_hour_minute
    - name: Activity Date
      expr: source.activity_date
      comment: "Calendar date on which the feedback comment was created."
      display_name: "Activity Date"
      synonyms: ["comment date"]
      format:
        type: date
        date_format: year_month_day
    - name: Workspace ID
      expr: source.workspace_id
      comment: "Workspace containing the Genie feedback comment."
      display_name: "Workspace ID"
      synonyms: ["workspace"]
    - name: Workspace Name
      expr: dim_workspace.workspace_name
      comment: "Current display name of the workspace."
      display_name: "Workspace Name"
      synonyms: ["workspace"]
  measures:
    - name: Feedback Comments
      expr: SUM(source.comment_count)
      comment: "Total free-text Genie feedback comments."
      display_name: "Feedback Comments"
      synonyms: ["comments"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Commented Messages
      expr: COUNT(DISTINCT struct(source.workspace_id, source.message_id))
      comment: "Distinct Genie messages receiving at least one free-text feedback comment."
      display_name: "Commented Messages"
      synonyms: ["messages with comments"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
$$
