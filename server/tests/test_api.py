IOS = {"X-API-Key": "test-ios"}
BOT = {"X-API-Key": "test-bot"}


def snap(client):
    response = client.get("/api/v1/snapshot", headers=IOS)
    assert response.status_code == 200, response.text
    return response.json()


def test_health_is_open(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["ok"] is True


def test_missing_and_wrong_key(client):
    assert client.get("/api/v1/snapshot").status_code == 401
    assert client.get("/api/v1/snapshot", headers={"X-API-Key": "nope"}).status_code == 401


def test_openapi_lists_rule_check(client):
    spec = client.get("/openapi.json").json()
    assert spec["info"]["title"] == "Дисциплина"
    assert "/api/v1/rules/check" in spec["paths"]
    assert "/api/v1/snapshot" in spec["paths"]
    assert "/api/v1/sync" in spec["paths"]
    assert "X-API-Key" in spec["components"]["securitySchemes"] or any(
        "APIKey" in name or "APIKeyHeader" in name or "X-API-Key" in str(scheme)
        for name, scheme in spec["components"].get("securitySchemes", {}).items()
    )


def test_seed_matches_the_mockups(client):
    body = snap(client)
    assert body["as_of"] == "2026-11-14"
    assert body["date_label"] == "Суббота, 14 ноября"

    finance = body["finance"]
    assert finance["balance"] == 789.4
    assert finance["reserve"] == 300
    assert finance["on_hold"] == 186
    assert finance["free"] == 489.4
    assert round(finance["reserve"] + finance["free"], 2) == finance["balance"]
    assert finance["invested"] == 1000
    assert finance["returned"] == 420
    assert finance["break_even_ratio"] == 0.42
    assert finance["profit_today"] == 34.2
    assert finance["spend_today"] == 38
    assert finance["income_today"] == 72.2
    assert finance["roi_today_pct"] == 90
    display = finance["display"]
    assert display["profit_today"] == "+$34.20"
    assert display["spend_today"] == "$38.00"
    assert display["income_today"] == "$72.20"
    assert display["roi_today"] == "90%"
    assert display["stop_ratio"] == "$38 / $50"
    assert display["balance"] == "$789.40"
    assert display["reserve"] == "$300.00"
    assert display["on_hold"] == "$186.00"
    assert display["free"] == "$489.40"
    assert display["invested"] == "$1 000"
    assert display["returned"] == "$420"
    assert display["break_even"] == "42%"
    assert len(finance["series"]) == 14
    assert finance["series"][-1]["date"] == "2026-11-14"
    assert finance["series"][-1]["profit"] == 34.2

    assert [tx["title"] for tx in body["transactions"]] == [
        "Admitad · Surfshark",
        "TikTok Ads · VPN",
        "Admitad · Skillbox",
        "Google Ads · Курсы",
    ]
    assert [tx["subtitle"] for tx in body["transactions"]] == [
        "Сегодня, 16:40 · Польша",
        "Сегодня, 11:18 · Польша",
        "Вчера · Испания",
        "Вчера · Испания",
    ]
    assert [tx["amount_label"] for tx in body["transactions"]] == [
        "+$72.20",
        "-$38.00",
        "+$54.00",
        "-$41.00",
    ]

    bundles = {row["title"]: row for row in body["bundles"]}
    assert list(bundles) == [
        "VPN · Польша",
        "VPN · Филиппины",
        "Курсы · Испания",
        "E-com · Казахстан",
        "Travel · Мексика",
    ]
    poland = bundles["VPN · Польша"]
    assert poland["subtitle"] == "TikTok Ads · Admitad · CPA"
    assert poland["status"] == "profit"
    assert poland["status_label"] == "Прибыль"
    assert poland["spend"] == 248
    assert poland["profit"] == 214
    assert poland["roi_label"] == "86%"
    assert poland["profit_label"] == "+$214"
    assert poland["spend_label"] == "$248"
    assert bundles["VPN · Филиппины"]["roi_label"] == "61%"
    assert bundles["VPN · Филиппины"]["profit_label"] == "+$97"
    assert bundles["VPN · Филиппины"]["spend_label"] == "$159"
    assert bundles["Курсы · Испания"]["status_label"] == "Тест"
    assert bundles["Курсы · Испания"]["roi_label"] == "32%"
    assert bundles["Курсы · Испания"]["spend_label"] == "$88"
    assert bundles["E-com · Казахстан"]["roi_label"] == "8%"
    assert bundles["E-com · Казахстан"]["profit_label"] == "+$5"
    assert bundles["Travel · Мексика"]["status"] == "stop"
    assert bundles["Travel · Мексика"]["roi_label"] == "-24%"
    assert bundles["Travel · Мексика"]["profit_label"] == "-$19"
    assert bundles["Travel · Мексика"]["spend_label"] == "$80"
    assert bundles["Travel · Мексика"]["subtitle"] == "Native Ads · Travelpayouts"

    geos = body["geos"]
    assert [(geo["code"], geo["status_label"], geo["cpc_label"], geo["epc_label"], geo["trend_label"]) for geo in geos] == [
        ("PL", "Живая", "$0.18", "$0.34", "↑ 12%"),
        ("PH", "Живая", "$0.09", "$0.15", "↑ 6%"),
        ("ES", "Тест", "$0.42", "$0.55", "↑ 3%"),
        ("KZ", "Тест", "$0.11", "$0.12", "0%"),
        ("MX", "Стоп", "$0.22", "$0.17", "↓ 8%"),
    ]
    assert geos[0]["subtitle"] == "VPN · TikTok Ads · Admitad"
    assert geos[4]["subtitle"] == "Travel · Native Ads"
    summary = body["geo_summary"]
    assert summary["live_count"] == 4
    assert summary["stopped_count"] == 1
    assert summary["avg_cpc"] == 0.2
    assert summary["avg_epc"] == 0.29
    assert summary["avg_cpc_label"] == "$0.20"
    assert summary["avg_epc_label"] == "$0.29"
    assert summary["stopped_line"] == "и 1 в стопе · капитал $1 000"

    assert body["task_summary"] == {
        "done": 1,
        "total": 3,
        "open": 2,
        "headline": "1 из 3",
        "subline": "две задачи ещё открыты",
        "date_line": "Сегодня · Суббота, 14 ноября",
    }
    assert body["tasks"][0]["title"] == "Проверить стоп-лосс дня"
    assert body["tasks"][0]["done"] is True
    assert body["tasks"][0]["note"] == "Запас $12 · правило соблюдено"
    assert body["tasks"][1]["title"] == "Разобрать креативы"
    assert body["tasks"][1]["note"] == "TikTok Ads · не откладывать"
    assert body["tasks"][2]["detail"].startswith("Awin")

    assert body["journal_summary"]["count"] == 12
    assert body["journal_summary"]["headline"] == "12 записей"
    assert body["journal_summary"]["subline"] == "последняя — сегодня, 16:45"
    assert [entry["title"] for entry in body["journal"][:5]] == [
        "Оставил VPN · Польша в работе",
        "Остановил Travel · Мексика",
        "Увеличил бюджет VPN · Польша",
        "Запустил тест Курсы · Испания",
        "Зафиксировал резерв $300",
    ]
    first = body["journal"][0]
    assert first["date_label"] == "Сегодня, 16:45"
    assert first["reason"] == "EPC $0.34 при CPC $0.18, день закрывается в плюсе."
    assert first["result"] == "+$34.20 за день"
    stopped = body["journal"][1]
    assert stopped["date_label"] == "Вчера, 19:10"
    assert stopped["result"] == "−$19, связка в стопе"
    assert body["journal"][2]["result"] == "шаг +25%, расход $248, прибыль +$214"
    assert body["journal"][4]["result"] == "резерв активен, свободно $489.40"

    rules = body["rules"]
    assert [(rule["title"], rule["value_label"], rule["enabled"], rule["detail"]) for rule in rules] == [
        ("Стоп-лосс дня", "$50", True, "Сегодня расход $38 · осталось $12"),
        ("Стоп-лосс связки", "$80", True, "При достижении связка уходит в стоп"),
        ("Резерв капитала", "$300", True, "30% от $1 000, не использовать в тестах"),
        ("Шаг масштабирования", "25%", True, "После 7 дней при ROI выше 50%"),
        ("Лимит тестов", "2", True, "Сейчас открыто 2 теста — Испания и Казахстан"),
        ("Вывод до нуля", "ВЫКЛ", False, "Пока вернулось $420 из $1 000"),
    ]
    assert rules[-1]["value_muted"] is True
    assert body["rule_summary"]["headline"] == "5 из 6"
    assert body["rule_summary"]["subline"] == "правил сейчас включены"
    assert body["home"] == {
        "bundles_label": "5 активных",
        "geos_label": "4 страны",
        "tasks_label": "3 на сегодня",
        "journal_label": "12 записей",
        "rules_label": "стоп $50",
    }


def test_seed_has_a_warning_a_scale_signal_and_no_violations(client):
    report = client.get("/api/v1/rules/check", headers=IOS).json()
    assert report["violations"] == []
    assert [item["key"] for item in report["warnings"]] == ["daily_stop_loss"]
    assert report["warnings"][0]["message"] == "Сегодня расход $38 · осталось $12"
    assert [item["key"] for item in report["signals"]] == ["scale_step"]
    assert "VPN · Польша" in report["signals"][0]["message"]
    assert "Филиппины" not in report["signals"][0]["message"]
    by_key = {item["key"]: item for item in report["items"]}
    assert by_key["bundle_stop_loss"]["status"] == "ok"
    assert "Travel · Мексика" in by_key["bundle_stop_loss"]["message"]
    assert by_key["withdraw_to_zero"]["status"] == "disabled"
    assert by_key["test_limit"]["status"] == "ok"
    assert by_key["capital_reserve"]["status"] == "ok"


def test_bot_writes_stats_and_journal_but_not_rules(client):
    denied = client.patch("/api/v1/rules/1", headers=BOT, json={"enabled": False})
    assert denied.status_code == 403

    journal = client.post(
        "/api/v1/journal",
        headers=BOT,
        json={
            "title": "Сводка бота",
            "reason": "День закрыт внутри стопа.",
            "result": "нарушений нет",
            "result_tone": "neutral",
            "occurred_at": "2026-11-14T18:05:00",
        },
    )
    assert journal.status_code == 200
    body = journal.json()
    assert body["journal_summary"]["count"] == 13
    assert body["journal"][0]["title"] == "Сводка бота"

    poland = next(row for row in body["bundles"] if row["title"] == "VPN · Польша")
    updated = client.post(
        f"/api/v1/bundles/{poland['id']}/stats",
        headers=BOT,
        json={"day": "2026-11-15", "spend": 10, "revenue": 12, "clicks": 40, "conversions": 1},
    )
    assert updated.status_code == 200
    fresh = next(row for row in updated.json()["bundles"] if row["id"] == poland["id"])
    assert fresh["spend"] == 258
    assert fresh["revenue"] == 474

    created = client.post(
        "/api/v1/transactions",
        headers=BOT,
        json={"title": "Admitad · холд", "geo_name": "Польша", "amount": 10, "occurred_at": "2026-11-12T10:00:00"},
    )
    assert created.status_code == 200
    assert any(tx["title"] == "Admitad · холд" for tx in created.json()["transactions"])


def test_losing_bundle_over_the_stop_is_a_violation(client):
    created = client.post(
        "/api/v1/bundles",
        headers=IOS,
        json={
            "title": "Нутра · Бразилия",
            "vertical": "Нутра",
            "geo_code": "BR",
            "traffic_source": "Native Ads",
            "network": "Admitad",
            "payout_model": "CPA",
            "status": "profit",
        },
    )
    assert created.status_code == 200
    bundle_id = next(row["id"] for row in created.json()["bundles"] if row["title"] == "Нутра · Бразилия")
    client.post(
        f"/api/v1/bundles/{bundle_id}/stats",
        headers=IOS,
        json={"day": "2026-11-14", "spend": 90, "revenue": 50, "clicks": 100, "conversions": 2},
    )
    report = client.get("/api/v1/rules/check", headers=BOT).json()
    assert len(report["violations"]) == 1
    assert report["violations"][0]["key"] == "bundle_stop_loss"
    assert "Нутра · Бразилия" in report["violations"][0]["message"]


def test_phone_toggles_a_task_and_sync_is_idempotent(client):
    patched = client.patch("/api/v1/tasks/2", headers=IOS, json={"done": True})
    assert patched.status_code == 200
    body = patched.json()
    assert body["task_summary"]["headline"] == "2 из 3"
    assert body["task_summary"]["subline"] == "одна задача ещё открыта"
    assert body["tasks"][1]["done"] is True

    sync = client.post(
        "/api/v1/sync",
        headers=IOS,
        json={
            "mutations": [
                {
                    "id": "local-task-3",
                    "entity": "task",
                    "op": "update",
                    "payload": {"id": 3, "done": True},
                    "client_updated_at": "2026-11-14T18:00:00",
                }
            ]
        },
    )
    assert sync.status_code == 200, sync.text
    result = sync.json()
    assert result["applied"] == ["local-task-3"]
    assert result["conflicts"] == []
    assert result["snapshot"]["task_summary"]["headline"] == "3 из 3"
    assert result["snapshot"]["task_summary"]["subline"] == "все задачи закрыты"

    again = client.post(
        "/api/v1/sync",
        headers=IOS,
        json={
            "mutations": [
                {
                    "id": "local-task-3",
                    "entity": "task",
                    "op": "update",
                    "payload": {"id": 3, "done": False},
                    "client_updated_at": "2026-11-14T19:00:00",
                }
            ]
        },
    )
    assert again.json()["snapshot"]["tasks"][2]["done"] is True

    forbidden = client.post(
        "/api/v1/sync",
        headers=BOT,
        json={
            "mutations": [
                {
                    "id": "bot-rule",
                    "entity": "rule",
                    "op": "update",
                    "payload": {"id": 1, "enabled": False},
                    "client_updated_at": "2026-11-14T18:00:00",
                }
            ]
        },
    )
    assert forbidden.status_code == 200
    assert forbidden.json()["conflicts"][0]["id"] == "bot-rule"
    assert snap(client)["rules"][0]["enabled"] is True


def test_bundle_filter_and_phone_can_stop_a_bundle(client):
    only_stop = client.get("/api/v1/bundles", headers=BOT, params={"status": "stop"}).json()
    assert [row["title"] for row in only_stop] == ["Travel · Мексика"]
    stopped = client.patch("/api/v1/bundles/3", headers=IOS, json={"status": "stop"})
    assert stopped.status_code == 200
    spain = next(row for row in stopped.json()["bundles"] if row["id"] == 3)
    assert spain["status_label"] == "Стоп"
    assert stopped.json()["rules"][4]["detail"] == "Сейчас открыто 1 тест — Казахстан"
