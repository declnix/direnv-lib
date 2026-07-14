#!/usr/bin/env sh
set -eu

repo_url="${DIRENV_LIB_REPO_URL:-https://github.com/declnix/direnv-lib.git}"
target_dir="${DIRENV_LIB_DIR:-"$HOME/.config/direnv"}"
git_dir="$target_dir/.git"

mkdir -p "$target_dir"

if [ -e "$git_dir" ] && ! git --git-dir="$git_dir" rev-parse --is-bare-repository >/dev/null 2>&1; then
  echo "error: $git_dir exists but is not a bare Git repository" >&2
  exit 1
fi

if [ ! -e "$git_dir" ]; then
  git clone --bare "$repo_url" "$git_dir"
fi

git --git-dir="$git_dir" --work-tree="$target_dir" config status.showUntrackedFiles normal
git --git-dir="$git_dir" --work-tree="$target_dir" config core.bare false
git --git-dir="$git_dir" --work-tree="$target_dir" checkout

cat <<EOF
direnv-lib is installed at:
  $target_dir

Git metadata:
  $git_dir

Existing files were not added or removed.

Use:
  git -C "$target_dir" status
EOF
