#!/usr/bin/env bash
#
# git-branch-cleaner/clean-branches.sh
# Lists and removes merged Git branches (local and remote).
# Protects main, master, and develop branches from deletion.
#
# Usage: ./clean-branches.sh [-r] [-n] [-f] [-h]
#

set -euo pipefail

# ─── Defaults ───────────────────────────────────────────────────────────────────
INCLUDE_REMOTE=false
DRY_RUN=false
FORCE=false

# Protected branches (never delete these)
PROTECTED_BRANCHES="main master develop"

# ─── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Functions ──────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Lists and removes Git branches that have been merged into the current branch.
Protects main, master, and develop branches from deletion.

Options:
  -r    Include remote tracking branches
  -n    Dry-run: show what would be deleted without actually deleting
  -f    Force: skip confirmation prompts (delete without asking)
  -h    Show this help message

Examples:
  $(basename "$0")           # Interactive cleanup of local merged branches
  $(basename "$0") -n        # Dry-run: just show merged branches
  $(basename "$0") -r -f     # Force-delete local + remote merged branches
  $(basename "$0") -r -n     # Show all merged branches (local + remote)

Notes:
  - Must be run from inside a Git repository
  - Protected branches (main, master, develop) are never deleted
  - The currently checked-out branch is never deleted
  - Remote branch deletion uses 'git push --delete'
EOF
    exit 0
}

# Check if a branch name is protected
is_protected() {
    local branch="$1"
    for protected in $PROTECTED_BRANCHES; do
        if [[ "$branch" == "$protected" ]]; then
            return 0
        fi
    done
    return 1
}

# Confirm deletion (returns 0 for yes, 1 for no)
confirm_delete() {
    local branch="$1"
    local branch_type="$2"

    if $FORCE; then
        return 0
    fi

    echo -en "  Delete ${branch_type} branch ${CYAN}${branch}${RESET}? [y/N] "
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# ─── Parse arguments ────────────────────────────────────────────────────────────
while getopts ":rnfh" opt; do
    case "$opt" in
        r) INCLUDE_REMOTE=true ;;
        n) DRY_RUN=true ;;
        f) FORCE=true ;;
        h) usage ;;
        \?) echo "Error: Unknown option -$OPTARG" >&2; usage ;;
    esac
done

# ─── Verify we are in a git repo ────────────────────────────────────────────────
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${RED}Error: Not inside a Git repository.${RESET}" >&2
    exit 1
fi

# ─── Get current branch ─────────────────────────────────────────────────────────
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [[ -z "$CURRENT_BRANCH" ]]; then
    echo -e "${RED}Error: Unable to determine current branch (detached HEAD?).${RESET}" >&2
    exit 1
fi

echo -e "${BOLD}Git Branch Cleaner${RESET}"
echo -e "Current branch: ${CYAN}${CURRENT_BRANCH}${RESET}"
echo -e "Protected branches: ${YELLOW}${PROTECTED_BRANCHES}${RESET}"
echo ""

if $DRY_RUN; then
    echo -e "${YELLOW}[DRY-RUN MODE] No branches will be deleted.${RESET}"
    echo ""
fi

# ─── Local merged branches ──────────────────────────────────────────────────────
echo -e "${BOLD}=== Local Merged Branches ===${RESET}"

local_deleted=0
local_skipped=0

# Get merged branches, strip whitespace and the * marker
merged_local=$(git branch --merged 2>/dev/null | sed 's/^[* ]*//' | xargs -n1 2>/dev/null || true)

if [[ -z "$merged_local" ]]; then
    echo "  No merged local branches found."
else
    for branch in $merged_local; do
        # Skip current branch
        if [[ "$branch" == "$CURRENT_BRANCH" ]]; then
            continue
        fi

        # Skip protected branches
        if is_protected "$branch"; then
            echo -e "  ${YELLOW}SKIP${RESET} $branch (protected)"
            ((local_skipped++)) || true
            continue
        fi

        if $DRY_RUN; then
            echo -e "  ${CYAN}WOULD DELETE${RESET} $branch"
            ((local_deleted++)) || true
        else
            if confirm_delete "$branch" "local"; then
                if git branch -d "$branch" &>/dev/null; then
                    echo -e "  ${GREEN}DELETED${RESET} $branch"
                    ((local_deleted++)) || true
                else
                    echo -e "  ${RED}FAILED${RESET} to delete $branch"
                fi
            else
                echo -e "  ${YELLOW}SKIPPED${RESET} $branch"
                ((local_skipped++)) || true
            fi
        fi
    done
fi

echo ""

# ─── Remote merged branches ─────────────────────────────────────────────────────
if $INCLUDE_REMOTE; then
    echo -e "${BOLD}=== Remote Merged Branches ===${RESET}"

    # Fetch latest remote info
    echo "  Fetching remote data..."
    git fetch --prune &>/dev/null || true

    remote_deleted=0
    remote_skipped=0

    # Get remote merged branches
    merged_remote=$(git branch -r --merged 2>/dev/null | sed 's/^[* ]*//' | grep -v '\->' || true)

    if [[ -z "$merged_remote" ]]; then
        echo "  No merged remote branches found."
    else
        for rbranch in $merged_remote; do
            # Extract remote name and branch name
            remote=$(echo "$rbranch" | cut -d'/' -f1)
            branch=$(echo "$rbranch" | cut -d'/' -f2-)

            # Skip protected branches
            if is_protected "$branch"; then
                echo -e "  ${YELLOW}SKIP${RESET} $rbranch (protected)"
                ((remote_skipped++)) || true
                continue
            fi

            # Skip current branch
            if [[ "$branch" == "$CURRENT_BRANCH" ]]; then
                continue
            fi

            if $DRY_RUN; then
                echo -e "  ${CYAN}WOULD DELETE${RESET} $rbranch"
                ((remote_deleted++)) || true
            else
                if confirm_delete "$rbranch" "remote"; then
                    if git push "$remote" --delete "$branch" &>/dev/null; then
                        echo -e "  ${GREEN}DELETED${RESET} $rbranch"
                        ((remote_deleted++)) || true
                    else
                        echo -e "  ${RED}FAILED${RESET} to delete $rbranch"
                    fi
                else
                    echo -e "  ${YELLOW}SKIPPED${RESET} $rbranch"
                    ((remote_skipped++)) || true
                fi
            fi
        done
    fi

    echo ""
fi

# ─── Summary ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}=== Summary ===${RESET}"
if $DRY_RUN; then
    echo -e "  Local branches that would be deleted: ${local_deleted}"
    if $INCLUDE_REMOTE; then
        echo -e "  Remote branches that would be deleted: ${remote_deleted}"
    fi
else
    echo -e "  Local branches deleted: ${GREEN}${local_deleted}${RESET}"
    echo -e "  Local branches skipped: ${YELLOW}${local_skipped}${RESET}"
    if $INCLUDE_REMOTE; then
        echo -e "  Remote branches deleted: ${GREEN}${remote_deleted}${RESET}"
        echo -e "  Remote branches skipped: ${YELLOW}${remote_skipped}${RESET}"
    fi
fi
echo ""
echo -e "${BOLD}Done.${RESET}"
