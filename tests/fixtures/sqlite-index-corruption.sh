#!/usr/bin/env bash
set -euo pipefail

for required_command in sqlite3 sha256sum grep cut dd cp rm mktemp; do
  command -v "${required_command}" >/dev/null
done

fixture_root="$(mktemp -d)"

cleanup() {
  if [[ -n "${fixture_root:-}" && -d "${fixture_root}" ]]; then
    rm -r -- "${fixture_root}"
  fi
}

trap cleanup EXIT

source_database="${fixture_root}/source.db"
received_database="${fixture_root}/received.db"
preserved_database="${fixture_root}/received.pre-repair.db"

sqlite3 "${source_database}" <<'SQL'
PRAGMA page_size = 4096;
CREATE TABLE events(
  id INTEGER PRIMARY KEY,
  key_text TEXT NOT NULL,
  payload TEXT NOT NULL
);
CREATE INDEX events_by_key ON events(key_text);
INSERT INTO events(key_text, payload)
VALUES
  ('alpha', 'zulu'),
  ('bravo', 'yankee'),
  ('charlie', 'xray');
SQL

page_size="$(sqlite3 "${source_database}" 'PRAGMA page_size;')"
index_root_page="$(
  sqlite3 "${source_database}" \
    "SELECT rootpage FROM sqlite_schema WHERE name = 'events_by_key';"
)"
index_page_start="$(( (index_root_page - 1) * page_size ))"
index_page_end="$(( index_root_page * page_size ))"
index_value_offset=""

while IFS= read -r candidate_offset; do
  if (( candidate_offset >= index_page_start && candidate_offset < index_page_end )); then
    index_value_offset="${candidate_offset}"
    break
  fi
done < <(LC_ALL=C grep -abo 'alpha' "${source_database}" | cut -d: -f1)

if [[ -z "${index_value_offset}" ]]; then
  echo "Could not locate the fixture value in the index page." >&2
  exit 1
fi

# Keep the index page structurally readable while making one index value
# disagree with its table row. Both values are five bytes.
printf omega |
  dd \
    of="${source_database}" \
    bs=1 \
    seek="${index_value_offset}" \
    conv=notrunc \
    status=none

sqlite3 "${source_database}" ".backup '${received_database}'"
cp -- "${received_database}" "${preserved_database}"

preserved_checksum_before="$(sha256sum "${preserved_database}" | cut -d' ' -f1)"
integrity_before="$(sqlite3 "${received_database}" 'PRAGMA integrity_check;')"

if [[ "${integrity_before}" != *"missing from index events_by_key"* ]]; then
  echo "Expected the received snapshot to report the inconsistent index." >&2
  echo "Actual integrity result: ${integrity_before}" >&2
  exit 1
fi

table_hash_before="$(
  sqlite3 "${received_database}" \
    'SELECT id, key_text, payload FROM events ORDER BY id;' |
    sha256sum |
    cut -d' ' -f1
)"

sqlite3 "${received_database}" 'REINDEX events_by_key;'

integrity_after="$(sqlite3 "${received_database}" 'PRAGMA integrity_check;')"
table_hash_after="$(
  sqlite3 "${received_database}" \
    'SELECT id, key_text, payload FROM events ORDER BY id;' |
    sha256sum |
    cut -d' ' -f1
)"
preserved_checksum_after="$(sha256sum "${preserved_database}" | cut -d' ' -f1)"
preserved_integrity="$(sqlite3 "${preserved_database}" 'PRAGMA integrity_check;')"

[[ "${integrity_after}" == "ok" ]]
[[ "${table_hash_before}" == "${table_hash_after}" ]]
[[ "${preserved_checksum_before}" == "${preserved_checksum_after}" ]]
[[ "${preserved_integrity}" == *"missing from index events_by_key"* ]]

echo "backup: succeeded"
echo "received integrity before repair: ${integrity_before}"
echo "received pre-repair artifact: preserved unchanged"
echo "repair: REINDEX events_by_key"
echo "received integrity after repair: ${integrity_after}"
echo "table rows: unchanged"
