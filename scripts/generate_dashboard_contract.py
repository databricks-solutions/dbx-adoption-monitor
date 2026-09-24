"""Generate a deterministic dashboard dataset/widget migration contract."""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable


SOURCE_RE = re.compile(
    r"\b(?:FROM|JOIN)\s+"
    r"(?P<source>(?:`[^`]+`|[A-Za-z_][\w$]*)(?:\.(?:`[^`]+`|[A-Za-z_][\w$]*)){0,2})",
    re.IGNORECASE,
)


def walk(value: Any) -> Iterable[dict[str, Any]]:
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def query_contract(page: dict[str, Any]) -> dict[str, dict[str, set[str]]]:
    usage: dict[str, dict[str, set[str]]] = defaultdict(
        lambda: {
            "widgets": set(),
            "fields": set(),
            "field_expressions": set(),
            "encoding_fields": set(),
            "parameters": set(),
        }
    )
    for layout_item in page.get("layout", []):
        widget = layout_item.get("widget", {})
        widget_name = widget.get("name", "")
        encoding_fields = {
            node["fieldName"]
            for node in walk(widget.get("spec", {}))
            if isinstance(node.get("fieldName"), str)
        }
        for node in walk(widget):
            dataset_name = node.get("datasetName")
            if not dataset_name:
                continue
            usage[dataset_name]["widgets"].add(widget_name)
            usage[dataset_name]["fields"].update(
                field.get("name", "")
                for field in node.get("fields", [])
                if isinstance(field, dict) and field.get("name")
            )
            usage[dataset_name]["field_expressions"].update(
                f"{field.get('name', '')}={field.get('expression', '')}"
                for field in node.get("fields", [])
                if isinstance(field, dict) and field.get("name")
            )
            usage[dataset_name]["encoding_fields"].update(encoding_fields)
            usage[dataset_name]["parameters"].update(
                parameter.get("name", "")
                for parameter in node.get("parameters", [])
                if isinstance(parameter, dict) and parameter.get("name")
            )
    return usage


def build_contract(dashboard: dict[str, Any]) -> dict[str, Any]:
    usage_by_dataset: dict[str, dict[str, set[str]]] = defaultdict(
        lambda: {
            "pages": set(),
            "widgets": set(),
            "fields": set(),
            "field_expressions": set(),
            "encoding_fields": set(),
            "parameters": set(),
        }
    )
    pages = []
    for page in dashboard.get("pages", []):
        page_usage = query_contract(page)
        pages.append(
            {
                "name": page.get("name"),
                "display_name": page.get("displayName"),
                "widget_count": len(page.get("layout", [])),
                "datasets": sorted(page_usage),
            }
        )
        for dataset_name, usage in page_usage.items():
            target = usage_by_dataset[dataset_name]
            target["pages"].add(page.get("displayName", page.get("name", "")))
            target["widgets"].update(usage["widgets"])
            target["fields"].update(usage["fields"])
            target["field_expressions"].update(usage["field_expressions"])
            target["encoding_fields"].update(usage["encoding_fields"])
            target["parameters"].update(usage["parameters"])

    datasets = []
    for dataset in dashboard.get("datasets", []):
        name = dataset["name"]
        sql = "".join(dataset.get("queryLines", []))
        usage = usage_by_dataset[name]
        datasets.append(
            {
                "name": name,
                "display_name": dataset.get("displayName"),
                "source_objects": sorted(
                    {
                        match.group("source").replace("`", "")
                        for match in SOURCE_RE.finditer(sql)
                        if not match.group("source").startswith("(")
                    }
                ),
                "pages": sorted(usage["pages"]),
                "widget_ids": sorted(usage["widgets"]),
                "required_fields": sorted(usage["fields"]),
                "field_expressions": sorted(usage["field_expressions"]),
                "encoding_fields": sorted(usage["encoding_fields"]),
                "parameters": sorted(usage["parameters"]),
                "query_lines": dataset.get("queryLines", []),
            }
        )

    return {
        "dataset_count": len(datasets),
        "page_count": len(pages),
        "widget_count": sum(page["widget_count"] for page in pages),
        "dataset_widget_binding_count": sum(
            len(dataset["widget_ids"]) for dataset in datasets
        ),
        "pages": pages,
        "datasets": datasets,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("dashboard", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    contract = build_contract(json.loads(args.dashboard.read_text()))
    args.output.write_text(json.dumps(contract, indent=2) + "\n")
    print(
        f"Wrote {contract['dataset_count']} datasets, {contract['page_count']} pages, "
        f"{contract['widget_count']} widgets, and "
        f"{contract['dataset_widget_binding_count']} dataset/widget bindings to {args.output}"
    )


if __name__ == "__main__":
    main()
