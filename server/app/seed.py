"""Seed the database so the API matches the Дисциплина mockups of 14 Nov 2026.

Budget on the account is $1 000. Balance is reserve + free
($300 + $489.40 = $789.40). Returned payouts are $420, so break-even is 42%.
"""

from __future__ import annotations

import argparse
import json
from datetime import date, datetime, timedelta
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_sessionmaker, init_db, reset_engine_schema
from app.metrics import load_world
from app.models import (
    Account,
    Bundle,
    BundleStat,
    Geo,
    JournalEntry,
    PnLPoint,
    Rule,
    Task,
    Transaction,
)
from app.snapshot import build_snapshot

AS_OF = date(2026, 11, 14)
SEEDED_AT = datetime(2026, 11, 14, 9, 0, 0)

# (offset from AS_OF, spend cents, revenue cents)
POLAND_DAYS = [
    (-13, 800, 1400),
    (-12, 700, 1300),
    (-11, 700, 1300),
    (-10, 700, 1400),
    (-9, 700, 1300),
    (-8, 700, 1400),
    (-7, 700, 1380),
    (-6, 2200, 4000),
    (-5, 2400, 4400),
    (-4, 2600, 4800),
    (-3, 2800, 5200),
    (-2, 3000, 5500),
    (-1, 3000, 5600),
    (0, 3800, 7220),
]
# Philippines, Spain, Kazakhstan and Mexico have no row on the reporting day,
# so the only ad spend "today" is Poland's $38 — the TikTok transaction.
PH_DAYS = [(-13 + i, 1200, 1900) for i in range(12)] + [(-1, 1500, 2800)]
ES_DAYS = [(-4 + i, 2200, 2900) for i in range(4)]
KZ_DAYS = [(-2, 3100, 3400), (-1, 3100, 3300)]
MX_DAYS = [(-3, 4000, 3000), (-2, 4000, 3100)]

PNL_CENTS = [1800, 1200, 2000, 1500, 2400, 2800, 1900, 2600, 2100, 3000, 2300, 1700, 2200, 3420]


def _assert_seed_math() -> None:
    assert sum(s for _, s, _ in POLAND_DAYS) == 24800
    assert sum(r for _, _, r in POLAND_DAYS) == 46200
    assert sum(s for _, s, _ in PH_DAYS) == 15900
    assert sum(r for _, _, r in PH_DAYS) == 25600
    assert sum(s for _, s, _ in ES_DAYS) == 8800
    assert sum(r for _, _, r in ES_DAYS) == 11600
    assert sum(s for _, s, _ in KZ_DAYS) == 6200
    assert sum(r for _, _, r in KZ_DAYS) == 6700
    assert sum(s for _, s, _ in MX_DAYS) == 8000
    assert sum(r for _, _, r in MX_DAYS) == 6100
    assert PNL_CENTS[-1] == 7220 - 3800
    assert len(PNL_CENTS) == 14
    assert len(PH_DAYS) == 13


_assert_seed_math()


def _dollars(cents: int) -> float:
    return round(cents / 100, 2)


def _day(offset: int) -> date:
    return AS_OF + timedelta(days=offset)


def _stats(bundle: Bundle, rows: list[tuple[int, int, int]], cpc: float) -> list[BundleStat]:
    stats = []
    for offset, spend_c, rev_c in rows:
        spend = _dollars(spend_c)
        revenue = _dollars(rev_c)
        clicks = max(1, int(round(spend / cpc))) if cpc else 0
        conversions = max(0, int(round(revenue / 8)))
        stats.append(
            BundleStat(
                bundle=bundle,
                day=_day(offset),
                spend=spend,
                revenue=revenue,
                clicks=clicks,
                conversions=conversions,
            )
        )
    return stats


