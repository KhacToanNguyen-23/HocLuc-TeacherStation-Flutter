import json
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from models import preflight
report = preflight()
print(json.dumps(report, ensure_ascii=True, indent=2))
sys.exit(0 if report['assetsReady'] else 1)
