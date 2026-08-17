# Validation and acceptance

## Self-verification matrix

| Area | Evidence |
|---|---|
| Files | Source/destination counts, sizes, hashes for critical files |
| Applications | Executable version, process executable path, update/uninstall path |
| Shortcuts | Target, working directory, icon, actual click-equivalent launch |
| File associations | UserChoice/ProgID/Application command and Shell invocation |
| Environment | Registry values plus command resolution in a fresh process |
| Caches | Tool reports new D: path and a harmless download/install uses it |
| Projects | Normal open/build/test command succeeds |
| Docker | Context, engine status without forced start, Compose paths, counts, VHDX unchanged |
| WSL | Distribution list, version, VHDX path, no generic move |
| VMware | Inventory and VM paths, no running-disk manipulation |
| Recovery | Backup exists, contains no plaintext secrets, restore steps documented |

## Administrator/user acceptance

Ask the user to verify representative workflows:

1. Open one affected application from the desktop.
2. Open one document through double-click and Open With.
3. Open/build one project in each primary development stack.
4. Confirm personal data in cloud/download/chat applications.
5. Confirm Docker/WSL/VMware projects appear as expected.
6. Review deletion candidates; accept or reject each group.
7. Confirm the management folder is understandable.

## Completion gate

Declare completion only when:

- Every planned action is reflected in the manifest.
- Every invariant has strong evidence.
- New failures are resolved or explicitly excluded by the user.
- Rollback artifacts are accessible.
- User acceptance is recorded.

