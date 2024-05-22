#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

CURRENT_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(git -C "${CURRENT_SCRIPT_DIR}" rev-parse --show-toplevel)"

HEADER_TEMPLATE=$(cat $CURRENT_SCRIPT_DIR/license-header.txt)
AUTHOR="Binary Birds Kft"
YEAR=$(date +%Y)
PATHS_WITH_INVALID_HEADER=( )

read -ra PATHS_TO_CHECK_FOR_LICENSE <<< "$( \
    git -C "${REPO_ROOT}" ls-files -z \
        ":(exclude).*" \
        ":(exclude)*.txt" \
        ":(exclude)*.sh" \
        ":(exclude)*.html" \
        ":(exclude)*.yaml" \
        ":(exclude)Package.swift" \
  | xargs -0 \
)"

for FILE_PATH in "${PATHS_TO_CHECK_FOR_LICENSE[@]}"; do
    FILE_BASENAME=$(basename -- "${FILE_PATH}")
    FILE_EXTENSION="${FILE_BASENAME##*.}"

    case "${FILE_EXTENSION}" in
        swift) EXPECTED_HEADER=$(sed -e 's|@@|//|g' <<<"${HEADER_TEMPLATE}") ;;
        yml) EXPECTED_HEADER=$(sed -e 's|@@|##|g' <<<"${HEADER_TEMPLATE}") ;;
        sh) EXPECTED_HEADER=$(cat <(echo '#!/usr/bin/env bash') <(sed -e 's|@@|##|g' <<<"${HEADER_TEMPLATE}")) ;;
        *) fatal "Unsupported file extension for file (exclude or update this script): ${FILE_PATH}" ;;
    esac

    EXPECTED_HEADER=$(sed "s/{FILE}/${FILE_BASENAME}/" <<< "${EXPECTED_HEADER}")
    EXPECTED_HEADER=$(sed "s/{AUTHOR}/$AUTHOR/" <<< "${EXPECTED_HEADER}")
    EXPECTED_HEADER=$(sed "s/{YEAR}/$YEAR/" <<< "${EXPECTED_HEADER}")
    
    EXPECTED_HEADER_LINECOUNT=$(wc -l <<<"${EXPECTED_HEADER}")
    FILE_HEADER=$(head -n "${EXPECTED_HEADER_LINECOUNT}" "${FILE_PATH}")

    if ! diff -u \
        --label "Expected header" <(echo "${FILE_HEADER}") \
        --label "${FILE_PATH}" <(echo "${EXPECTED_HEADER}")
    then
        PATHS_WITH_INVALID_HEADER+=("${FILE_PATH} ")
    fi
done

if [ "${#PATHS_WITH_INVALID_HEADER[@]}" -gt 0 ]; then
    fatal "❌ Found invalid license header in files: ${PATHS_WITH_INVALID_HEADER[*]}."
fi

log "✅ Found no files with invalid license header."
