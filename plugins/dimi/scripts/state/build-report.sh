#!/usr/bin/env bash
# What the repository already has for a report or dashboard, found mechanically so the build-report skill
# reuses it instead of guessing: manifests, chart and table libraries in the lockfiles, component and token
# files, the data layer, tenant and permission helpers, existing metric or report code, the SCALE line,
# test runners. Called from the skill's `!` injection as  bash build-report.sh  — prints labelled lines; always exits 0.
. "$(dirname "$0")/../lib.sh"

block() { echo "- $1:"; if [ -n "$2" ]; then printf '%s\n' "$2" | sed 's/^/    /'; else echo "    none found"; fi; }

T=$(top)
if [ -z "$T" ]; then echo "- Repository: not a git repository; read the manifests by hand"; exit 0; fi
cd "$T" || exit 0
FILES=$(git -c core.quotePath=false ls-files 2>/dev/null)
SRC=$(printf '%s\n' "$FILES" | grep -vE '(^|/)(node_modules|dist|build|vendor|\.next|coverage|generated)/|\.(lock|min\.js|map|snap)$|lock\.(json|yaml)$')

echo "- Repository: $(basename "$T") · HEAD: $(git rev-parse --short HEAD 2>/dev/null || echo none) · branch: $(branch_name)"
block "Manifests" "$(printf '%s\n' "$FILES" | grep -E '(^|/)(package\.json|pyproject\.toml|requirements[^/]*\.txt|go\.mod|Cargo\.toml|pom\.xml|build\.gradle(\.kts)?|Gemfile|composer\.json)$' | cap 20)"

# Dependencies that matter for a report: charts, tables, dates, data layer, exports. Read from the manifests only
# (names only): a lockfile would also list transitive packages, which are not the repository's choice.
DEPS=$( { printf '%s\n' "$FILES" | grep -E '(^|/)(package\.json|pyproject\.toml|requirements[^/]*\.txt|go\.mod|Cargo\.toml|Gemfile|composer\.json)$' | head -40 | tr '\n' '\0' | xargs -0 -r cat 2>/dev/null; } | tr -d '"' )
match_deps() { local m; m=$(printf '%s\n' "$DEPS" | grep -oiE -- "$1" | tr 'A-Z' 'a-z' | sed -E 's/^[^a-z@]+//; s/[^a-z0-9/.-]+$//' | sort -u | tr '\n' ' '); printf '%s' "${m:-none found}"; }
echo "- Chart libraries: $(match_deps '(^|[^a-z0-9-])(recharts|chart\.js|react-chartjs-2|echarts|echarts-for-react|@nivo/[a-z-]+|victory|visx|@visx/[a-z-]+|d3|plotly(\.js|-js)?|apexcharts|highcharts|@mui/x-charts|@tremor/react|vega(-lite)?|observablehq/plot|lightweight-charts|matplotlib|plotly|altair|bokeh|seaborn|streamlit|dash|gradio|panel)([^a-z0-9-]|$)' | sed 's/^ *//')"
echo "- Table and grid libraries: $(match_deps '(^|[^a-z0-9-])(@tanstack/react-table|@tanstack/table-core|ag-grid-[a-z]+|@mui/x-data-grid|react-data-grid|handsontable|@glideapps/glide-data-grid|mantine-react-table|material-react-table)([^a-z0-9-]|$)')"
echo "- Component libraries and styling: $(match_deps '(^|[^a-z0-9-])(@mui/material|@mantine/core|@chakra-ui/react|antd|@radix-ui/[a-z-]+|@headlessui/react|@shadcn/ui|shadcn|tailwindcss|styled-components|@emotion/react|@vanilla-extract/css|@stitches/react|bootstrap|primereact|@fluentui/react|@carbon/react)([^a-z0-9-]|$)')"
echo "- Dates, numbers, exports: $(match_deps '(^|[^a-z0-9-])(date-fns|dayjs|luxon|moment|@internationalized/date|@js-temporal/polyfill|numeral|intl-messageformat|papaparse|exceljs|xlsx|sheetjs|jspdf|pdfkit|@react-pdf/renderer|puppeteer|playwright|openpyxl|pandas|polars|weasyprint|reportlab|csv-writer|fast-csv)([^a-z0-9-]|$)')"
echo "- Data layer: $(match_deps '(^|[^a-z0-9-])(prisma|@prisma/client|drizzle-orm|kysely|knex|typeorm|sequelize|mikro-orm|@mikro-orm/core|mongoose|pg|postgres|mysql2|better-sqlite3|sqlalchemy|django|djangorestframework|peewee|tortoise-orm|sqlmodel|psycopg[0-9]?|asyncpg|clickhouse-connect|@clickhouse/client|duckdb|@duckdb/node-api|snowflake-sdk|@google-cloud/bigquery|google-cloud-bigquery|redis|ioredis|bullmq|celery|@tanstack/react-query|swr|@apollo/client|urql|trpc|@trpc/server)([^a-z0-9-]|$)')"
echo "- Scheduling and delivery: $(match_deps '(^|[^a-z0-9-])(node-cron|cron|bullmq|agenda|bree|@temporalio/[a-z]+|celery|apscheduler|dramatiq|rq|nodemailer|resend|@sendgrid/mail|postmark|mailgun(-js)?|ses|@aws-sdk/client-ses|sendgrid|django-anymail)([^a-z0-9-]|$)')"

