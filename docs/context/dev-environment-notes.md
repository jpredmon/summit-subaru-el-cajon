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
