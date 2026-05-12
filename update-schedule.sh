#!/bin/bash
# RADIXスクール スケジュール自動更新スクリプト
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="$SCRIPT_DIR/schedule-data.js"

echo "スケジュール更新中..."

python3 - "$OUTPUT" <<'EOF'
import urllib.request, json, sys
from datetime import date, datetime

output_path = sys.argv[1]

def fetch(year, month):
    url = f"https://sgrum.com/web/fcradixniigata/schedule.ajax?year={year}&month={month:02d}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read())
    except Exception as e:
        print(f"  取得失敗 {year}/{month:02d}: {e}", file=sys.stderr)
        return None

def extract(data):
    out = {}
    if not data:
        return out
    for dateKey, items in data.get("dayCalendarData", {}).items():
        for item in items:
            t = item["title"]
            if ("U12" in t or "U10" in t) and "スクール" in t:
                d = data["detailData"].get(str(item["seq"]), {})
                time_str = ""
                if d.get("startTime") and d.get("endTime"):
                    time_str = d["startTime"] + "〜" + d["endTime"]
                cls = "u12" if "U12" in t else "u10"
                out.setdefault(dateKey, []).append(
                    {"cls": cls, "label": cls.upper(), "time": time_str}
                )
    return out

today = date.today()
all_events = {}

for delta in range(3):
    m = today.month + delta
    y = today.year + (m - 1) // 12
    m = ((m - 1) % 12) + 1
    print(f"  取得中: {y}/{m:02d}")
    all_events.update(extract(fetch(y, m)))

now_str = datetime.now().strftime("%Y-%m-%d %H:%M")
lines = [f"// 自動更新: {now_str}"]
lines.append("const SCHEDULE_DATA = {")
for k in sorted(all_events.keys()):
    v = json.dumps(all_events[k], ensure_ascii=False)
    lines.append(f'  "{k}": {v},')
lines.append("};")

with open(output_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

print(f"  完了: {len(all_events)}日分 → {output_path}")
EOF
