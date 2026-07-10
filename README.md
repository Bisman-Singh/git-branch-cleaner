# Git Branch Cleaner

A Bash utility that identifies and removes Git branches that have been merged into the current branch. Supports both local and remote branches with interactive confirmation.

## Features

- Lists all merged branches (local and remote)
- Interactive mode: prompts before each deletion
- Protects critical branches (main, master, develop) from accidental deletion
- Dry-run mode to preview what would be deleted
- Force mode to skip confirmation prompts
- Clear summary of actions taken
- Color-coded output for readability

## Requirements

- Bash 4.0+
- Git 2.0+
- Must be run from inside a Git repository

## Usage

```bash
# Make executable
chmod +x clean-branches.sh

# Interactive cleanup of local merged branches
./clean-branches.sh

# Dry-run: see what would be deleted
./clean-branches.sh -n

# Include remote branches
./clean-branches.sh -r

# Force mode: delete without confirmation
./clean-branches.sh -f

# Full cleanup: local + remote, no prompts
./clean-branches.sh -r -f

# Show help
./clean-branches.sh -h
```

### Flags

| Flag | Description |
|------|-------------|
| `-r` | Include remote tracking branches |
| `-n` | Dry-run: show what would be deleted without deleting |
| `-f` | Force: skip confirmation prompts |
| `-h` | Show help message |

## Sample Output

```
Git Branch Cleaner
Current branch: main
Protected branches: main master develop

[DRY-RUN MODE] No branches will be deleted.

=== Local Merged Branches ===
  SKIP develop (protected)
  WOULD DELETE feature/login-page
  WOULD DELETE bugfix/typo-fix
  WOULD DELETE feature/old-api

=== Summary ===
  Local branches that would be deleted: 3

Done.
```



<sub><sup>Originally developed and tested locally during learning. Later organized and pushed to GitHub for portfolio visibility.</sup></sub>
