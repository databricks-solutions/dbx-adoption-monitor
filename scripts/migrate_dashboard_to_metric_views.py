"""Repoint dashboard datasets to Metric Views and add the Vector Search page."""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any


DATASET_SQL = {
    "e2b9e81f": """
SELECT
  `Dashboard ID` AS dashboard_id,
  CASE
    WHEN `Dashboard Name` RLIKE '.* [0-9]{4}-[0-9]{2}-[0-9]{2} .*' THEN 'unnamed_dashboard'
    ELSE `Dashboard Name`
  END AS dashboard_name,
  `View Date` AS viewed_date,
  `Workspace ID` AS workspace_id,
  `Workspace Name` AS workspace_name,
  MEASURE(`Dashboard Views`) AS num_views,
  MEASURE(`Draft Dashboard Views`) AS DraftDashboardViews,
  MEASURE(`Published Dashboard Views`) AS PublishedDashboardViews
FROM dashboard_adoption_metrics
GROUP BY ALL
""",
    "a5510c39": """
SELECT
  CASE
    WHEN `Dashboard Name` RLIKE '.* [0-9]{4}-[0-9]{2}-[0-9]{2} .*' THEN 'unnamed_dashboard'
    ELSE `Dashboard Name`
  END AS dashboard_name,
  MEASURE(`Dashboard Views`) AS num_views
FROM dashboard_adoption_metrics
WHERE `View Date` >= date_sub(current_date(), 14)
GROUP BY ALL
HAVING MEASURE(`Dashboard Views`) < 10
""",
    "9d2c306d": """
WITH weekly_views AS (
  SELECT
    `Dashboard ID` AS dashboard_id,
    `Workspace ID` AS workspace_id,
    `Dashboard Name` AS dashboard_name,
    weekofyear(`View Date`) AS week_num,
    MEASURE(`Dashboard Views`) AS num_views
  FROM dashboard_adoption_metrics
  WHERE `View Date` >= current_date() - INTERVAL 21 DAYS
  GROUP BY ALL
),
weekly_ranks AS (
  SELECT *, DENSE_RANK() OVER (PARTITION BY week_num ORDER BY num_views DESC) AS week_rank
  FROM weekly_views
),
pivoted AS (
  SELECT
    dashboard_id,
    workspace_id,
    first(dashboard_name) AS dashboard_name,
    coalesce(MAX(CASE WHEN week_num = weekofyear(current_date()) THEN num_views END), 0) AS week_0_views,
    coalesce(MAX(CASE WHEN week_num = weekofyear(current_date() - INTERVAL 7 DAYS) THEN num_views END), 0) AS week_1_views,
    coalesce(MAX(CASE WHEN week_num = weekofyear(current_date() - INTERVAL 14 DAYS) THEN num_views END), 0) AS week_2_views,
    coalesce(MAX(CASE WHEN week_num = weekofyear(current_date()) THEN week_rank END), 999) AS week_0_rank,
    coalesce(MAX(CASE WHEN week_num = weekofyear(current_date() - INTERVAL 7 DAYS) THEN week_rank END), 999) AS week_1_rank,
    coalesce(MAX(CASE WHEN week_num = weekofyear(current_date() - INTERVAL 14 DAYS) THEN week_rank END), 999) AS week_2_rank,
    SUM(num_views) AS total_views
  FROM weekly_ranks
  GROUP BY dashboard_id, workspace_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (ORDER BY total_views DESC) AS overall_rank
  FROM pivoted
)
SELECT
  overall_rank,
  dashboard_name,
  dashboard_id,
  workspace_id,
  coalesce(week_0_views, week_1_views) AS this_week_views,
  coalesce(week_0_rank, week_1_rank) AS this_week_rank,
  week_1_views AS last_week_views,
  week_1_rank AS last_week_rank,
  week_2_views AS two_weeks_ago_views,
  week_2_rank AS two_weeks_ago_rank,
  this_week_rank - last_week_rank AS rank_change
FROM ranked
WHERE overall_rank <= 10 AND week_0_rank < 999
ORDER BY overall_rank
""",
    "f8608a63": """
WITH monthly_views AS (
  SELECT
    `Dashboard ID` AS dashboard_id,
    `Dashboard Name` AS dashboard_name,
    `View Month` AS month,
    MEASURE(`Dashboard Views`) AS total_views
  FROM dashboard_adoption_metrics
  WHERE `View Date` >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL 1 MONTH
  GROUP BY ALL
),
pivoted AS (
  SELECT
    dashboard_name,
    MAX(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE) THEN total_views END) AS this_month_views,
    MAX(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE) - INTERVAL 1 MONTH THEN total_views END) AS last_month_views
  FROM monthly_views
  GROUP BY dashboard_name
),
diffs AS (
  SELECT dashboard_name, COALESCE(this_month_views, 0) - COALESCE(last_month_views, 0) AS view_diff
  FROM pivoted
),
ranked AS (
  SELECT
    dashboard_name,
    view_diff,
    CASE WHEN view_diff >= 0 THEN 'Climber' ELSE 'Decliner' END AS type,
    DENSE_RANK() OVER (PARTITION BY view_diff >= 0 ORDER BY abs(view_diff) DESC) AS rank
  FROM diffs
)
SELECT dashboard_name, view_diff, type, rank
FROM ranked
WHERE rank <= 20
ORDER BY type, rank
""",
    "51bbce62": """
SELECT
  `Activity Date` AS event_date,
  MEASURE(`Successful App Authentications`) AS user_login_events
FROM app_authentication_metrics
GROUP BY ALL
ORDER BY event_date DESC
""",
    "0e741d6f": """
SELECT
  `Activity Date` AS event_date,
  `Workspace ID` AS workspace_id,
  `App ID` AS app,
  `Changed By` AS sharing_user,
  `Grantee` AS `acl_entry.user_name`,
  `Permission Level` AS `acl_entry.permission_level`,
  MEASURE(`Permission Changes`) AS permission_changes
FROM app_permission_metrics
GROUP BY ALL
ORDER BY event_date DESC
""",
    "20c44dd1": """
SELECT
  `Activity Date` AS event_date,
  `Action Name` AS action_name,
  MEASURE(`App Lifecycle Events`) AS actions
FROM app_activity_metrics
GROUP BY ALL
ORDER BY event_date DESC
""",
    "255e661f": """
SELECT
  `Actor` AS email,
  MEASURE(`App Lifecycle Events`) AS action_count
FROM app_activity_metrics
WHERE `Activity Date` >= date_sub(current_date(), 7)
GROUP BY ALL
ORDER BY action_count DESC
LIMIT 10
""",
    "a19ba0f5": """
SELECT
  `App Name` AS app_name,
  `Workspace Name` AS workspace_name,
  MEASURE(`Unique App Users`) AS distinct_users,
  MEASURE(`App Lifecycle Events`) AS lifecycle_events
FROM app_activity_metrics
GROUP BY ALL
""",
    "75376ae2": """
SELECT
  `Entity Name` AS entity_name,
  `Usage Date` AS usage_date,
  `Workspace Name` AS workspace_name,
  MEASURE(`Inference Requests`) AS request_count,
  MEASURE(`Input Tokens`) AS input_tokens,
  MEASURE(`Output Tokens`) AS output_tokens,
  MEASURE(`Serving DBUs`) AS dbus,
  MEASURE(`Serving Cost USD`) AS dollars
FROM serving_adoption_metrics
GROUP BY ALL
""",
    "gspaces": """
SELECT `Space ID` AS space_id, `Space Name` AS space_name
FROM genie_space_adoption_metrics
GROUP BY ALL
""",
    "ov_kpi": """
WITH scorecard AS (
  SELECT
    MEASURE(`Active Genie Spaces`) AS active_spaces,
    MEASURE(`Questions`) AS questions,
    MEASURE(`Total Space Warehouse Cost USD`) AS warehouse_usd,
    MEASURE(`Genie Token Cost USD`) AS token_usd,
    MEASURE(`Genie Token DBUs`) AS token_dbus
  FROM genie_space_adoption_metrics
  WHERE `Activity Date` >= CAST(:param.min AS DATE)
    AND `Activity Date` <= CAST(:param.max AS DATE)
    AND (:space_id = 'ALL' OR `Space ID` = :space_id)
  GROUP BY ALL
),
people AS (
  SELECT MEASURE(`Unique Question Askers`) AS users
  FROM genie_conversation_metrics
  WHERE `Activity Date` >= CAST(:param.min AS DATE)
    AND `Activity Date` <= CAST(:param.max AS DATE)
    AND (:space_id = 'ALL' OR `Space ID` = :space_id)
  GROUP BY ALL
)
SELECT scorecard.*, people.users FROM scorecard CROSS JOIN people
""",
    "ov_leaderboard": """
WITH scorecard AS (
  SELECT
    `Space ID` AS space_id,
    `Space Name` AS space_name,
    MEASURE(`Questions`) AS questions,
    MEASURE(`Space Opens`) AS views,
    MEASURE(`Positive Ratings`) AS positive,
    MEASURE(`Negative Ratings`) AS negative,
    MEASURE(`Total Space Warehouse Cost USD`) AS warehouse_usd,
    MEASURE(`Genie Token Cost USD`) AS token_usd
  FROM genie_space_adoption_metrics
  WHERE `Activity Date` >= CAST(:param.min AS DATE)
    AND `Activity Date` <= CAST(:param.max AS DATE)
    AND (:space_id = 'ALL' OR `Space ID` = :space_id)
  GROUP BY ALL
),
people AS (
  SELECT `Space ID` AS space_id, MEASURE(`Unique Question Askers`) AS users
  FROM genie_conversation_metrics
  WHERE `Activity Date` >= CAST(:param.min AS DATE)
    AND `Activity Date` <= CAST(:param.max AS DATE)
    AND (:space_id = 'ALL' OR `Space ID` = :space_id)
  GROUP BY ALL
)
SELECT s.*, COALESCE(p.users, 0) AS users
FROM scorecard s LEFT JOIN people p USING (space_id)
""",
    "ov_trend": """
SELECT `Activity Date` AS day, MEASURE(`Questions`) AS questions
FROM genie_conversation_metrics
WHERE `Activity Date` >= CAST(:param.min AS DATE)
  AND `Activity Date` <= CAST(:param.max AS DATE)
  AND (:space_id = 'ALL' OR `Space ID` = :space_id)
GROUP BY ALL
ORDER BY day
""",
    "us_kpi": """
WITH messages AS (
  SELECT
    MEASURE(`Questions`) AS questions,
    MEASURE(`Unique Question Askers`) AS users
  FROM genie_conversation_metrics
  WHERE `Activity Date` >= CAST(:param.min AS DATE)
    AND `Activity Date` <= CAST(:param.max AS DATE)
    AND (:space_id = 'ALL' OR `Space ID` = :space_id)
  GROUP BY ALL
),
by_conversation AS (
  SELECT `Conversation ID`, MEASURE(`Questions`) AS message_count
  FROM genie_conversation_metrics
  WHERE `Activity Date` >= CAST(:param.min AS DATE)
    AND `Activity Date` <= CAST(:param.max AS DATE)
    AND (:space_id = 'ALL' OR `Space ID` = :space_id)
  GROUP BY ALL
),
reach AS (
  SELECT MEASURE(`Space Opens`) AS views
  FROM genie_space_adoption_metrics
  WHERE `Activity Date` >= CAST(:param.min AS DATE)
    AND `Activity Date` <= CAST(:param.max AS DATE)
    AND (:space_id = 'ALL' OR `Space ID` = :space_id)
  GROUP BY ALL
)
SELECT
  messages.questions,
  messages.users,
  COALESCE(reach.views, 0) AS views,
  (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY message_count) FROM by_conversation) AS median_msgs_per_conv
FROM messages CROSS JOIN reach
""",
    "us_reach": """
SELECT
  `Space Name` AS space_name,
  MEASURE(`Space Opens`) AS views,
  MEASURE(`Questions`) AS questions
FROM genie_space_adoption_metrics
WHERE `Activity Date` >= CAST(:param.min AS DATE)
  AND `Activity Date` <= CAST(:param.max AS DATE)
  AND (:space_id = 'ALL' OR `Space ID` = :space_id)
GROUP BY ALL
""",
    "us_trend": """
SELECT `Activity Date` AS day, MEASURE(`Questions`) AS questions
FROM genie_conversation_metrics
WHERE `Activity Date` >= CAST(:param.min AS DATE)
  AND `Activity Date` <= CAST(:param.max AS DATE)
  AND (:space_id = 'ALL' OR `Space ID` = :space_id)
GROUP BY ALL
ORDER BY day
""",
    "us_feedback": """
SELECT
  `Space Name` AS space_name,
  `Feedback Rating` AS feedback_rating,
  MEASURE(`Questions`) AS messages
FROM genie_conversation_metrics
WHERE `Activity Date` >= CAST(:param.min AS DATE)
  AND `Activity Date` <= CAST(:param.max AS DATE)
  AND (:space_id = 'ALL' OR `Space ID` = :space_id)
GROUP BY ALL
""",
    "us_comments": """
SELECT
  `Space Name` AS space_name,
  `Comment Text` AS comment_text,
  `Created At` AS created_timestamp,
  MEASURE(`Feedback Comments`) AS comments
FROM genie_feedback_metrics
WHERE `Activity Date` >= CAST(:param.min AS DATE)
  AND `Activity Date` <= CAST(:param.max AS DATE)
  AND (:space_id = 'ALL' OR `Space ID` = :space_id)
GROUP BY ALL
ORDER BY created_timestamp DESC
""",
    "us_errors": """
SELECT
  `Space Name` AS space_name,
  MEASURE(`Questions`) AS total,
  MEASURE(`Questions with Errors`) AS errors
FROM genie_conversation_metrics
WHERE `Activity Date` >= CAST(:param.min AS DATE)
  AND `Activity Date` <= CAST(:param.max AS DATE)
  AND (:space_id = 'ALL' OR `Space ID` = :space_id)
GROUP BY ALL
""",
    "us_topusers": """
SELECT `User` AS user_email, MEASURE(`Questions`) AS questions
FROM genie_conversation_metrics
WHERE `Activity Date` >= CAST(:param.min AS DATE)
  AND `Activity Date` <= CAST(:param.max AS DATE)
  AND (:space_id = 'ALL' OR `Space ID` = :space_id)
GROUP BY ALL
ORDER BY questions DESC
LIMIT 15
""",
    "co_kpi": """
WITH scorecard AS (
  SELECT
    MEASURE(`Total Space Warehouse Cost USD`) AS warehouse_usd,
    MEASURE(`Genie Token Cost USD`) AS token_usd,
    MEASURE(`Questions`) AS questions
  FROM genie_space_adoption_metrics
  WHERE `Activity Date` >= CAST(:param.min AS DATE)
    AND `Activity Date` <= CAST(:param.max AS DATE)
    AND (:space_id = 'ALL' OR `Space ID` = :space_id)
  GROUP BY ALL
)
SELECT
  warehouse_usd,
  token_usd,
  COALESCE(TRY_DIVIDE(warehouse_usd, questions), 0) AS avg_wh_per_q
FROM scorecard
""",
    "co_category": """
SELECT
  `Space Name` AS genie_space,
  `Cost Category` AS genie_cost_category,
  `Cost Class` AS genie_cost_class,
  MEASURE(`Genie Warehouse Cost USD`) AS cost_usd
FROM genie_warehouse_cost_metrics
WHERE `Activity Date` >= CAST(:param.min AS DATE)
  AND `Activity Date` <= CAST(:param.max AS DATE)
  AND (:space_id = 'ALL' OR `Space ID` = :space_id)
GROUP BY ALL
""",
    "co_perq": """
SELECT
  `Space Name` AS space_name,
  `Message ID` AS question,
  MEASURE(`Message Statements`) AS num_statements,
  MEASURE(`Message Warehouse Cost USD`) AS cost_usd
FROM genie_message_cost_metrics
WHERE `Activity Date` >= CAST(:param.min AS DATE)
  AND `Activity Date` <= CAST(:param.max AS DATE)
  AND (:space_id = 'ALL' OR `Space ID` = :space_id)
GROUP BY ALL
ORDER BY cost_usd DESC
LIMIT 25
""",
    "co_token": """
SELECT
  `Space Name` AS space_name,
  MEASURE(`Genie Token DBUs`) AS token_dbus,
  MEASURE(`Genie Token Cost USD`) AS token_usd
FROM genie_token_cost_metrics
WHERE `Genie Surface` = 'GENIE_AGENTS'
  AND `Space Name` IS NOT NULL
  AND `Usage Date` >= CAST(:param.min AS DATE)
  AND `Usage Date` <= CAST(:param.max AS DATE)
  AND (:space_id = 'ALL' OR `Space ID` = :space_id)
GROUP BY ALL
ORDER BY token_dbus DESC
""",
    "tk_kpi": """
SELECT
  MEASURE(`Genie Token DBUs`) AS dbus,
  MEASURE(`Genie Token Cost USD`) AS usd,
  MEASURE(`Free Token DBUs`) AS free_dbus,
  MEASURE(`Paid Token DBUs`) AS paid_dbus
FROM genie_token_cost_metrics
WHERE `Usage Date` >= CAST(:param.min AS DATE) AND `Usage Date` <= CAST(:param.max AS DATE)
GROUP BY ALL
""",
    "tk_product": """
SELECT
  `Genie Surface` AS genie_surface,
  MEASURE(`Genie Token DBUs`) AS dbus,
  MEASURE(`Genie Token Cost USD`) AS usd,
  MEASURE(`Active Token Users`) AS users
FROM genie_token_cost_metrics
WHERE `Usage Date` >= CAST(:param.min AS DATE) AND `Usage Date` <= CAST(:param.max AS DATE)
GROUP BY ALL
""",
    "tk_tier": """
SELECT `Tier` AS tier, MEASURE(`Genie Token DBUs`) AS dbus
FROM genie_token_cost_metrics
WHERE `Usage Date` >= CAST(:param.min AS DATE) AND `Usage Date` <= CAST(:param.max AS DATE)
GROUP BY ALL
""",
    "tk_user": """
SELECT
  `User` AS user_email,
  MEASURE(`Genie Token DBUs`) AS dbus,
  MEASURE(`Genie Token Cost USD`) AS usd
FROM genie_token_cost_metrics
WHERE `Usage Date` >= CAST(:param.min AS DATE) AND `Usage Date` <= CAST(:param.max AS DATE)
GROUP BY ALL
ORDER BY dbus DESC
LIMIT 20
""",
    "tk_channel": """
SELECT `Genie Channel` AS genie_channel, MEASURE(`Genie Token DBUs`) AS dbus
FROM genie_token_cost_metrics
WHERE `Usage Date` >= CAST(:param.min AS DATE) AND `Usage Date` <= CAST(:param.max AS DATE)
GROUP BY ALL
""",
    "tk_trend": """
SELECT
  `Usage Date` AS day,
  `Genie Surface` AS genie_surface,
  MEASURE(`Genie Token Cost USD`) AS usd,
  MEASURE(`Genie Token DBUs`) AS dbus
FROM genie_token_cost_metrics
WHERE `Usage Date` >= CAST(:param.min AS DATE) AND `Usage Date` <= CAST(:param.max AS DATE)
GROUP BY ALL
ORDER BY day
""",
}

