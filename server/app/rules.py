"""Compare live stats with the operator's rules.

Statuses:
- ok: the rule holds
- warning: still inside the limit, but close (daily spend >= 75%)
- violation: the limit is broken and the operator has not acted
- signal: a scale rule is ready, not a breach
- disabled: the rule is switched off
"""

from __future__ import annotations

from datetime import date, timedelta

from app.metrics import Rollup, World, rule_params
from app.models import Bundle, BundleStat
from app.ru import fmt_money, ru_plural
from app.schemas import CheckItem


def streak_ending(stats: list[BundleStat], as_of: date, threshold: float) -> int:
    by_day = {row.day: row for row in stats}
    streak = 0
    day = as_of
    while streak < 120:
        row = by_day.get(day)
        if row is None or row.spend <= 0:
            break
        roi = (row.revenue - row.spend) / row.spend * 100
        if roi + 1e-9 < threshold:
            break
        streak += 1
        day -= timedelta(days=1)
    return streak


def _daily_detail(spent: float, limit: float) -> str:
    if spent > limit + 0.001:
        return (
            f"Сегодня расход {fmt_money(spent)} · лимит пробит на {fmt_money(spent - limit)}"
        )
    return f"Сегодня расход {fmt_money(spent)} · осталось {fmt_money(limit - spent)}"


def _reserve_detail(percent: float, invested: float) -> str:
    pct = int(round(percent))
    return f"{pct}% от {fmt_money(invested)}, не использовать в тестах"


def _scale_detail(days: int, threshold: float) -> str:
    return f"После {int(days)} дней при ROI выше {int(round(threshold))}%"


def _tests_detail(names: list[str]) -> str:
    n = len(names)
    if n == 0:
        return "Сейчас открытых тестов нет"
    word = ru_plural(n, "тест", "теста", "тестов")
    if n == 1:
        listed = names[0]
    elif n == 2:
        listed = f"{names[0]} и {names[1]}"
    else:
        listed = ", ".join(names[:-1]) + " и " + names[-1]
    return f"Сейчас открыто {n} {word} — {listed}"


def _withdraw_detail(returned: float, invested: float) -> str:
    return f"Пока вернулось {fmt_money(returned)} из {fmt_money(invested)}"


def rule_presentation(world: World, rule_key: str, enabled: bool, params: dict) -> tuple[str, str, bool]:
    """value_label, detail, value_muted for the rules screen."""
    account = world.account
    if rule_key == "daily_stop_loss":
        limit = float(params.get("limit", 0))
        return fmt_money(limit), _daily_detail(world.spend_today, limit), False
    if rule_key == "bundle_stop_loss":
        return fmt_money(float(params.get("limit", 0))), "При достижении связка уходит в стоп", False
    if rule_key == "capital_reserve":
        return (
            fmt_money(float(params.get("amount", account.reserve))),
            _reserve_detail(float(params.get("percent", 0)), account.invested),
            False,
        )
    if rule_key == "scale_step":
        return (
            f"{int(round(float(params.get('percent', 0))))}%",
            _scale_detail(int(params.get("days", 7)), float(params.get("roi_threshold", 50))),
            False,
        )
    if rule_key == "test_limit":
        names = [
            bundle.title.split("·")[-1].strip()
            for bundle, _rollup in world.bundles
            if bundle.status == "test"
        ]
        return str(int(params.get("limit", 0))), _tests_detail(names), False
    if rule_key == "withdraw_to_zero":
        label = "ВЫКЛ" if not enabled else "ВКЛ"
        return label, _withdraw_detail(account.returned, account.invested), not enabled
    return "", "", False


def check_rules(world: World) -> list[CheckItem]:
    by_key = {rule.key: rule for rule in world.rules}
    items: list[CheckItem] = []
    for rule in world.rules:
        params = rule_params(rule)
        items.append(_check_one(world, rule.key, rule.title, rule.enabled, params, by_key))
    return items


