# Risk model

Use this model before every proposed action.

## Weight classes

| Weight | Class | Examples | Default action |
|---:|---|---|---|
| 100 | Irreplaceable state | Projects, personal data, database data, Docker volumes/VHDX, WSL VHDX, VM disks | Never auto-delete or generic-move |
| 90 | Development base | Active IDEs, JDK, Node, Python, Git, databases, working CLI tools | Inspect and application-native repair only |
| 70 | Recovery material | Current backups, manifests, environment exports, recent installers | Retain at least three verified generations |
| 50 | Re-downloadable cache | npm, pnpm, uv, pip, Maven, Gradle, build caches | Relocate through configuration; delete only after validation |
| 30 | Historical versions | Old installers, superseded app copies, old reports | Candidate after 90 days and dependency check |
| 10 | Temporary material | Failed downloads, stale temp files, disposable logs | Candidate after 30 days and ownership check |

## Action risk

| Risk | Action | Required gate |
|---|---|---|
| Low | Create folder, copy report, move verified loose installer | Collision check and manifest |
| Medium | Change user cache config, user PATH, shortcut | Backup, fresh-process validation, rollback |
| High | Move installed app, registry/file association repair, service path change | Application mapping, all registration surfaces, explicit approval |
| Critical | Delete data, factory reset, manipulate VHDX/volumes/VM disks | Product-native backup, explicit confirmation, administrator plan |

## Reversibility score

- 3: exact inverse exists and is tested.
- 2: backup exists but restore is not tested.
- 1: re-download/reinstall required.
- 0: destructive or data loss possible.

Do not execute high-risk work below score 2. Do not execute critical work below score 3.

## Evidence quality

- Strong: actual path, hash, registry value, process executable path, successful shell association, product inventory.
- Medium: shortcut target exists, UI screenshot, directory name.
- Weak: process name only, stale uninstall metadata, old disk report, assumption from folder size.

Completion requires strong evidence for every affected entry point.

