#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version=$(tr -d '[:space:]' <"$project_root/docs/agent-toolkit/VERSION")
downloads_root="$project_root/priv/static/downloads"
output_dir="$downloads_root/agent-toolkit"
releases_root="$downloads_root/agent-toolkit-releases"
staging_dir=$(mktemp -d "${TMPDIR:-/tmp}/alchemistdrops-agent-toolkit.XXXXXX")
artifacts_dir="$staging_dir/artifacts"
incoming_dir=""
pointer_tmp=""
skills="
ecto-development
elixir-development
phoenix-authentication
phoenix-development
phoenix-js-hooks
phoenix-liveview-testing
phoenix-liveview
"

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

is_allowed_skill() {
  case "$1" in
    ecto-development | elixir-development | phoenix-authentication | phoenix-development | phoenix-js-hooks | phoenix-liveview-testing | phoenix-liveview)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

cleanup() {
  if [ -n "$pointer_tmp" ] && [ -L "$pointer_tmp" ]; then
    rm -- "$pointer_tmp"
  fi

  if [ -n "$incoming_dir" ] && [ -d "$incoming_dir" ]; then
    rm -rf -- "$incoming_dir"
  fi

  rm -rf -- "$staging_dir"
}

trap cleanup EXIT INT TERM

for skill_name in $skills; do
  skill_dir="$project_root/.agents/skills/$skill_name"
  skill_file="$skill_dir/SKILL.md"

  [ -d "$skill_dir" ] || fail "Missing skill directory: $skill_dir"
  [ ! -L "$skill_dir" ] || fail "Refusing symlinked skill directory: $skill_dir"
  [ -f "$skill_file" ] || fail "Missing skill file: $skill_file"
  [ ! -L "$skill_file" ] || fail "Refusing symlinked skill file: $skill_file"

  unexpected_file=$(find "$skill_dir" -mindepth 1 -maxdepth 1 ! -name SKILL.md -print -quit)
  [ -z "$unexpected_file" ] || fail "Unexpected skill entry: $unexpected_file"
done

