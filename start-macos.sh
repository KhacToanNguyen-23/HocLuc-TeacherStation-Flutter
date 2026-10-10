#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$task_root"
mkdir -p .run
if [[ "${1:-}" == "service" ]]; then
  mvn -q -f backend/service/pom.xml package
  cd backend/whiteboard-host
  npm ci --no-audit --no-fund
  npm run build
  cd "$task_root"
  exec java -jar backend/service/target/companion-service-0.1.0.jar "$task_root" 47831
fi
if [[ "${1:-}" == "app" ]]; then
  cd frontend
  flutter pub get
  exec flutter run -d macos
fi
printf '%s\n' 'Terminal 1: bash start-macos.sh service' 'Terminal 2: bash start-macos.sh app' 'Dừng từng tiến trình bằng Ctrl+C. Cần Java 17+, Maven, Node/npm, Flutter và Xcode/CocoaPods.'
