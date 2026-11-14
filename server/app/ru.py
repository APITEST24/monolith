"""Russian copy and money labels. These strings are what the iOS app shows."""

from datetime import date, datetime, timedelta

MONTHS = [
    "",
    "января",
    "февраля",
    "марта",
    "апреля",
    "мая",
    "июня",
    "июля",
    "августа",
    "сентября",
    "октября",
    "ноября",
    "декабря",
]

WEEKDAYS = [
    "Понедельник",
    "Вторник",
    "Среда",
    "Четверг",
    "Пятница",
    "Суббота",
    "Воскресенье",
]

DOT = "·"


def ru_plural(n: int, one: str, few: str, many: str) -> str:
    n = abs(int(n))
    n10 = n % 10
    n100 = n % 100
    if n10 == 1 and n100 != 11:
        return one
    if 2 <= n10 <= 4 and not (12 <= n100 <= 14):
        return few
    return many


def ru_count(n: int, one: str, few: str, many: str) -> str:
    return f"{n} {ru_plural(n, one, few, many)}"


def fmt_money(value: float, *, cents: bool | None = None, signed: bool = False) -> str:
    negative = value < -0.0000001
    mag = abs(float(value))
    mag = round(mag + 1e-9, 2)
    if cents is None:
        cents = abs(mag - round(mag)) > 0.001
    if cents:
        body = f"{mag:,.2f}"
    else:
        body = f"{int(round(mag)):,}"
    body = body.replace(",", " ")
    if negative:
        sign = "-"
    elif signed and mag > 0.0000001:
        sign = "+"
    else:
        sign = ""
    return f"{sign}${body}"


def fmt_roi(pct: float) -> str:
    return f"{int(round(pct))}%"


def fmt_trend(pct: float) -> str:
    rounded = int(round(pct))
    if rounded > 0:
        return f"↑ {rounded}%"
    if rounded < 0:
        return f"↓ {abs(rounded)}%"
    return "0%"


def date_label(day: date) -> str:
    return f"{WEEKDAYS[day.weekday()]}, {day.day} {MONTHS[day.month]}"


def clock(dt: datetime) -> str:
    return dt.strftime("%H:%M")


def journal_date_label(dt: datetime, as_of: date) -> str:
    hhmm = clock(dt)
    if dt.date() == as_of:
        return f"Сегодня, {hhmm}"
    if dt.date() == as_of - timedelta(days=1):
        return f"Вчера, {hhmm}"
    return f"{dt.day} {MONTHS[dt.month]}, {hhmm}"


def transaction_subtitle(dt: datetime, as_of: date, geo: str) -> str:
    if dt.date() == as_of:
        return f"Сегодня, {clock(dt)} {DOT} {geo}"
    if dt.date() == as_of - timedelta(days=1):
        return f"Вчера {DOT} {geo}"
    return f"{dt.day} {MONTHS[dt.month]} {DOT} {geo}"


def task_open_subline(open_count: int) -> str:
    words = {
        0: "все задачи закрыты",
        1: "одна задача ещё открыта",
        2: "две задачи ещё открыты",
        3: "три задачи ещё открыты",
        4: "четыре задачи ещё открыты",
    }
    if open_count in words:
        return words[open_count]
    return f"{ru_count(open_count, 'задача', 'задачи', 'задач')} ещё открыты"


def rules_subline(enabled: int) -> str:
    if enabled == 0:
        return "все правила выключены"
    if enabled == 1:
        return "правило сейчас включено"
    return "правил сейчас включены"
