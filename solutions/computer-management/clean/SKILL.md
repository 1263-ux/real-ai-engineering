---
name: clean
description: Safely audit, plan, organize, repair, and document a Windows data drive such as D:. Use when Codex is asked to clean or restructure a drive, consolidate downloads/installers/projects, relocate dependency caches, repair shortcuts or file associations after paths changed, validate Docker/WSL/VMware data, create rollback logs, or perform periodic storage maintenance. Prioritizes application integrity, user data, development environments, staged verification, and explicit administrator/user acceptance over visual tidiness.
---

# Clean

Organize a Windows data drive without breaking installed applications, developer tooling, containers, WSL, virtual machines, shortcuts, or file associations.

## Mandatory operating model

1. Define the goal and measurable expected outcome.
2. Inventory the current state without mutation.
3. Classify every proposed action by risk and reversibility.
4. Back up configuration and write a move manifest.
5. Execute one bounded phase at a time.
6. Verify with the same entry point the user uses.
7. Obtain administrator/user acceptance before declaring success.
8. Update the maintenance record and recovery instructions.

Never optimize for a tidy root directory at the expense of working software.

## Non-negotiable safety rules

- Do not move an installed application directory merely for organization.
- Do not delete or move Docker volumes/VHDX, WSL VHDX, VMware disks, database files, user profiles, or system folders through generic file operations.
- Do not use `docker system prune --volumes`, factory reset, recursive deletion, registry-wide replacement, or mass shortcut rewriting as a cleanup shortcut.
- Do not treat a running process as proof that file association, shortcut, update, uninstall, protocol, service, or CLI entry points work.
- Do not expose environment-variable secrets in reports. Record sensitive variable names and presence only.
- Do not delete duplicates until hashes, versions, use, and rollback needs are known.
- Do not change a system-wide path when a user-level override or application-native repair is sufficient.
- Preserve unrelated user changes and dirty worktrees.

Read [references/risk-model.md](references/risk-model.md) before proposing any move, deletion, registry change, or virtualization action.

## Phase 0: define the contract

Write down:

- Target drive and excluded locations.
- Primary machine roles: development, security lab, algorithms, personal data, or storage.
- Desired outcome: free space, clearer categories, cache relocation, broken-path repair, or documentation.
- Required invariants: applications open, projects build, containers remain, data stays, rollback exists.
- Actions requiring explicit confirmation: deletion, uninstall, reinstallation, factory reset, database/volume changes, security settings, or administrator elevation.

Use [assets/plan-template.md](assets/plan-template.md) for the proposed plan.

## Phase 1: collect evidence

Run `scripts/Get-DriveInventory.ps1` from a non-elevated shell first. Store its output outside the area being reorganized.

Also inspect when relevant:

- Drive capacity and top-level structure.
- Installed-app registry entries and actual executables.
- Desktop, public desktop, and Start Menu shortcut targets.
- User and machine PATH entries, plus critical environment variables.
- Services, scheduled tasks, protocol handlers, shell extensions, App Paths, and file associations.
- Docker contexts, Compose files, VHDX locations, containers, images, and volumes without starting/stopping them.
- WSL distributions and VHDX locations.
- VMware inventory and disk locations.
- Dependency cache locations for npm, pnpm, uv, pip, Maven, Gradle, Volta, Cargo, Go, NuGet, and similar tools.
- Existing cleanup scripts, logs, backups, and incomplete operations.

If a prior cleanup failed, read its logs before touching the affected application.

## Phase 2: design the target structure

Prefer a small stable taxonomy:

- `Apps`: portable or deliberately installed applications only.
- `Runtime`: JDK, Maven, language managers, and dependency caches.
- `Projects`: development, learning, security, clones, and archives.
- `UserData`: downloads and application-owned personal data.
- `Virtualization`: managed by Docker/WSL/VMware, not generic moves.
- `Installers`: verified installers and ISO files.
- `Backup`: configuration exports, reports, manifests, and recovery notes.

