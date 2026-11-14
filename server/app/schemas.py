from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, Field


class SeriesPoint(BaseModel):
    date: date
    profit: float


class FinanceDisplay(BaseModel):
    profit_today: str
    spend_today: str
    income_today: str
    roi_today: str
    stop_ratio: str
    balance: str
    reserve: str
    on_hold: str
    free: str
    invested: str
    returned: str
    break_even: str


class Finance(BaseModel):
    balance: float = Field(description="Резерв + свободно")
    reserve: float
    on_hold: float
    free: float
    invested: float
    returned: float
    break_even_ratio: float
    profit_today: float
    spend_today: float
    income_today: float
    roi_today_pct: float
    stop_limit: float
    stop_spent: float
    series: list[SeriesPoint]
    display: FinanceDisplay


class TransactionOut(BaseModel):
    id: int
    occurred_at: datetime
    title: str
    subtitle: str
    geo_name: str
    amount: float
    amount_label: str


class BundleOut(BaseModel):
    id: int
    title: str
    subtitle: str
    vertical: str
    geo_code: str
    traffic_source: str
    network: str
    payout_model: str
    status: Literal["profit", "test", "stop"] | str
    status_label: str
    spend: float
    revenue: float
    profit: float
    roi_pct: float
    clicks: int
    conversions: int
    spend_label: str
    profit_label: str
    roi_label: str
    sort_order: int


class GeoOut(BaseModel):
    id: int
    code: str
    name: str
    subtitle: str
    status: Literal["live", "test", "stop"] | str
    status_label: str
    cpc: float
    epc: float
    trend_pct: float
    cpc_label: str
    epc_label: str
    trend_label: str
    bundle_id: int | None
    sort_order: int


class GeoSummary(BaseModel):
    live_count: int = Field(description="Гео не в стопе: живые и тесты")
    stopped_count: int
    capital: float
    avg_cpc: float
    avg_epc: float
    capital_label: str
    avg_cpc_label: str
    avg_epc_label: str
    stopped_line: str


class TaskOut(BaseModel):
    id: int
    title: str
    detail: str
    note: str
    note_tone: str
    done: bool
    sort_order: int


class TaskSummary(BaseModel):
    done: int
    total: int
    open: int
    headline: str
    subline: str
    date_line: str


class JournalOut(BaseModel):
    id: int
    occurred_at: datetime
    date_label: str
    title: str
    reason: str
    result: str
    result_tone: str


class JournalSummary(BaseModel):
    count: int
    headline: str
    subline: str


class RuleOut(BaseModel):
    id: int
    key: str
    title: str
    value_label: str
    value_muted: bool
    detail: str
    enabled: bool
    params: dict[str, Any]
    sort_order: int


class RuleSummary(BaseModel):
    enabled: int
    total: int
    headline: str
    subline: str


class HomeLabels(BaseModel):
    bundles_label: str
    geos_label: str
    tasks_label: str
    journal_label: str
    rules_label: str


class Snapshot(BaseModel):
    as_of: date
    date_label: str
    finance: Finance
    transactions: list[TransactionOut]
    bundles: list[BundleOut]
    geos: list[GeoOut]
    geo_summary: GeoSummary
    tasks: list[TaskOut]
    task_summary: TaskSummary
    journal: list[JournalOut]
    journal_summary: JournalSummary
    rules: list[RuleOut]
    rule_summary: RuleSummary
    home: HomeLabels


class CheckItem(BaseModel):
    key: str
    title: str
    status: Literal["ok", "warning", "violation", "signal", "disabled"]
    message: str


class CheckReport(BaseModel):
    as_of: date
    items: list[CheckItem]
    violations: list[CheckItem]
    warnings: list[CheckItem]
    signals: list[CheckItem]


class TransactionIn(BaseModel):
    occurred_at: datetime | None = None
    title: str
    geo_name: str
    amount: float


class BundleIn(BaseModel):
    title: str
    subtitle: str = ""
    vertical: str
    geo_code: str
    traffic_source: str
    network: str
    payout_model: str = "CPA"
    status: Literal["profit", "test", "stop"] = "test"


class BundlePatch(BaseModel):
    title: str | None = None
    subtitle: str | None = None
    status: Literal["profit", "test", "stop"] | None = None


class StatIn(BaseModel):
    day: date
    spend: float = Field(ge=0)
    revenue: float = Field(ge=0)
    clicks: int = Field(ge=0, default=0)
    conversions: int = Field(ge=0, default=0)


class GeoIn(BaseModel):
    code: str
    name: str
    subtitle: str = ""
    status: Literal["live", "test", "stop"] = "test"
    cpc: float = 0
    epc: float = 0
    trend_pct: float = 0
    bundle_id: int | None = None


class GeoPatch(BaseModel):
    name: str | None = None
    subtitle: str | None = None
    status: Literal["live", "test", "stop"] | None = None
    cpc: float | None = None
    epc: float | None = None
    trend_pct: float | None = None


class TaskIn(BaseModel):
    title: str
    detail: str = ""
    note: str = ""
    note_tone: Literal["positive", "accent", "muted"] = "accent"


class TaskPatch(BaseModel):
    title: str | None = None
    detail: str | None = None
    note: str | None = None
    note_tone: Literal["positive", "accent", "muted"] | None = None
    done: bool | None = None


class JournalIn(BaseModel):
    occurred_at: datetime | None = None
    title: str
    reason: str
    result: str
    result_tone: Literal["positive", "negative", "neutral"] = "neutral"


class RulePatch(BaseModel):
    enabled: bool | None = None
    params: dict[str, Any] | None = None


class MutationIn(BaseModel):
    id: str
    entity: Literal["task", "rule", "journal", "bundle", "geo", "transaction", "bundle_stat"]
    op: Literal["create", "update"]
    payload: dict[str, Any]
    client_updated_at: datetime | None = None


class SyncIn(BaseModel):
    mutations: list[MutationIn]


class SyncConflict(BaseModel):
    id: str
    reason: str


class SyncResult(BaseModel):
    applied: list[str]
    conflicts: list[SyncConflict]
    snapshot: Snapshot