block "Dashboard-as-code and BI definitions already in the repo" "$(printf '%s\n' "$SRC" | grep -iE '(^|/)(grafana|dashboards?|metabase|superset|looker|lookml|redash|kibana|datadog|monitors?)(/|\.)|\.(lookml|lkml)$|grafana.*\.json$|dashboard.*\.(json|ya?ml)$' | cap 20)"
block "Existing metric, report, dashboard or analytics code (reuse before writing a second definition)" \
  "$(printf '%s\n' "$SRC" | grep -E '\.(ts|tsx|js|jsx|py|go|rs|rb|sql|prisma|vue|svelte)$' | grep -iE '(^|/|[-_.])(metrics?|reports?|reporting|dashboards?|analytics|insights?|stats|statistics|kpis?|charts?|summary|summaries|rollups?|aggregates?|aggregations?|materiali[sz]ed)([-_.]|/|$)' | grep -viE '(^|/)(test|spec|e2e|__tests__)' | cap 30)"
block "Database views, rollups and migrations that aggregate" \
  "$(printf '%s\n' "$SRC" | grep -E '\.(sql|prisma)$|(^|/)migrations?/' | tr '\n' '\0' | xargs -0 -r grep -liE 'materialized view|create view|group by|rollup|summary' 2>/dev/null | cap 15)"
block "Design tokens and theme files" "$(printf '%s\n' "$SRC" | grep -iE '(^|/)[^/]*(tokens?|theme|palette|colou?rs?)[^/]*\.(ts|tsx|js|css|scss|json)$|tailwind\.config\.[a-z]+$' | cap 15)"
block "Shared UI blocks (tables, cards, charts, empty and error states)" \
  "$(printf '%s\n' "$SRC" | grep -iE '(^|/)(components?|ui|design-system|packages/ui)/[^/]*/?[^/]*(table|card|chart|empty|error|skeleton|spinner|banner|stat|tile|kpi|panel|drawer|filter|date-?range|pagination)[^/]*\.(tsx|jsx|vue|svelte)$' | cap 25)"
block "Tenant, permission and auth helpers (every query must go through one)" \
  "$(printf '%s\n' "$SRC" | grep -E '\.(ts|js|py|go|rb)$' | grep -viE '(^|/)(test|spec|e2e|__tests__)' | tr '\n' '\0' | xargs -0 -r grep -lE 'tenant(Id|_id)|org(anization)?(Id|_id)|workspace(Id|_id)|requirePermission|hasPermission|can\(|authorize|@permission_required|IsAuthenticated|row.?level.?security|RLS' 2>/dev/null | cap 15)"
block "Routes, pages and API handlers that already list or aggregate" \
  "$(printf '%s\n' "$SRC" | grep -iE '(^|/)(app|pages|routes|api|views|controllers|handlers)/.*(^|[^A-Za-z0-9_])(list|index|summary|overview|stats|report|dashboard|export)([^A-Za-z0-9_]|$).*\.(tsx|ts|js|py|go|rb)$' | cap 20)"
block "Feature flags and settings" "$(printf '%s\n' "$SRC" | grep -iE '(^|/)[^/]*(flags?|features?|settings|config)[^/]*\.(ts|json|ya?ml|py|toml)$' | grep -viE 'tsconfig|eslint|prettier|jest|vite|next\.config|tailwind' | cap 10)"
block "SCALE line and data rules (CLAUDE.md, AGENTS.md, .claude/rules/)" \
  "$(grep -rnE '^SCALE|^[[:space:]]*-?[[:space:]]*SCALE[[:space:]]*=' CLAUDE.md AGENTS.md .claude/rules 2>/dev/null | cut -c1-200 | cap 5; ls .claude/rules/*.md 2>/dev/null)"
block "Test runners and e2e" "$(printf '%s\n' "$FILES" | grep -E '(^|/)(jest|vitest|playwright|cypress|pytest|karma)\.config\.[a-z]+$|(^|/)(pytest\.ini|conftest\.py|tox\.ini)$' | cap 10)"
echo "- Test files (by name): $(printf '%s\n' "$SRC" | grep -ciE '(^|/)(tests?|__tests__|spec|e2e)(/|$)|\.(test|spec)\.[a-z]+$|_test\.(go|py|rs)$')"
block "Fixtures and seed data (known answers for metric tests)" "$(printf '%s\n' "$SRC" | grep -iE '(^|/)(fixtures?|seeds?|factories|__fixtures__|testdata)/' | cap 10)"
p="$T/.claude/fde-client-profile.md"
if [ -f "$p" ]; then echo "- Client profile: $p (data classes, retention and approvals apply to every number shown)"; else echo "- Client profile: none"; fi
exit 0
