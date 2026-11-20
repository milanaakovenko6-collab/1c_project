import json
import os
import subprocess
from datetime import datetime
from collections import Counter

# 1. Читаем отчет BSL Language Server
report_path = "bsl-json.json"
diagnostics = []
if os.path.exists(report_path):
    with open(report_path, "r", encoding="utf-8") as f:
        data = json.load(f)
        for file_info in data.get("fileinfos", []):
            file_path = file_info.get("path", "")
            for diag in file_info.get("diagnostics", []):
                diagnostics.append({
                    "file": os.path.basename(file_path),
                    "full_path": file_path,
                    "line": diag.get("range", {}).get("start", {}).get("line", 0) + 1,
                    "severity": diag.get("severity", "Information"),
                    "code": diag.get("code", ""),
                    "message": diag.get("message", "")
                })

# Подсчет ошибок по уровням критичности
severity_counts = Counter(d["severity"] for d in diagnostics)
errors_count = severity_counts.get("Error", 0)
warnings_count = severity_counts.get("Warning", 0)
info_count = severity_counts.get("Information", 0) + severity_counts.get("Hint", 0)

# 2. Собираем статистику активности разработчиков из Git
authors_commits = Counter()
recent_commits = []
try:
    git_log = subprocess.check_output(
        ["git", "log", "-n", "30", "--pretty=format:%an|%ad|%s", "--date=short"],
        encoding="utf-8"
    )
    for line in git_log.strip().split("\n"):
        if "|" in line:
            author, date, msg = line.split("|", 2)
            authors_commits[author] += 1
            if len(recent_commits) < 10:
                recent_commits.append((author, date, msg))
except Exception as e:
    print(f"Git log error: {e}")

# 3. Формируем HTML-страницу дашборда
os.makedirs("dashboard_out", exist_ok=True)
now_str = datetime.now().strftime("%d.%m.%Y %H:%M UTC")

authors_rows = ""
for author, count in authors_commits.most_common():
    authors_rows += f"<tr><td><strong>{author}</strong></td><td><span class='badge'>{count} коммитов</span></td></tr>"

commits_rows = ""
for author, date, msg in recent_commits:
    commits_rows += f"<tr><td>{date}</td><td>{author}</td><td>{msg}</td></tr>"

diag_rows = ""
for d in diagnostics[:100]: # показываем первые 100 замечаний
    sev_class = d["severity"].lower()
    diag_rows += f"""
    <tr>
        <td><span class="sev {sev_class}">{d['severity']}</span></td>
        <td><strong>{d['file']}</strong><br><small>Строка: {d['line']} | Код: {d['code']}</small></td>
        <td>{d['message']}</td>
    </tr>
    """

if not diag_rows:
    diag_rows = "<tr><td colspan='3' style='text-align:center; color:#10b981;'><strong>Отлично! Замечаний к коду 1С не обнаружено.</strong></td></tr>"

html_content = f"""<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Дашборд качества кода 1С и командной работы</title>
    <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f3f4f6; color: #1f2937; margin: 0; padding: 20px; }}
        .container {{ max-width: 1100px; margin: 0 auto; }}
        header {{ background: #1e293b; color: white; padding: 25px 30px; border-radius: 12px; margin-bottom: 25px; display: flex; justify-content: space-between; align-items: center; }}
        header h1 {{ margin: 0; font-size: 22px; }}
        header span {{ font-size: 13px; color: #94a3b8; }}
        .cards {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; margin-bottom: 25px; }}
        .card {{ background: white; padding: 20px; border-radius: 12px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); border-left: 5px solid #3b82f6; }}
        .card.err {{ border-color: #ef4444; }}
        .card.warn {{ border-color: #f59e0b; }}
        .card.ok {{ border-color: #10b981; }}
        .card h3 {{ margin: 0 0 10px 0; font-size: 14px; color: #6b7280; text-transform: uppercase; }}
        .card .num {{ font-size: 32px; font-weight: bold; }}
        .grid-2 {{ display: grid; grid-template-columns: 1fr 2fr; gap: 20px; margin-bottom: 25px; }}
        .panel {{ background: white; padding: 20px; border-radius: 12px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }}
        .panel h2 {{ margin-top: 0; font-size: 18px; border-bottom: 1px solid #e5e7eb; padding-bottom: 10px; }}
        table {{ width: 100%; border-collapse: collapse; font-size: 14px; }}
        th, td {{ text-align: left; padding: 10px; border-bottom: 1px solid #f1f5f9; }}
        th {{ color: #64748b; font-weight: 600; }}
        .badge {{ background: #e0f2fe; color: #0369a1; padding: 4px 10px; border-radius: 999px; font-weight: 600; font-size: 12px; }}
        .sev {{ padding: 3px 8px; border-radius: 6px; font-size: 12px; font-weight: bold; color: white; }}
        .sev.error {{ background: #ef4444; }}
        .sev.warning {{ background: #f59e0b; }}
        .sev.information, .sev.hint {{ background: #3b82f6; }}
        @media (max-width: 768px) {{ .grid-2 {{ grid-template-columns: 1fr; }} }}
    </style>
</head>
<body>
<div class="container">
    <header>
        <div>
            <h1>Панель мониторинга разработки 1С (CI/CD Dashboard)</h1>
            <span>Автоматический анализ качества кода и активности команды</span>
        </div>
        <span>Обновлено: {now_str}</span>
    </header>

    <div class="cards">
        <div class="card err">
            <h3>Критические ошибки</h3>
            <div class="num">{errors_count}</div>
        </div>
        <div class="card warn">
            <h3>Предупреждения</h3>
            <div class="num">{warnings_count}</div>
        </div>
        <div class="card">
            <h3>Рекомендации (Info)</h3>
            <div class="num">{info_count}</div>
        </div>
        <div class="card ok">
            <h3>Участников команды</h3>
            <div class="num">{len(authors_commits)}</div>
        </div>
    </div>

    <div class="grid-2">
        <div class="panel">
            <h2>Активность разработчиков</h2>
            <table>
                <thead><tr><th>Разработчик</th><th>Вклад</th></tr></thead>
                <tbody>{authors_rows}</tbody>
            </table>
        </div>
        <div class="panel">
            <h2>Последние изменения в репозитории</h2>
            <table>
                <thead><tr><th>Дата</th><th>Автор</th><th>Описание коммита</th></tr></thead>
                <tbody>{commits_rows}</tbody>
            </table>
        </div>
    </div>

    <div class="panel">
        <h2>Детализация замечаний статического анализа (BSL Language Server)</h2>
        <table>
            <thead><tr><th>Уровень</th><th>Модуль / Строка</th><th>Описание проблемы</th></tr></thead>
            <tbody>{diag_rows}</tbody>
        </table>
    </div>
</div>
</body>
</html>
"""

with open("dashboard_out/index.html", "w", encoding="utf-8") as f:
    f.write(html_content)

print("Dashboard successfully generated at dashboard_out/index.html")
