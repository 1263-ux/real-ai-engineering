# Windows path repair

Moving an installed application can break more than its shortcut. Prefer reinstalling to the desired location. If repair is required, inventory and validate every applicable surface.

## Registration surfaces

- User and public desktop shortcuts.
- User and common Start Menu shortcuts.
- `HKCU/HKLM\Software\Classes\<ProgID>` open commands and icons.
- `...\Software\Classes\Applications\<exe>` entries.
- `...\Software\Microsoft\Windows\CurrentVersion\App Paths`.
- UserChoice, OpenWithList, and OpenWithProgids for affected extensions.
- Uninstall InstallLocation, DisplayIcon, and UninstallString.
- User and machine PATH and named environment variables.
- Windows services ImagePath.
- Scheduled tasks and startup entries.
- Protocol handlers and URL schemes.
- Shell extensions, context-menu handlers, COM registrations, and DLL paths.
- Updater configuration and canonical install directory.
- Firewall rules or application allowlists when path-bound.

## Repair order

1. Back up the specific registry branches and shortcuts.
2. Identify the active executable by version, hash, and process path.
3. Check whether an updater recreated an old installation directory.
4. Select one canonical active path; preserve other copies until acceptance.
5. Repair user-level application entries first.
6. Repair system-level entries only with required authority.
7. Refresh shell association caches.
8. Invoke the exact shortcut or Open With candidate.
9. Re-read registry values after application launch and updater activity.
10. Update the software-path index.

## Common failure patterns

- **White icon:** shortcut or icon path no longer exists.
- **Process starts but document does not open:** tested direct executable launch instead of the selected ProgID/Application command.
- **Repair reverts after launch:** updater or installer metadata still points to the old directory.
- **Duplicate Open With candidates:** user and machine registrations coexist, or stale Applications entries remain.
- **Partial application directory:** an interrupted force cleanup deleted the main executable but left locked DLLs/services.

Do not bulk-rewrite hundreds of ProgIDs before confirming the canonical executable and updater behavior.

