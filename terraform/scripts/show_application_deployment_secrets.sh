#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash terraform/scripts/show_application_deployment_secrets.sh [--terraform-directory PATH]

Reads github_secrets from initialized Terraform state and prints the values
to add as environment secrets in GitHub's Development environment.
EOF
}

terraform_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
while (( $# > 0 )); do
    case "$1" in
        --terraform-directory) (( $# >= 2 )) || { printf 'Missing value for --terraform-directory.\n' >&2; exit 2; }; terraform_directory="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

command -v terraform >/dev/null 2>&1 || { printf 'Terraform was not found on PATH.\n' >&2; exit 1; }
python_command=$(command -v python3 || command -v python || true)
[[ -n "$python_command" ]] || { printf 'Python was not found on PATH. Python is required to read the Terraform JSON output.\n' >&2; exit 1; }
terraform_directory=$(cd "$terraform_directory" && pwd)

if ! secrets_json=$(terraform "-chdir=$terraform_directory" output -json github_secrets); then
    printf 'Could not read the application deployment identity from Terraform state. Initialize the Terraform remote backend first.\n' >&2
    exit 1
fi

printf 'Add these environment secrets in GitHub:\n'
printf 'Repository > Settings > Environments > Development > Environment secrets\n\n'
for name in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID; do
    if ! value=$("$python_command" -c 'import json, sys; print(json.load(sys.stdin)[sys.argv[1]])' "$name" <<<"$secrets_json"); then
        printf 'Terraform output did not contain %s.\n' "$name" >&2
        exit 1
    fi
    [[ -n "$value" ]] || { printf 'Terraform output did not contain %s.\n' "$name" >&2; exit 1; }
    printf '%s = %s\n' "$name" "$value"
done
printf '\nThese values belong only in the Development environment. Do not replace the TF_AZURE_* secrets in the Terraform environment.\n'
