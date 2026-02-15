#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE_DIR="${1:-${REPO_ROOT}/_site}"

DASHBOARD_DIR="${REPO_ROOT}/reports/dashboard"
DOCS_DIR="${REPO_ROOT}/docs/generated"
BADGE_DATA_FILE="${REPO_ROOT}/reports/badge-data.json"

if [[ ! -f "${DASHBOARD_DIR}/index.html" ]]; then
  echo "ERROR: Missing dashboard artifact: ${DASHBOARD_DIR}/index.html" >&2
  exit 1
fi

if [[ ! -d "${DOCS_DIR}" ]]; then
  echo "ERROR: Missing docs artifacts directory: ${DOCS_DIR}" >&2
  exit 1
fi

if [[ ! -f "${BADGE_DATA_FILE}" ]]; then
  echo "ERROR: Missing badge artifact: ${BADGE_DATA_FILE}" >&2
  exit 1
fi

rm -rf "${SITE_DIR}"
mkdir -p "${SITE_DIR}"

cp -R "${DASHBOARD_DIR}" "${SITE_DIR}/dashboard"
cp -R "${DOCS_DIR}" "${SITE_DIR}/docs"
cp "${BADGE_DATA_FILE}" "${SITE_DIR}/badge-data.json"

cat > "${SITE_DIR}/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0; url=dashboard/">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>RCD-CUI Dashboard Redirect</title>
</head>
<body>
  <p>Redirecting to <a href="dashboard/">dashboard</a>...</p>
</body>
</html>
HTML

cat > "${SITE_DIR}/docs/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>RCD-CUI Documentation</title>
</head>
<body>
  <h1>RCD-CUI Documentation</h1>
  <ul>
    <li><a href="pi_guide.md">PI Guide</a></li>
    <li><a href="researcher_quickstart.md">Researcher Quickstart</a></li>
    <li><a href="sysadmin_reference.md">Sysadmin Reference</a></li>
    <li><a href="ciso_compliance_map.md">CISO Compliance Map</a></li>
    <li><a href="leadership_briefing.md">Leadership Briefing</a></li>
    <li><a href="glossary_full.md">Full Glossary</a></li>
    <li><a href="crosswalk.csv">Framework Crosswalk (CSV)</a></li>
  </ul>
</body>
</html>
HTML

echo "Assembled site artifacts at: ${SITE_DIR}"
