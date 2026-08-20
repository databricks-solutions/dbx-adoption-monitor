# Repo state & next actions

**This is the single source of truth for where this repo stands and what to do next.**
If you are an AI agent or a new contributor, read this first. Keep it current: when you finish
something here, update this file in the same change.

Last updated: 2026-08-20.

---

## What this is

`dbx-adoption-monitor` is a Databricks Solution accelerator that analyses adoption and **cost
observability** across AI/BI Dashboards, Genie Spaces, Apps, and Model Serving — an out-of-the-box
bundle of crawl notebooks, medallion data models, cost facts, and an AI/BI dashboard.

It deploys as a Databricks Asset Bundle (`databricks.yml` + `deployment_resources/`): a job crawls
workspace metadata via the SDK, SQL models build cost/usage facts from `system.*` tables, and the
`.lvdash.json` dashboard renders them.

## Current state

The **v3 baseline** has been ported in from the working repo (`aibi-adoption-dashboard`) and
validated live. It includes:

- **Crawl** (`src/01_get_metadata.ipynb`): lists Genie spaces/conversations/messages, dashboards,
  models, serving endpoints, and apps into `adb_*` tables (stateless full rebuild each run).
- **Genie medallion cost-observability model** + **multi-asset cost facts** (`src/02_*.sql`):
  serving, vector search, apps, plus Genie warehouse + token cost. See
  `docs/data-model-and-cost-attribution.md` for the cost-attribution reference (what reconciles and
  what does not).
- **Dashboard** (`src/dashboards/lh_adoption_dashboard.lvdash.json`): 8 pages (Dashboards, Apps,
  Models, 4× Genie, Global Filters).
- **Tests** (`tests/`): pytest config checks + SQL `assert_true` fixtures (grain uniqueness,
  non-negativity, NOT-NULL invariants).

**Data-correctness fixes already landed** (validated against live billing on a test workspace —
each cost fact reconciles exactly to `system.billing.usage`):
- Apps & Vector Search: eliminated NULL billing-line buckets.
- Serving: endpoint-grain cost redesign — reconciles ~100% (was ~4% undercaptured).
- `adb_apps` crawl: fixed the empty-table bug (flattened the Apps SDK status fields).

---

## Release-readiness cleanup (do before any public push)

These are known, required cleanups for a public Solution. Each is a concrete action:

- [ ] **De-hardcode the catalog/schema** in two dashboard datasets (`apps_views`, `uc_models` in the
      `.lvdash.json` — grep `field_eng_slc`). Use the bundle `dataset_catalog` / `dataset_schema`
      variables like every other dataset.
- [ ] **Genericize internal references** left over from the source workspace: `field_eng_slc`,
      `e2-demo`, any workspace-specific IDs — in `docs/v3-system-table-validation.md`,
      `docs/data-model-and-cost-attribution.md`, and this file's roadmap section.
- [ ] **Fix the relocated README disclaimer**: `docs/data-model-and-cost-attribution.md` carries the
      old "not endorsed by or affiliated with Databricks" wording — wrong for an official
      `databricks-solutions` repo. Remove/replace.
- [ ] **Generic bundle defaults**: confirm `deployment_resources/variables.yml` defaults are generic
      (schema placeholder; the warehouse `lookup` name must exist in the target workspace or be
      overridden at deploy).
- [ ] **Confirm governance files** (`README.md`, `LICENSE.md`, `NOTICE.md`, `CODEOWNERS.txt`,
      `SECURITY.md`) are correct and complete for the Solution (these were kept from this repo, not
      overwritten by the port).

---

## Upgrade roadmap

Four sequenced, independently-shippable workstreams. **Do them in order** — each unblocks the next:

```
Part 1 (rename) ─► Part 2 (crawl perf/incremental) ─► Part 3 (semantic layer) ─► Part 4 (dashboard)
```

### Part 1 — Asset name normalisation
Consistent, cloud-neutral, self-describing names in one schema, with real metadata. **Do first:** the
pipeline is a stateless full rebuild, so a rename is code-only + rerun (no data migration); once
Part 2 adds watermark state it gets expensive.
- Three inconsistent conventions today: `adb_*` (crawl; `adb` misreads as *Azure Databricks* — it
  means *Adoption Dashboard*), `mvFact*` (cost; `mv` implies materialized view but these are plain
  Delta tables), and `dbsql_cost_per_query_table` / `genie_cost_per_message_table` (redundant
  `_table` suffix). Plus 8 hash-named dashboard datasets (`e2b9e81f`, …).
- **Rule:** flat, short, descriptive names by default; `dim_`/`fact_` only where the object genuinely
  is a dimension or fact. Applied honestly: `dim_*` for entity catalogs (genie_spaces, dashboards,
  apps, models, serving_endpoints); `fact_*` for grain+measure tables (serving_usage,
  vector_search_cost, app_usage, genie_usage, genie_token_cost, dashboard_usage, dbsql_cost_per_query,
  genie_cost_per_message); flat for bridge/detail/view (genie_conversations, genie_messages,
  genie_message_statements [bridge], genie_message_comments, genie_cost_by_category [view]).