VECTOR_DATASET = {
    "name": "vs_usage",
    "displayName": "vector_search_usage",
    "queryLines": [
        line + "\n"
        for line in """SELECT
  `Endpoint Name` AS endpoint_name,
  `SKU Name` AS sku_name,
  `Usage Date` AS usage_date,
  `Workspace Name` AS workspace_name,
  `Attribution Status` AS attribution_status,
  MEASURE(`Vector Search DBUs`) AS dbus,
  MEASURE(`Vector Search Cost USD`) AS dollars
FROM vector_search_cost_metrics
GROUP BY ALL""".splitlines()
    ],
}


def query_lines(sql: str) -> list[str]:
    return [line + "\n" for line in sql.strip().splitlines()]


def replace_strings(value: Any, replacements: dict[str, str]) -> Any:
    if isinstance(value, str):
        for old, new in replacements.items():
            value = value.replace(old, new)
        return value
    if isinstance(value, list):
        return [replace_strings(item, replacements) for item in value]
    if isinstance(value, dict):
        return {key: replace_strings(item, replacements) for key, item in value.items()}
    return value


def vector_page(model_page: dict[str, Any]) -> dict[str, Any]:
    page = replace_strings(
        copy.deepcopy(model_page),
        {
            "475d4e3a": "vector-search",
            "Models": "Vector Search",
            "75376ae2": "vs_usage",
            "model-name": "vector-endpoint-name",
            "entity_name": "endpoint_name",
            "Model Name": "Vector Search Endpoint",
            "model name": "endpoint name",
            "Model views by workspace": "Vector Search cost by endpoint",
            "View trends by workspaces": "Vector Search cost trend",
        },
    )
    page["name"] = "vector-search"
    page["displayName"] = "Vector Search"

    for item in page["layout"]:
        widget = item["widget"]
        widget_name = widget["name"]
        if widget_name == "total-views":
            widget["name"] = "vector-search-cost"
            widget["queries"][0]["query"]["fields"] = [
                {"name": "sum(dollars)", "expression": "SUM(`dollars`)"}
            ]
            widget["spec"]["encodings"]["value"]["fieldName"] = "sum(dollars)"
            widget["spec"]["frame"]["title"] = "Vector Search Cost (USD)"
        elif widget_name == "number-of-inferences":
            widget["name"] = "vector-search-dbus"
            widget["queries"][0]["query"]["fields"] = [
                {"name": "sum(dbus)", "expression": "SUM(`dbus`)"}
            ]
            widget["queries"][0]["query"]["disaggregated"] = False
            widget["spec"]["encodings"]["value"]["fieldName"] = "sum(dbus)"
            widget["spec"]["frame"]["title"] = "Vector Search DBUs"
        elif widget_name == "view-trends-by-workspaces":
            query = widget["queries"][0]["query"]
            query["fields"] = [
                {"name": "workspace_name", "expression": "`workspace_name`"},
                {
                    "name": "monthly(usage_date)",
                    "expression": 'DATE_TRUNC("MONTH", `usage_date`)',
                },
                {"name": "sum(dollars)", "expression": "SUM(`dollars`)"},
            ]
            widget["spec"]["encodings"]["y"]["fieldName"] = "sum(dollars)"
            widget["spec"]["encodings"]["y"]["displayName"] = "Cost (USD)"
            widget["spec"]["frame"]["title"] = "Vector Search cost trend"
        elif widget_name == "model-views-by-workspace":
            widget["name"] = "vector-search-cost-by-endpoint"
            query = widget["queries"][0]["query"]
            query["fields"] = [
                {"name": "sku_name", "expression": "`sku_name`"},
                {"name": "sum(dollars)", "expression": "SUM(`dollars`)"},
                {"name": "endpoint_name", "expression": "`endpoint_name`"},
            ]
            spec = widget["spec"]
            spec["encodings"]["x"]["fieldName"] = "sum(dollars)"
            spec["encodings"]["x"]["displayName"] = "Cost (USD)"
            spec["encodings"]["y"]["fieldName"] = "endpoint_name"
            spec["encodings"]["y"]["displayName"] = "Endpoint"
            spec["encodings"]["color"]["fieldName"] = "sku_name"
            spec["frame"]["title"] = "Vector Search cost by endpoint and SKU"
    return page


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("dashboard", type=Path)
    args = parser.parse_args()

    dashboard = json.loads(args.dashboard.read_text())
    datasets = {dataset["name"]: dataset for dataset in dashboard["datasets"]}
    missing = sorted(set(DATASET_SQL) - set(datasets))
    if missing:
        raise ValueError(f"Dashboard is missing expected datasets: {missing}")

    for name, sql in DATASET_SQL.items():
        datasets[name]["queryLines"] = query_lines(sql)
        datasets[name].pop("catalog", None)
        datasets[name].pop("schema", None)

    if "vs_usage" in datasets:
        datasets["vs_usage"].update(VECTOR_DATASET)
    else:
        dashboard["datasets"].append(VECTOR_DATASET)

    model_page = next(page for page in dashboard["pages"] if page["displayName"] == "Models")
    vector_page_definition = vector_page(model_page)
    vector_page_index = next(
        (
            index
            for index, page in enumerate(dashboard["pages"])
            if page.get("name") == "vector-search"
        ),
        None,
    )
    if vector_page_index is None:
        dashboard["pages"].append(vector_page_definition)
    else:
        dashboard["pages"][vector_page_index] = vector_page_definition

    for page in dashboard["pages"]:
        for layout_item in page.get("layout", []):
            widget = layout_item.get("widget", {})
            if not any(
                query.get("query", {}).get("datasetName") == "co_perq"
                for query in widget.get("queries", [])
            ):
                continue
            spec = widget.get("spec", {})
            if spec.get("widgetType") == "filter-date-range-picker":
                spec.setdefault("frame", {})["title"] = "Date Range"
                continue
            if spec.get("widgetType") == "filter-single-select":
                spec.setdefault("frame", {})["title"] = "Genie Space"
                continue
            relabelled = False
            for column in spec.get("encodings", {}).get("columns", []):
                if column.get("fieldName") == "question":
                    column["title"] = "Message ID"
                    relabelled = True
            if relabelled and "frame" in spec:
                spec["frame"]["title"] = "Most Expensive Messages"

    args.dashboard.write_text(json.dumps(dashboard, indent=1) + "\n")
    print(
        f"Migrated {len(DATASET_SQL)} datasets and ensured the Vector Search page "
        f"in {args.dashboard}"
    )


if __name__ == "__main__":
    main()