Do not create categories that require moving working applications without an application-supported migration path.

For every item, record source, destination, category, size, owner/application, risk, rollback, and verification command.

## Phase 3: execute by risk

### Stage A: low risk

- Create destination folders.
- Move loose installers, archives, and reports after collision checks.
- Group personal documents when their applications do not own the paths.
- Generate duplicate candidates; do not delete them.
- Update documentation.

Verify the root directory and moved-file hashes/counts before proceeding.

### Stage B: configurable caches

Use the tool's supported configuration rather than filesystem tricks:

- npm: `npm config set cache <D-path> --location=user`
- pnpm: `pnpm config set store-dir <D-path> --global`
- uv: set `UV_CACHE_DIR` and `UV_PYTHON_INSTALL_DIR`
- pip: set `PIP_CACHE_DIR`
- Maven: configure `settings.xml` local repository
- Gradle: set `GRADLE_USER_HOME`
- Volta: set `VOLTA_HOME` only when the installed launcher supports the layout

Copy existing cache data first, validate new downloads, then propose old-cache deletion separately. Do not move global command prefixes as though they were caches.

### Stage C: installed applications

Prefer, in order:

1. Application-native move feature.
2. Reinstall to the desired path while preserving user data.
3. Vendor-supported portable mode.
4. A documented compatibility junction when reinstalling is unsuitable.
5. Manual registry repair only when all registration surfaces are known.

Read [references/windows-path-repair.md](references/windows-path-repair.md) before this stage.

### Stage D: virtualization and databases

Use product-native export/import, move, backup, or clone workflows. Never infer that a large VHDX is disposable. Do not start or stop workloads merely to count them unless the user authorized operational validation.

## Phase 4: validate each stage

Run `scripts/Test-PostClean.ps1` with the inventory and expected critical paths.

Validation must cover:

- Actual executable exists.
- Desktop and Start Menu shortcuts resolve.
- PATH entries resolve in a fresh process.
- CLI version and a harmless smoke command succeed.
- File association works through Windows Shell/Open With, not only direct executable launch.
- App remains correctly registered after it starts and after an updater runs.
- Uninstall and update entries reference valid paths.
- Services and scheduled tasks reference valid binaries.
- Projects build or open with their normal entry point.
- Docker/WSL/VMware inventories remain recognizable and data locations unchanged.
- Free-space and file-count changes match the manifest.

Read [references/validation-and-acceptance.md](references/validation-and-acceptance.md) for the complete matrix.

## Phase 5: administrator/user acceptance

Separate two approvals:

- **Codex self-verification:** objective evidence, hashes, path checks, smoke tests, and rollback readiness.
- **Administrator/user verification:** user opens representative applications, verifies personal data, accepts the target structure, and approves any deletion candidates.

Do not claim completion when only direct executable launches pass. Ask the user to test the actual desktop shortcut, Open With entry, project workflow, or application UI that originally mattered.

## Phase 6: document and hand off

Create or update a management folder with:

- Current machine and drive profile.
- Software-to-path index distinguishing active paths from stale registration paths.
- Development environment and cache map.
- Docker/WSL/VMware map.
- Maintenance log and move manifest.
- Recovery instructions and configuration backups.
- Outstanding candidates that were not deleted.

Use [assets/maintenance-record-template.md](assets/maintenance-record-template.md). Never store credential values.

## Stop conditions

Stop mutation and report evidence when:

- A target application is running from an unexpected path.
- A cleanup log shows partial deletion.
- A directory contains database, VHDX, VM disk, or application-owned state.
- The desired destination conflicts with an updater's canonical installation path.
- Administrator permission is required for system-wide repair.
- The rollback artifact is missing or cannot be verified.
- Verification produces a new failure outside the planned phase.

Resume only after narrowing the cause and updating the plan.

## Periodic maintenance

Automate inventory, scoring, and report updates. Do not automate destructive cleanup. Use the weights in [references/risk-model.md](references/risk-model.md), retain recent reports, and present stale candidates for approval.