- Land everything in one schema (`adoption` vs `dbx_adoption` — decide; lean `adoption`). Add
  table/column `COMMENT`s to the crawl tables (none today). Rename atomically across the crawl
  notebook, all `src/02_*.sql` (reads AND CREATE targets), and dashboard dataset queries — a partial
  rename breaks joins. This is a **breaking change** — see Migration below.

### Part 2 — Crawl & pipeline performance
Stop rebuilding everything from scratch; make large-metastore runs tractable.
- Everything is `CREATE OR REPLACE` / `INSERT OVERWRITE`; `lookback_days` defaults to 365 → cost facts
  re-scan a year of `system.*` each run. `mvFactGenieUsage` and `mvFactDashboardUsage` hardcode a
  180-day window (not wired to `lookback_days`).
- The crawl notebook is the wall-clock long pole: a full run on a busy workspace sat 67+ min in
  `Ingest_Metadata`, dominated by per-item permission fan-outs (models/endpoints/apps) and the Genie
  conversation walk. `adb_apps` is the **last** crawl cell, so a slow earlier section blocks it.
- Tasks: incremental load via a `pipeline_watermarks` table + idempotent `MERGE` (needs Part 1's
  stable names); wire `lookback_days` into the two 180-day facts and standardise `INTERVAL` →
  `date_sub`; split the monolithic crawl notebook into independent, retryable tasks so one slow
  section doesn't block the rest; materialise `genie_cost_by_category` (currently an unmaterialized
  view that `LIKE`-matches multi-KB `statement_text` on every dashboard load).

### Part 3 — Semantic layer
A governed measure layer (UC Metric Views) over the *stable* facts, so measures are named, reusable,
re-aggregation-safe, and discoverable by Genie One and external BI.
- UC Metric Views v1.1 (verify at build time; require DBR 17.2+/serverless). Add
  `CREATE OR REPLACE VIEW … WITH METRICS LANGUAGE YAML` wrappers over the facts (start with the clean
  single-source ones: serving/vector_search/app usage). Define measures + dimensions with
  `display_name`, `format`, `synonyms`. Deploy as views alongside the facts (zero extra compute).
- **Do NOT** rewrite the multi-source KPI datasets (`ov_kpi`, `co_kpi`, `ov_leaderboard`, …) as metric
  views — they join 3–4 sources, outside the single-source metric-view model. Metric views are
  additive, not a replacement. Hands-on check: `MEASURE(...)` in a dashboard dataset `queryLines`.

### Part 4 — Dashboard refresh + performance
Modernise the AI/BI dashboard and make it fast — **largely solved by Part 3**: point datasets at
(materialized) metric views instead of re-running heavy CTEs each load.
- Repoint datasets at the metric views; materialise hot ones (subject to the parameterized-MV
  limitation). Add the missing Vector Search page (fact exists, no page). Adopt richer widgets
  (`period`/`target` counter encodings, area for token trend, combo for DBU-vs-$, heatmap). Verify
  dataset cross-filtering JSON via a `bundle generate` diff. Confirm the Part-1 renames + de-hardcode
  are reflected.

---

## Migration ("If you're migrating")

Parts 1 (rename) and the de-hardcode are intentionally **not backwards compatible** — expected for a
major overhaul. The README must ship an "If you're migrating" section before those land. Because the
pipeline is stateless, migration is: redeploy the new bundle → rerun the job (new-named tables
appear) → repoint any *custom* downstream queries/dashboards built on the old names → drop the old
tables. The bundled dashboard moves with the repo, so most users only touch their own artifacts.

---

## Where things live

| Path | What |
|---|---|
| `databricks.yml`, `deployment_resources/` | Asset Bundle: job, dashboard, variables |
| `src/01_get_metadata.ipynb` | Metadata crawl (SDK) → `adb_*` tables |
| `src/02_*.sql` | Cost/usage facts + `genie_cost_categorised` view |
| `src/dashboards/lh_adoption_dashboard.lvdash.json` | AI/BI dashboard |
| `src/standalone_resources/` | Standalone deep-dive notebooks |
| `tests/` | pytest config checks + SQL assert fixtures |
| `docs/data-model-and-cost-attribution.md` | Cost-attribution reference (relocated from the source README) |
| `docs/v3-system-table-validation.md` | `system.*` column/type reference for the SQL models |
| `scripts/validate_system_tables.py` | Regenerates the system-table validation doc |

## Provenance
Ported 2026-08-20 from the working repo `Dynosphere/aibi-adoption-dashboard` at its released v3 line;
the cost/crawl fixes were validated against live billing on a test workspace (each fact reconciles
exactly to `system.billing.usage`). Governance files here were preserved (not overwritten) during the
port.
