# Dev Environment Setup Notes

## Installed (scoped, no Android Studio, no emulator images)

| Component | Location | Notes |
|---|---|---|
| Flutter SDK 3.44.6 (stable) | `C:\dev\flutter` | Bundles Dart 3.12.2. Added `C:\dev\flutter\bin` to **User** PATH. |
| Android cmdline-tools | `C:\dev\android-sdk\cmdline-tools\latest` | `sdkmanager` only, no Studio. |
| Android platform-tools | `C:\dev\android-sdk\platform-tools` | Includes `adb`. |
| Android build-tools | `C:\dev\android-sdk\build-tools\36.1.0` | Single version, all 7 SDK licenses accepted. |
| JDK 17 (Temurin) | `C:\dev\jdk17` | Required by `sdkmanager` (needs Java 17+); machine's global `JAVA_HOME` (`C:\Java`, Java 11) was left untouched to avoid breaking other tools. Flutter is configured to use it via `flutter config --jdk-dir=C:\dev\jdk17`. |

`ANDROID_HOME` / `ANDROID_SDK_ROOT` set to `C:\dev\android-sdk` (User scope).

**Deferred on purpose**: no Android `platforms;android-XX` package installed yet. `flutter doctor` shows Android toolchain as `[!]` until one is added — needed only when building a real APK for the borrowed-device test later. That's a separate confirm-before-install step.

Disk: started at 8.52 GB free, ended around 4.55 GB free after all of the above.

## Chrome auto-launch is unreliable here — use `-d web-server` instead

`flutter run -d chrome` repeatedly failed with `Failed to launch browser after 3 tries` / `[CHROME]: Opening in existing browser session`, and left multiple spinning tabs behind.

**Root cause**: this machine has ~1–2 GB free RAM. Chrome's first-launch multi-process startup (browser + GPU + network + renderer processes) is slow enough that Flutter's internal debug-port-connect timeout fires before Chrome opens its remote-debugging port. Flutter then retries by spawning a second Chrome process pointed at the *same* isolated `--user-data-dir` while the first one is still starting up — Chrome's own single-instance lock then merges the two into one session, so the new debug port Flutter is waiting on never comes up. This stacks across all 3 retries until Flutter gives up.

Confirmed via manual test: launching one isolated Chrome instance (fresh `--user-data-dir` + `--remote-debugging-port`) works fine and responds correctly on `/json/version`. So Chrome and the debug protocol both work — it's purely a startup-timing race under RAM pressure, not a broken install.

**Workaround (adopted as the standing dev workflow)**: run `flutter run -d web-server --web-port=8765`, then open `http://localhost:8765` manually in a normal Chrome window/tab (no flutter-managed launch, so no race). Hot reload (`r` in the terminal) still works — confirmed the served page returns the Flutter web bootstrap HTML and loads at `http://localhost:8765` with `HTTP 200`.

## VS Code / Dart-Code setup (2026-07-10)

Three separate issues surfaced getting the Flutter Daemon running in VS Code on this machine, in order:

1. **Git dubious-ownership error blocking every `flutter` command.** `C:\dev\flutter` is owned by SID `S-1-5-32-544` (BUILTIN\Administrators) — likely extracted under an admin account during machine provisioning — while the interactive user is a different SID. Flutter's `update_engine_version.ps1` shells out to `git` internally on every invocation; git refuses to operate in a repo it doesn't own, the script can't parse the null result, and `flutter` aborts before anything (including the daemon) starts. Fixed with:
   ```
   git config --global --add safe.directory C:/dev/flutter
   ```
2. **The Flutter VS Code extension was never actually installed.** Dart-Code publishes *two* separate marketplace extensions: **Dart** (`dart-code.dart-code`) and **Flutter** (`dart-code.flutter`, depends on Dart, adds the actual run/debug/hot-reload support). Only the Dart one was present, so VS Code correctly kept prompting for "the Flutter extension." Fixed with `code --install-extension dart-code.flutter`.
3. **`web-server` device not found in VS Code even though `flutter run -d web-server` works fine from the CLI.** Dart-Code hides the `web-server` device from its own device list/launch-config validation by default. The setting is `dart.flutterShowWebServerDevice` (not `dart.showWebServerDevice` — not in the extension's schema under that name) — **and it's an enum (`"remote"` / `"always"`), not a boolean.** Setting it to `true` fails schema validation and silently falls back to the default (`"remote"`, which only shows the device for remote/browser-based sessions), so it looks like nothing happened no matter how many reloads you do. Correct value: `"dart.flutterShowWebServerDevice": "always"`. Added to the project's `.vscode/settings.json`, alongside a `.vscode/launch.json` config named "vincue_mobile (web-server)" with `"deviceId": "web-server"` and `"args": ["--web-port", "8765"]`.

Two more one-off snags hit while getting this working, both self-contained fixes, not ongoing gotchas:
- **Folder casing mismatch.** The project folder's real on-disk name is `FlutterInventory` (mixed case), but it's easy to `cd`/open it as `flutterinventory` from a shell (NTFS doesn't care, Dart-Code does). If VS Code says the casing doesn't match, force-quit all `Code.exe` processes first (a stale window can keep the wrong-cased path loaded even after reopening correctly) and reopen with the exact on-disk casing.
- **`redhat.java` (+ its Test Runner) errors on this project even though it's pure Dart/Flutter.** Trigger is Flutter's own auto-generated `android/build.gradle.kts` files, which match `redhat.java`'s `workspaceContains:*/build.gradle.kts` activation event. Disabled both extensions for this workspace only (Extensions panel → gear icon → Disable (Workspace); it forces disabling both together since one depends on the other) — resolved it permanently for this project without affecting other Java projects.

Disk: 4.55 GB free after initial SDK setup, dropped to a low of 919 MB free by 2026-07-10 (unrelated leftover installers/apps accumulating over time — Postgres, an unused WSL/Ubuntu install, stray installer downloads, the Windows Copilot app), then reclaimed back up to **~8.3 GB free** the same day by removing all of it. Check free space before any new install/build regardless — this machine trends toward tight, even if it's fine right now.
