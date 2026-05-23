# DittoXCactus — Mesh RAG project root commands.
# Run `just` (no args) to list available targets.

# Default target: list targets
default:
    @just --list

# Start the Likec4 dev server (hot-reloads on .c4 source edits)
serve:
    npx --yes likec4@latest start docs/c4

# Validate the Likec4 DSL
validate:
    npx --yes likec4@latest validate docs/c4

# Build the static Likec4 dashboard at docs/c4/dashboard
build:
    npx --yes likec4@latest build docs/c4 -o docs/c4/dashboard

# Open the most recent static-built dashboard in the default browser (macOS)
open-dashboard:
    open docs/c4/dashboard/index.html

# ---------------------------------------------------------------------------
# App run targets — pass DITTO_APP_ID + DITTO_LICENSE via .env, role via flag.

# Device IDs (override on CLI if hardware changes).
ios_device := "00008110-00110CEC1AEB601E"
android_device := "28191JEGR17016"
ios_sim := "8692ACA9-6797-4206-8929-626B672E70CC"  # iPhone 17 Pro

# Run on the physical iPhone as phone-a (release mode skips debug-attach flake).
iphone:
    flutter run --release -d {{ios_device}} \
      --dart-define-from-file=.env \
      --dart-define=PHONE_ROLE=a

# Run on the Pixel 6a as phone-b (debug mode = hot reload works).
android:
    flutter run -d {{android_device}} \
      --dart-define-from-file=.env \
      --dart-define=PHONE_ROLE=b

# Run on the Pixel 6a in release mode — AOT-compiled Dart, optimized
# native. Use for measuring real inference latency; debug mode adds 2-4×
# overhead that masks the model's actual decode speed.
android-release:
    flutter run --release -d {{android_device}} \
      --dart-define-from-file=.env \
      --dart-define=PHONE_ROLE=b

# Run in the iOS simulator as phone-a — fastest debug loop (host CPU decode,
# hot reload, no signing dance).
sim role="a":
    xcrun simctl boot {{ios_sim}} 2>/dev/null || true
    open -a Simulator
    flutter run -d {{ios_sim}} \
      --dart-define-from-file=.env \
      --dart-define=PHONE_ROLE={{role}}
