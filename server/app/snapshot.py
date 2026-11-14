from __future__ import annotations

from app.metrics import World, rule_params
from app.ru import (
    date_label,
    fmt_money,
    fmt_roi,
    fmt_trend,
    journal_date_label,
    ru_count,
    ru_plural,
    rules_subline,
    task_open_subline,
    transaction_subtitle,
)
from app.rules import rule_presentation
from app.schemas import (
    BundleOut,
    Finance,
    FinanceDisplay,
    GeoOut,
    GeoSummary,
    HomeLabels,
    JournalOut,
    JournalSummary,
    RuleOut,
    RuleSummary,
    SeriesPoint,
    Snapshot,
    TaskOut,
    TaskSummary,
    TransactionOut,
)

BUNDLE_LABELS = {"profit": "Прибыль", "test": "Тест", "stop": "Стоп"}
GEO_LABELS = {"live": "Живая", "test": "Тест", "stop": "Стоп"}


def build_snapshot(world: World) -> Snapshot:
    account = world.account
    as_of = account.reporting_date
    profit_today = round(world.income_today - world.spend_today, 2)
    roi_today = round(profit_today / world.spend_today * 100, 4) if world.spend_today else 0.0
    balance = round(account.reserve + account.free, 2)
    break_even = round(account.returned / account.invested, 4) if account.invested else 0.0
    stop_limit = 0.0
    for rule in world.rules:
        if rule.key == "daily_stop_loss":
            stop_limit = float(rule_params(rule).get("limit", 0))

    display = FinanceDisplay(
        profit_today=fmt_money(profit_today, signed=True),
        spend_today=fmt_money(world.spend_today, cents=True),
        income_today=fmt_money(world.income_today, cents=True),
        roi_today=fmt_roi(roi_today),
        stop_ratio=f"{fmt_money(world.spend_today)} / {fmt_money(stop_limit)}",
        balance=fmt_money(balance, cents=True),
        reserve=fmt_money(account.reserve, cents=True),
        on_hold=fmt_money(account.on_hold, cents=True),
        free=fmt_money(account.free, cents=True),
        invested=fmt_money(account.invested),
        returned=fmt_money(account.returned),
        break_even=fmt_roi(break_even * 100),
    )
    finance = Finance(
        balance=balance,
        reserve=account.reserve,
        on_hold=account.on_hold,
        free=account.free,
        invested=account.invested,
        returned=account.returned,
        break_even_ratio=break_even,
        profit_today=profit_today,
        spend_today=world.spend_today,
        income_today=world.income_today,
        roi_today_pct=roi_today,
        stop_limit=stop_limit,
        stop_spent=world.spend_today,
        series=[SeriesPoint(date=point.day, profit=point.profit) for point in world.pnl],
        display=display,
    )
    transactions = [
        TransactionOut(
            id=tx.id,
            occurred_at=tx.occurred_at,
            title=tx.title,
            subtitle=transaction_subtitle(tx.occurred_at, as_of, tx.geo_name),
            geo_name=tx.geo_name,
            amount=tx.amount,
            amount_label=fmt_money(tx.amount, cents=True, signed=True),
        )
        for tx in world.transactions
    ]
    bundles = []
    for bundle, roll in world.bundles:
        bundles.append(
            BundleOut(
                id=bundle.id,
                title=bundle.title,
                subtitle=bundle.subtitle,
                vertical=bundle.vertical,
                geo_code=bundle.geo_code,
                traffic_source=bundle.traffic_source,
                network=bundle.network,
                payout_model=bundle.payout_model,
                status=bundle.status,
                status_label=BUNDLE_LABELS.get(bundle.status, bundle.status),
                spend=roll.spend,
                revenue=roll.revenue,
                profit=roll.profit,
                roi_pct=roll.roi_pct,
                clicks=roll.clicks,
                conversions=roll.conversions,
                spend_label=fmt_money(roll.spend),
                profit_label=fmt_money(roll.profit, signed=True),
                roi_label=fmt_roi(roll.roi_pct),
                sort_order=bundle.sort_order,
            )
        )
    geos = [
        GeoOut(
            id=geo.id,
            code=geo.code,
            name=geo.name,
            subtitle=geo.subtitle,
            status=geo.status,
            status_label=GEO_LABELS.get(geo.status, geo.status),
            cpc=geo.cpc,
            epc=geo.epc,
            trend_pct=geo.trend_pct,
            cpc_label=fmt_money(geo.cpc, cents=True),
            epc_label=fmt_money(geo.epc, cents=True),
            trend_label=fmt_trend(geo.trend_pct),
            bundle_id=geo.bundle_id,
            sort_order=geo.sort_order,
        )
        for geo in world.geos
    ]
    active_geos = [geo for geo in world.geos if geo.status != "stop"]
    stopped = [geo for geo in world.geos if geo.status == "stop"]
    avg_cpc = round(sum(g.cpc for g in active_geos) / len(active_geos), 2) if active_geos else 0.0
    avg_epc = round(sum(g.epc for g in active_geos) / len(active_geos), 2) if active_geos else 0.0
    geo_summary = GeoSummary(
        live_count=len(active_geos),
        stopped_count=len(stopped),
        capital=account.invested,
        avg_cpc=avg_cpc,
        avg_epc=avg_epc,
        capital_label=fmt_money(account.invested),
        avg_cpc_label=fmt_money(avg_cpc, cents=True),
        avg_epc_label=fmt_money(avg_epc, cents=True),
        stopped_line=f"и {len(stopped)} в стопе · капитал {fmt_money(account.invested)}",
    )
    tasks = [
        TaskOut(
            id=task.id,
            title=task.title,
            detail=task.detail,
            note=task.note,
            note_tone=task.note_tone,
            done=task.done,
            sort_order=task.sort_order,
        )
        for task in world.tasks
    ]
    done = sum(1 for task in world.tasks if task.done)
    total = len(world.tasks)
    open_count = total - done
    task_summary = TaskSummary(
        done=done,
        total=total,
        open=open_count,
        headline=f"{done} из {total}",
        subline=task_open_subline(open_count),
        date_line=f"Сегодня · {date_label(as_of)}",
    )
    journal = [
        JournalOut(
            id=entry.id,
            occurred_at=entry.occurred_at,
            date_label=journal_date_label(entry.occurred_at, as_of),
            title=entry.title,
            reason=entry.reason,
            result=entry.result,
            result_tone=entry.result_tone,
        )
        for entry in world.journal
    ]
    latest = journal[0].date_label if journal else "нет записей"
    lowered = latest[:1].lower() + latest[1:] if journal else "нет записей"
    journal_summary = JournalSummary(
        count=len(journal),
        headline=ru_count(len(journal), "запись", "записи", "записей"),
        subline=(f"последняя — {lowered}" if journal else "журнал пуст"),
    )
    rules = []
    for rule in world.rules:
        params = rule_params(rule)
        value, detail, muted = rule_presentation(world, rule.key, rule.enabled, params)
        rules.append(
            RuleOut(
                id=rule.id,
                key=rule.key,
                title=rule.title,
                value_label=value,
                value_muted=muted,
                detail=detail,
                enabled=rule.enabled,
                params=params,
                sort_order=rule.sort_order,
            )
        )
    enabled = sum(1 for rule in world.rules if rule.enabled)
    rule_summary = RuleSummary(
        enabled=enabled,
        total=len(world.rules),
        headline=f"{enabled} из {len(world.rules)}",
        subline=rules_subline(enabled),
    )
    bundle_count = len(world.bundles)
    home = HomeLabels(
        bundles_label=f"{bundle_count} {ru_plural(bundle_count, 'активная', 'активные', 'активных')}",
        geos_label=f"{len(active_geos)} {ru_plural(len(active_geos), 'страна', 'страны', 'стран')}",
        tasks_label=f"{total} на сегодня",
        journal_label=journal_summary.headline,
        rules_label=f"стоп {fmt_money(stop_limit)}",
    )
    return Snapshot(
        as_of=as_of,
        date_label=date_label(as_of),
        finance=finance,
        transactions=transactions,
        bundles=bundles,
        geos=geos,
        geo_summary=geo_summary,
        tasks=tasks,
        task_summary=task_summary,
        journal=journal,
        journal_summary=journal_summary,
        rules=rules,
        rule_summary=rule_summary,
        home=home,
    )