def seed(db: Session) -> None:
    account = Account(
        reporting_date=AS_OF,
        invested=1000,
        returned=420,
        reserve=300,
        on_hold=186,
        free=489.40,
    )
    db.add(account)

    for index, cents in enumerate(PNL_CENTS):
        db.add(PnLPoint(day=_day(index - 13), profit=_dollars(cents)))

    db.add_all(
        [
            Transaction(
                occurred_at=datetime(2026, 11, 14, 16, 40),
                title="Admitad · Surfshark",
                geo_name="Польша",
                amount=72.20,
                updated_at=SEEDED_AT,
            ),
            Transaction(
                occurred_at=datetime(2026, 11, 14, 11, 18),
                title="TikTok Ads · VPN",
                geo_name="Польша",
                amount=-38.00,
                updated_at=SEEDED_AT,
            ),
            Transaction(
                occurred_at=datetime(2026, 11, 13, 15, 0),
                title="Admitad · Skillbox",
                geo_name="Испания",
                amount=54.00,
                updated_at=SEEDED_AT,
            ),
            Transaction(
                occurred_at=datetime(2026, 11, 13, 12, 0),
                title="Google Ads · Курсы",
                geo_name="Испания",
                amount=-41.00,
                updated_at=SEEDED_AT,
            ),
        ]
    )

    specs = [
        dict(
            title="VPN · Польша",
            subtitle="TikTok Ads · Admitad · CPA",
            vertical="VPN",
            geo_code="PL",
            traffic_source="TikTok Ads",
            network="Admitad",
            payout_model="CPA",
            status="profit",
            sort_order=1,
            days=POLAND_DAYS,
            cpc=0.18,
        ),
        dict(
            title="VPN · Филиппины",
            subtitle="Push-сеть · Admitad · CPA",
            vertical="VPN",
            geo_code="PH",
            traffic_source="Push-сеть",
            network="Admitad",
            payout_model="CPA",
            status="profit",
            sort_order=2,
            days=PH_DAYS,
            cpc=0.09,
        ),
        dict(
            title="Курсы · Испания",
            subtitle="Google Ads · Admitad · CPA",
            vertical="Курсы",
            geo_code="ES",
            traffic_source="Google Ads",
            network="Admitad",
            payout_model="CPA",
            status="test",
            sort_order=3,
            days=ES_DAYS,
            cpc=0.42,
        ),
        dict(
            title="E-com · Казахстан",
            subtitle="TikTok Ads · Admitad · CPS",
            vertical="E-com",
            geo_code="KZ",
            traffic_source="TikTok Ads",
            network="Admitad",
            payout_model="CPS",
            status="test",
            sort_order=4,
            days=KZ_DAYS,
            cpc=0.11,
        ),
        dict(
            title="Travel · Мексика",
            subtitle="Native Ads · Travelpayouts",
            vertical="Travel",
            geo_code="MX",
            traffic_source="Native Ads",
            network="Travelpayouts",
            payout_model="CPS",
            status="stop",
            sort_order=5,
            days=MX_DAYS,
            cpc=0.22,
        ),
    ]
    bundles: dict[str, Bundle] = {}
    for spec in specs:
        days = spec.pop("days")
        cpc = spec.pop("cpc")
        bundle = Bundle(updated_at=SEEDED_AT, **spec)
        db.add(bundle)
        db.add_all(_stats(bundle, days, cpc))
        bundles[bundle.geo_code] = bundle
    db.flush()

    geos = [
        ("PL", "Польша", "VPN · TikTok Ads · Admitad", "live", 0.18, 0.34, 12),
        ("PH", "Филиппины", "VPN · Push-сеть · Admitad", "live", 0.09, 0.15, 6),
        ("ES", "Испания", "Курсы · Google Ads · Admitad", "test", 0.42, 0.55, 3),
        ("KZ", "Казахстан", "E-com · TikTok Ads · Admitad", "test", 0.11, 0.12, 0),
        ("MX", "Мексика", "Travel · Native Ads", "stop", 0.22, 0.17, -8),
    ]
    for index, (code, name, subtitle, status, cpc, epc, trend) in enumerate(geos, start=1):
        db.add(
            Geo(
                code=code,
                name=name,
                subtitle=subtitle,
                status=status,
                cpc=cpc,
                epc=epc,
                trend_pct=trend,
                bundle_id=bundles[code].id,
                sort_order=index,
                updated_at=SEEDED_AT,
            )
        )

    db.add_all(
        [
            Task(
                title="Проверить стоп-лосс дня",
                detail="Дневной лимит $50. Сегодня уже потрачено $38.",
                note="Запас $12 · правило соблюдено",
                note_tone="positive",
                done=True,
                sort_order=1,
                updated_at=SEEDED_AT,
            ),
            Task(
                title="Разобрать креативы",
                detail="Связка VPN · Польша. В кампании 8 объявлений, 2 слабых по CTR.",
                note="TikTok Ads · не откладывать",
                note_tone="accent",
                done=False,
                sort_order=2,
                updated_at=SEEDED_AT,
            ),
            Task(
                title="Зарегистрироваться в партнёрке",
                detail="Awin, вертикаль курсов. Документы уже собраны.",
                note="Нужно до конца дня",
                note_tone="accent",
                done=False,
                sort_order=3,
                updated_at=SEEDED_AT,
            ),
        ]
    )

    journal = [
        (
            datetime(2026, 10, 20, 11, 0),
            "Открыл журнал дисциплины",
            "Одному легко нарушить стоп. Каждое решение записывается.",
            "правила включены до первой связки",
            "neutral",
        ),
        (
            datetime(2026, 10, 25, 13, 5),
            "Подключил Admitad и первые офферы",
            "Surfshark и Skillbox, белые вертикали, понятный холд.",
            "источник дохода для Польши и Испании",
            "positive",
        ),
        (
            datetime(2026, 10, 28, 15, 20),
            "Перевёл VPN · Польша из теста в прибыль",
            "ROI держится выше 60% несколько дней подряд.",
            "статус «Прибыль», связка остаётся в работе",
            "positive",
        ),
        (
            datetime(2026, 11, 1, 10, 0),
            "Зафиксировал капитал $1 000",
            "Рабочий депозит на цикл тестов и масштабирование.",
            "вложено $1 000, резерв посчитан отдельно",
            "neutral",
        ),
        (
            datetime(2026, 11, 3, 17, 50),
            "Отклонил серую вертикаль",
            "Оффер не из белого списка. В работе только VPN, курсы, e-com и travel.",
            "связку не открывал",
            "neutral",
        ),
        (
            datetime(2026, 11, 5, 9, 15),
            "Подключил Push-сеть · Филиппины",
            "EPC выше CPC, вертикаль VPN уже в плюсе на Польше.",
            "ROI 61%, прибыль +$97",
            "positive",
        ),
        (
            datetime(2026, 11, 6, 12, 40),
            "Запустил тест E-com · Казахстан",
            "Узкий оффер, CPC $0.11. Лимит тестов позволяет вторую связку.",
            "расход $62, прибыль +$5, тест идёт",
            "neutral",
        ),
        (
            datetime(2026, 11, 8, 11, 20),
            "Зафиксировал резерв $300",
            "Правило 30% от капитала $1 000, не тратить на тесты.",
            "резерв активен, свободно $489.40",
            "positive",
        ),
        (
            datetime(2026, 11, 10, 14, 5),
            "Запустил тест Курсы · Испания",
            "Живой оффер Skillbox, умеренный CPC $0.42.",
            "пока ROI 32% при расходе $88, тест идёт",
            "neutral",
        ),
        (
            datetime(2026, 11, 12, 18, 30),
            "Увеличил бюджет VPN · Польша",
            "7 дней подряд ROI выше 60%, сработало правило масштабирования.",
            "шаг +25%, расход $248, прибыль +$214",
            "positive",
        ),
        (
            datetime(2026, 11, 13, 19, 10),
            "Остановил Travel · Мексика",
            "ROI −24% при расходе $80, сработал стоп-лосс связки.",
            "−$19, связка в стопе",
            "negative",
        ),
        (
            datetime(2026, 11, 14, 16, 45),
            "Оставил VPN · Польша в работе",
            "EPC $0.34 при CPC $0.18, день закрывается в плюсе.",
            "+$34.20 за день",
            "positive",
        ),
    ]
    for occurred_at, title, reason, result, tone in journal:
        db.add(
            JournalEntry(
                occurred_at=occurred_at,
                title=title,
                reason=reason,
                result=result,
                result_tone=tone,
                updated_at=occurred_at,
            )
        )

    rules = [
        ("daily_stop_loss", "Стоп-лосс дня", True, {"limit": 50}),
        ("bundle_stop_loss", "Стоп-лосс связки", True, {"limit": 80}),
        ("capital_reserve", "Резерв капитала", True, {"amount": 300, "percent": 30}),
        (
            "scale_step",
            "Шаг масштабирования",
            True,
            {"percent": 25, "days": 7, "roi_threshold": 50},
        ),
        ("test_limit", "Лимит тестов", True, {"limit": 2}),
        ("withdraw_to_zero", "Вывод до нуля", False, {}),
    ]
    for index, (key, title, enabled, params) in enumerate(rules, start=1):
        db.add(
            Rule(
                key=key,
                title=title,
                enabled=enabled,
                params_json=json.dumps(params, ensure_ascii=False),
                sort_order=index,
                updated_at=SEEDED_AT,
            )
        )
    db.flush()


def seed_if_empty() -> None:
    init_db()
    with get_sessionmaker()() as db:
        if db.scalar(select(Account).limit(1)) is None:
            seed(db)
            db.commit()


def reset_and_seed() -> None:
    reset_engine_schema()
    with get_sessionmaker()() as db:
        seed(db)
        db.commit()


def export_snapshot(path: Path) -> None:
    with get_sessionmaker()() as db:
        payload = build_snapshot(load_world(db)).model_dump(mode="json")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Пересоздать базу Дисциплины с данными макета")
    parser.add_argument(
        "--export",
        type=Path,
        action="append",
        default=[],
        help="Куда записать snapshot.json (можно несколько раз)",
    )
    args = parser.parse_args()
    reset_and_seed()
    targets = args.export or [Path("data/demo_snapshot.json")]
    for target in targets:
        export_snapshot(target)
        print(f"snapshot -> {target}")
    print(f"база готова, отчётная дата {AS_OF.isoformat()}")


if __name__ == "__main__":
    main()