for skill_dir in "$project_root"/.agents/skills/*; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")

  is_allowed_skill "$skill_name" || fail "Skill is not in the publishing allowlist: $skill_name"
done

rules_dir="$project_root/.codex/rules"
rule_file="$rules_dir/elixir-safety.rules"

[ -f "$rule_file" ] || fail "Missing safety rule: $rule_file"
[ ! -L "$rule_file" ] || fail "Refusing symlinked safety rule: $rule_file"

unexpected_rule=$(find "$rules_dir" -mindepth 1 -maxdepth 1 ! -name elixir-safety.rules -print -quit)
[ -z "$unexpected_rule" ] || fail "Unexpected rules entry: $unexpected_rule"
[ -n "$version" ] || fail "Toolkit version cannot be empty"

for required_file in \
  "$project_root/AGENTS.md" \
  "$project_root/docs/agent-toolkit/README.md" \
  "$project_root/docs/agent-toolkit/LICENSE.txt" \
  "$project_root/docs/agent-toolkit/VERSION"; do
  [ -f "$required_file" ] || fail "Missing package source: $required_file"
  [ ! -L "$required_file" ] || fail "Refusing symlinked package source: $required_file"
done

mkdir -p "$artifacts_dir"

for skill_name in $skills; do
  skill_dir="$project_root/.agents/skills/$skill_name"
  package_dir="$staging_dir/$skill_name"

  mkdir -p "$package_dir"
  cp "$skill_dir/SKILL.md" "$package_dir/SKILL.md"
  cp "$project_root/docs/agent-toolkit/LICENSE.txt" "$package_dir/LICENSE.txt"
  find "$package_dir" -exec touch -t 202001010000 {} +

  (
    cd "$staging_dir"
    zip -q -X -r "$artifacts_dir/$skill_name-v$version.zip" "$skill_name"
  )

  rm -rf -- "$package_dir"
done

rules_root="$staging_dir/rules-package"
mkdir -p "$rules_root/.codex/rules"
cp "$rule_file" "$rules_root/.codex/rules/"
cp "$project_root/docs/agent-toolkit/LICENSE.txt" "$rules_root/LICENSE.txt"
find "$rules_root" -exec touch -t 202001010000 {} +

(
  cd "$rules_root"
  zip -q -X -r "$artifacts_dir/elixir-safety-rules-v$version.zip" ".codex" "LICENSE.txt"
)

rm -rf -- "$rules_root"

toolkit_root="$staging_dir/alchemistdrops-agent-toolkit"
mkdir -p "$toolkit_root/.agents/skills" "$toolkit_root/.codex/rules"

for skill_name in $skills; do
  mkdir -p "$toolkit_root/.agents/skills/$skill_name"
  cp \
    "$project_root/.agents/skills/$skill_name/SKILL.md" \
    "$toolkit_root/.agents/skills/$skill_name/SKILL.md"
done

cp "$rule_file" "$toolkit_root/.codex/rules/elixir-safety.rules"
cp "$project_root/AGENTS.md" "$toolkit_root/AGENTS.md"
cp "$project_root/docs/agent-toolkit/README.md" "$toolkit_root/README.md"
cp "$project_root/docs/agent-toolkit/LICENSE.txt" "$toolkit_root/LICENSE.txt"
cp "$project_root/docs/agent-toolkit/VERSION" "$toolkit_root/VERSION"
find "$toolkit_root" -exec touch -t 202001010000 {} +

(
  cd "$staging_dir"
  zip -q -X -r \
    "$artifacts_dir/alchemistdrops-agent-toolkit-v$version.zip" \
    "alchemistdrops-agent-toolkit"
)

for archive in "$artifacts_dir"/*.zip; do
  unzip -tq "$archive" >/dev/null || fail "Invalid archive: $archive"
done

release_checksum=$(
  cd "$artifacts_dir"
  cksum ./*.zip | LC_ALL=C sort | cksum | awk '{print $1}'
)
release_name="v$version-$release_checksum"
release_dir="$releases_root/$release_name"

mkdir -p "$releases_root"

if [ -e "$output_dir" ] && [ ! -L "$output_dir" ]; then
  fail "Expected the public toolkit path to be a symlink: $output_dir"
fi

if [ ! -d "$release_dir" ]; then
  incoming_dir=$(mktemp -d "$releases_root/.incoming.XXXXXX")

  for archive in "$artifacts_dir"/*.zip; do
    archive_name=$(basename "$archive")
    cp "$archive" "$incoming_dir/$archive_name"
  done

  for archive in "$incoming_dir"/*.zip; do
    unzip -tq "$archive" >/dev/null || fail "Invalid publish candidate: $archive"
  done

  printf '%s\n' "$release_name" >"$incoming_dir/.alchemistdrops-agent-toolkit-release"
  chmod 0755 "$incoming_dir"
  find "$incoming_dir" -maxdepth 1 -type f -exec chmod 0644 {} +
  mv "$incoming_dir" "$release_dir"
  incoming_dir=""
fi

chmod 0755 "$release_dir"
find "$release_dir" -maxdepth 1 -type f -exec chmod 0644 {} +

pointer_tmp="$downloads_root/.agent-toolkit-current.$$"
ln -s "agent-toolkit-releases/$release_name" "$pointer_tmp"

if [ -L "$output_dir" ]; then
  if mv -Tf "$pointer_tmp" "$output_dir" 2>/dev/null; then
    pointer_tmp=""
  elif mv -hf "$pointer_tmp" "$output_dir"; then
    pointer_tmp=""
  else
    fail "Could not atomically publish the toolkit release pointer"
  fi
else
  mv "$pointer_tmp" "$output_dir"
  pointer_tmp=""
fi

for old_release in "$releases_root"/v*; do
  [ -d "$old_release" ] || continue
  [ "$old_release" = "$release_dir" ] && continue

  if [ -f "$old_release/.alchemistdrops-agent-toolkit-release" ]; then
    rm -rf -- "$old_release"
  fi
done