def _check_one(
    world: World,
    key: str,
    title: str,
    enabled: bool,
    params: dict,
    _by_key: dict,
) -> CheckItem:
    if not enabled and key != "withdraw_to_zero":
        return CheckItem(key=key, title=title, status="disabled", message="Правило выключено")
    if key == "daily_stop_loss":
        limit = float(params.get("limit", 0))
        spent = world.spend_today
        detail = _daily_detail(spent, limit)
        if spent > limit + 0.001:
            status = "violation"
        elif limit > 0 and spent >= limit * 0.75:
            status = "warning"
        else:
            status = "ok"
        return CheckItem(key=key, title=title, status=status, message=detail)
    if key == "bundle_stop_loss":
        return _check_bundle_stop(world, title, float(params.get("limit", 0)))
    if key == "capital_reserve":
        percent = float(params.get("percent", 0))
        required = round(world.account.invested * percent / 100, 2)
        actual = world.account.reserve
        if actual + 0.009 < required:
            return CheckItem(
                key=key,
                title=title,
                status="violation",
                message=f"Резерв {fmt_money(actual)} меньше нормы {fmt_money(required)}",
            )
        return CheckItem(
            key=key,
            title=title,
            status="ok",
            message=_reserve_detail(percent, world.account.invested),
        )
    if key == "scale_step":
        return _check_scale(world, title, params)
    if key == "test_limit":
        names = [
            bundle.title.split("·")[-1].strip()
            for bundle, _rollup in world.bundles
            if bundle.status == "test"
        ]
        limit = int(params.get("limit", 0))
        detail = _tests_detail(names)
        status = "violation" if len(names) > limit else "ok"
        if status == "violation":
            detail = f"{detail}. Лимит — {limit}"
        return CheckItem(key=key, title=title, status=status, message=detail)
    if key == "withdraw_to_zero":
        detail = _withdraw_detail(world.account.returned, world.account.invested)
        if not enabled:
            return CheckItem(
                key=key,
                title=title,
                status="disabled",
                message=f"Правило выключено. {detail}",
            )
        if world.account.returned + 0.009 < world.account.invested:
            return CheckItem(
                key=key,
                title=title,
                status="ok",
                message=f"Вывод закрыт до безубыточности. {detail}",
            )
        return CheckItem(
            key=key,
            title=title,
            status="ok",
            message=f"Безубыточность достигнута, вывод разрешён. {detail}",
        )
    return CheckItem(key=key, title=title, status="ok", message="")


def _losing_over_limit(bundle: Bundle, roll: Rollup, limit: float) -> bool:
    return roll.spend + 0.001 >= limit and roll.roi_pct < 0 and bundle.status != "stop"


def _check_bundle_stop(world: World, title: str, limit: float) -> CheckItem:
    breached: list[str] = []
    parked: list[str] = []
    for bundle, roll in world.bundles:
        if roll.spend + 0.001 < limit or roll.roi_pct >= 0:
            continue
        if bundle.status == "stop":
            parked.append(bundle.title)
        else:
            breached.append(
                f"{bundle.title} — расход {fmt_money(roll.spend)}, ROI {int(round(roll.roi_pct))}%"
            )
    if breached:
        listed = "; ".join(breached)
        return CheckItem(
            key="bundle_stop_loss",
            title=title,
            status="violation",
            message=f"Стоп-лосс связки: {listed}. Связку нужно остановить.",
        )
    parked_note = f" В стопе: {', '.join(parked)}." if parked else ""
    return CheckItem(
        key="bundle_stop_loss",
        title=title,
        status="ok",
        message=f"Убыточных связок с расходом от {fmt_money(limit)} вне стопа нет.{parked_note}",
    )


def _check_scale(world: World, title: str, params: dict) -> CheckItem:
    days = int(params.get("days", 7))
    threshold = float(params.get("roi_threshold", 50))
    step = int(round(float(params.get("percent", 0))))
    ready: list[str] = []
    for bundle, roll in world.bundles:
        if bundle.status != "profit":
            continue
        streak = streak_ending(roll.days, world.account.reporting_date, threshold)
        if streak >= days:
            ready.append(
                f"{bundle.title}: ROI выше {int(round(threshold))}% уже {streak} дней подряд"
            )
    if not ready:
        return CheckItem(
            key="scale_step",
            title=title,
            status="ok",
            message="Нет связок, которые пора масштабировать",
        )
    return CheckItem(
        key="scale_step",
        title=title,
        status="signal",
        message="; ".join(ready) + f". Шаг {step}%.",
    )
