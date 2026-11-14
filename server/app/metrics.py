"""Load the account world the snapshot and the rule checker both read."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

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


@dataclass
class Rollup:
    spend: float
    revenue: float
    profit: float
    roi_pct: float
    clicks: int
    conversions: int
    days: list[BundleStat] = field(default_factory=list)


@dataclass
class World:
    account: Account
    pnl: list[PnLPoint]
    transactions: list[Transaction]
    bundles: list[tuple[Bundle, Rollup]]
    geos: list[Geo]
    tasks: list[Task]
    journal: list[JournalEntry]
    rules: list[Rule]
    spend_today: float
    income_today: float


def rule_params(rule: Rule) -> dict:
    try:
        data = json.loads(rule.params_json or "{}")
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def set_rule_params(rule: Rule, params: dict) -> None:
    rule.params_json = json.dumps(params, ensure_ascii=False)


def rollup_for(stats: list[BundleStat]) -> Rollup:
    spend = round(sum(s.spend for s in stats), 2)
    revenue = round(sum(s.revenue for s in stats), 2)
    profit = round(revenue - spend, 2)
    roi = round(profit / spend * 100, 4) if spend else 0.0
    return Rollup(
        spend=spend,
        revenue=revenue,
        profit=profit,
        roi_pct=roi,
        clicks=int(sum(s.clicks for s in stats)),
        conversions=int(sum(s.conversions for s in stats)),
        days=sorted(stats, key=lambda s: s.day),
    )


def recompute_is_derived() -> None:
    """Totals are always derived from daily stats. Nothing is cached on the bundle row."""


def load_world(db: Session) -> World:
    account = db.scalar(select(Account).limit(1))
    if account is None:
        raise RuntimeError("База пустая. Запустите python -m app.seed")
    pnl = list(db.scalars(select(PnLPoint).order_by(PnLPoint.day)))
    transactions = list(
        db.scalars(select(Transaction).order_by(Transaction.occurred_at.desc()))
    )
    bundles = list(db.scalars(select(Bundle).order_by(Bundle.sort_order, Bundle.id)))
    paired: list[tuple[Bundle, Rollup]] = []
    for bundle in bundles:
        stats = list(
            db.scalars(
                select(BundleStat)
                .where(BundleStat.bundle_id == bundle.id)
                .order_by(BundleStat.day)
            )
        )
        paired.append((bundle, rollup_for(stats)))
    geos = list(db.scalars(select(Geo).order_by(Geo.sort_order, Geo.id)))
    tasks = list(db.scalars(select(Task).order_by(Task.sort_order, Task.id)))
    journal = list(
        db.scalars(select(JournalEntry).order_by(JournalEntry.occurred_at.desc()))
    )
    rules = list(db.scalars(select(Rule).order_by(Rule.sort_order, Rule.id)))
    as_of = account.reporting_date
    spend_today = 0.0
    income_today = 0.0
    for tx in transactions:
        if tx.occurred_at.date() != as_of:
            continue
        if tx.amount < 0:
            spend_today += -tx.amount
        else:
            income_today += tx.amount
    return World(
        account=account,
        pnl=pnl,
        transactions=transactions,
        bundles=paired,
        geos=geos,
        tasks=tasks,
        journal=journal,
        rules=rules,
        spend_today=round(spend_today, 2),
        income_today=round(income_today, 2),
    )


def touch(entity, when: datetime | None = None) -> datetime:
    now = when or datetime.now().replace(microsecond=0)
    entity.updated_at = now
    return now
