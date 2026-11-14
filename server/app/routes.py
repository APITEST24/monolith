"""HTTP API. Writes return a fresh snapshot so the phone can replace its cache."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth import WRITE_ALL, WRITE_STATS, WRITE_SUMMARIES, READ, Principal, require
from app.database import get_db
from app.metrics import load_world, set_rule_params, touch
from app.models import AppliedMutation, Bundle, BundleStat, Geo, JournalEntry, Rule, Task, Transaction
from app.rules import check_rules
from app.schemas import (
    BundleIn,
    BundleOut,
    BundlePatch,
    CheckReport,
    GeoIn,
    GeoOut,
    GeoPatch,
    JournalIn,
    JournalOut,
    MutationIn,
    RuleOut,
    RulePatch,
    Snapshot,
    StatIn,
    SyncIn,
    SyncResult,
    TaskIn,
    TaskOut,
    TaskPatch,
    TransactionIn,
    TransactionOut,
)
from app.snapshot import build_snapshot

router = APIRouter(prefix="/api/v1", tags=["disciplina"])


def _now() -> datetime:
    return datetime.now().replace(microsecond=0)


def _snap(db: Session) -> Snapshot:
    return build_snapshot(load_world(db))


def _report(db: Session) -> CheckReport:
    world = load_world(db)
    items = check_rules(world)
    return CheckReport(
        as_of=world.account.reporting_date,
        items=items,
        violations=[item for item in items if item.status == "violation"],
        warnings=[item for item in items if item.status == "warning"],
        signals=[item for item in items if item.status == "signal"],
    )


def _get(db: Session, model, ident: int, label: str):
    row = db.get(model, ident)
    if row is None:
        raise HTTPException(status_code=404, detail=f"{label} не найдена" if label.endswith("а") or label.endswith("я") else f"{label} не найден")
    return row


@router.get("/snapshot", response_model=Snapshot, summary="Полный снимок для телефона")
def snapshot(db: Session = Depends(get_db), _: Principal = Depends(require(READ))) -> Snapshot:
    return _snap(db)


@router.get("/finance", summary="Финансы и ряд прибыли")
def finance(db: Session = Depends(get_db), _: Principal = Depends(require(READ))):
    return _snap(db).finance


@router.get("/transactions", response_model=list[TransactionOut])
def transactions(db: Session = Depends(get_db), _: Principal = Depends(require(READ))):
    return _snap(db).transactions


@router.post("/transactions", response_model=Snapshot, summary="Доход или расход")
def create_transaction(
    body: TransactionIn,
    db: Session = Depends(get_db),
    _: Principal = Depends(require(WRITE_STATS)),
) -> Snapshot:
    world = load_world(db)
    db.add(
        Transaction(
            occurred_at=body.occurred_at or datetime.combine(world.account.reporting_date, _now().time()),
            title=body.title.strip(),
            geo_name=body.geo_name.strip(),
            amount=round(body.amount, 2),
            updated_at=_now(),
        )
    )
    db.commit()
    return _snap(db)


@router.get("/bundles", response_model=list[BundleOut])
def bundles(
    status: str | None = None,
    db: Session = Depends(get_db),
    _: Principal = Depends(require(READ)),
):
    rows = _snap(db).bundles
    if status:
        rows = [row for row in rows if row.status == status]
    return rows


@router.post("/bundles", response_model=Snapshot)
def create_bundle(
    body: BundleIn,
    db: Session = Depends(get_db),
    _: Principal = Depends(require(WRITE_ALL)),
) -> Snapshot:
    subtitle = body.subtitle.strip() or f"{body.traffic_source} · {body.network} · {body.payout_model}"
    last = db.scalar(select(Bundle.sort_order).order_by(Bundle.sort_order.desc()).limit(1)) or 0
    db.add(
        Bundle(
            title=body.title.strip(),
            subtitle=subtitle,
            vertical=body.vertical.strip(),
            geo_code=body.geo_code.strip().upper(),
            traffic_source=body.traffic_source.strip(),
            network=body.network.strip(),
            payout_model=body.payout_model.strip(),
            status=body.status,
            sort_order=int(last) + 1,
            updated_at=_now(),
        )
    )
    db.commit()
    return _snap(db)


@router.patch("/bundles/{bundle_id}", response_model=Snapshot)
def patch_bundle(
    bundle_id: int,
    body: BundlePatch,
    db: Session = Depends(get_db),
    _: Principal = Depends(require(WRITE_ALL)),
) -> Snapshot:
    bundle = db.get(Bundle, bundle_id)
    if bundle is None:
        raise HTTPException(status_code=404, detail="Связка не найдена")
    if body.title is not None:
        bundle.title = body.title.strip()
    if body.subtitle is not None:
        bundle.subtitle = body.subtitle.strip()
    if body.status is not None:
        bundle.status = body.status
    touch(bundle)
    db.commit()
    return _snap(db)


@router.post("/bundles/{bundle_id}/stats", response_model=Snapshot, summary="Дневная статистика связки")
def upsert_stat(
    bundle_id: int,
    body: StatIn,
    db: Session = Depends(get_db),
    _: Principal = Depends(require(WRITE_STATS)),
) -> Snapshot:
    bundle = db.get(Bundle, bundle_id)
    if bundle is None:
        raise HTTPException(status_code=404, detail="Связка не найдена")
    existing = db.scalar(
        select(BundleStat).where(BundleStat.bundle_id == bundle_id, BundleStat.day == body.day)
    )
    if existing is None:
        existing = BundleStat(bundle_id=bundle_id, day=body.day, spend=0, revenue=0, clicks=0, conversions=0)
        db.add(existing)
    existing.spend = round(body.spend, 2)
    existing.revenue = round(body.revenue, 2)
    existing.clicks = body.clicks
    existing.conversions = body.conversions
    touch(bundle)
    db.commit()
    return _snap(db)


@router.get("/geos", response_model=list[GeoOut])
def geos(db: Session = Depends(get_db), _: Principal = Depends(require(READ))):
    return _snap(db).geos


@router.post("/geos", response_model=Snapshot)
def create_geo(
    body: GeoIn,
    db: Session = Depends(get_db),
    _: Principal = Depends(require(WRITE_ALL)),
) -> Snapshot:
    if body.bundle_id is not None and db.get(Bundle, body.bundle_id) is None:
        raise HTTPException(status_code=404, detail="Связка не найдена")
    last = db.scalar(select(Geo.sort_order).order_by(Geo.sort_order.desc()).limit(1)) or 0
    db.add(
        Geo(
            code=body.code.strip().upper(),
            name=body.name.strip(),
            subtitle=body.subtitle.strip(),
            status=body.status,
            cpc=round(body.cpc, 4),
            epc=round(body.epc, 4),
            trend_pct=round(body.trend_pct, 2),
            bundle_id=body.bundle_id,
            sort_order=int(last) + 1,
            updated_at=_now(),
        )
    )
    db.commit()
    return _snap(db)


@router.patch("/geos/{geo_id}", response_model=Snapshot)
def patch_geo(
    geo_id: int,
    body: GeoPatch,
    db: Session = Depends(get_db),
    principal: Principal = Depends(require(READ)),
) -> Snapshot:
    # Bots may update measured rates. Status changes stay with the phone.
    changing_status = body.status is not None
    changing_copy = body.name is not None or body.subtitle is not None
    changing_rates = body.cpc is not None or body.epc is not None or body.trend_pct is not None
    if changing_status or changing_copy:
        if not principal.allows(WRITE_ALL):
            raise HTTPException(status_code=403, detail="Этому ключу нельзя менять статус гео")
    elif changing_rates:
        if not principal.allows(WRITE_STATS):
            raise HTTPException(status_code=403, detail="Этому ключу нельзя менять ставки")
    geo = db.get(Geo, geo_id)
    if geo is None:
        raise HTTPException(status_code=404, detail="Гео не найдено")
    if body.name is not None:
        geo.name = body.name.strip()
    if body.subtitle is not None:
        geo.subtitle = body.subtitle.strip()
    if body.status is not None:
        geo.status = body.status
    if body.cpc is not None:
        geo.cpc = round(body.cpc, 4)
    if body.epc is not None:
        geo.epc = round(body.epc, 4)
    if body.trend_pct is not None:
        geo.trend_pct = round(body.trend_pct, 2)
    touch(geo)
    db.commit()
    return _snap(db)


@router.get("/tasks", response_model=list[TaskOut])
def tasks(db: Session = Depends(get_db), _: Principal = Depends(require(READ))):
    return _snap(db).tasks


@router.post("/tasks", response_model=Snapshot)
def create_task(
    body: TaskIn,
    db: Session = Depends(get_db),
    _: Principal = Depends(require(WRITE_ALL)),
) -> Snapshot:
    last = db.scalar(select(Task.sort_order).order_by(Task.sort_order.desc()).limit(1)) or 0
    db.add(
        Task(
            title=body.title.strip(),
            detail=body.detail.strip(),
            note=body.note.strip(),
            note_tone=body.note_tone,
            done=False,
            sort_order=int(last) + 1,
            updated_at=_now(),
        )
    )
    db.commit()
    return _snap(db)


@router.patch("/tasks/{task_id}", response_model=Snapshot)
def patch_task(
    task_id: int,
    body: TaskPatch,
    db: Session = Depends(get_db),
    _: Principal = Depends(require(WRITE_ALL)),
) -> Snapshot:
    task = db.get(Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Задача не найдена")
    _apply_task_patch(task, body.model_dump(exclude_unset=True))
    db.commit()
    return _snap(db)


def _apply_task_patch(task: Task, payload: dict) -> None:
    if "title" in payload and payload["title"] is not None:
        task.title = str(payload["title"]).strip()
    if "detail" in payload and payload["detail"] is not None:
        task.detail = str(payload["detail"]).strip()
    if "note" in payload and payload["note"] is not None:
        task.note = str(payload["note"]).strip()
    if "note_tone" in payload and payload["note_tone"] is not None:
        task.note_tone = str(payload["note_tone"])
    if "done" in payload and payload["done"] is not None:
        task.done = bool(payload["done"])
    touch(task)


@router.get("/journal", response_model=list[JournalOut])
def journal(db: Session = Depends(get_db), _: Principal = Depends(require(READ))):
    return _snap(db).journal


@router.post("/journal", response_model=Snapshot, summary="Запись журнала решений")
def create_journal(
    body: JournalIn,
    db: Session = Depends(get_db),
    _: Principal = Depends(require(WRITE_SUMMARIES)),
) -> Snapshot:
    world = load_world(db)
    occurred = body.occurred_at or datetime.combine(world.account.reporting_date, _now().time())
    db.add(
        JournalEntry(
            occurred_at=occurred,
            title=body.title.strip(),
            reason=body.reason.strip(),
            result=body.result.strip(),
            result_tone=body.result_tone,
            updated_at=_now(),
        )
    )
    db.commit()
    return _snap(db)


@router.get("/rules", response_model=list[RuleOut])
def rules(db: Session = Depends(get_db), _: Principal = Depends(require(READ))):
    return _snap(db).rules


@router.get("/rules/check", response_model=CheckReport, summary="Сверка статистики с правилами")
def rules_check(db: Session = Depends(get_db), _: Principal = Depends(require(READ))) -> CheckReport:
    return _report(db)


@router.patch("/rules/{rule_id}", response_model=Snapshot)
def patch_rule(
    rule_id: int,
    body: RulePatch,
    db: Session = Depends(get_db),
    _: Principal = Depends(require(WRITE_ALL)),
) -> Snapshot:
    rule = db.get(Rule, rule_id)
    if rule is None:
        raise HTTPException(status_code=404, detail="Правило не найдено")
    _apply_rule_patch(rule, body.model_dump(exclude_unset=True))
    db.commit()
    return _snap(db)


def _apply_rule_patch(rule: Rule, payload: dict) -> None:
    if "enabled" in payload and payload["enabled"] is not None:
        rule.enabled = bool(payload["enabled"])
    if "params" in payload and payload["params"] is not None:
        current = {}
        from app.metrics import rule_params

        current.update(rule_params(rule))
        current.update(payload["params"])
        set_rule_params(rule, current)
    touch(rule)


@router.post("/sync", response_model=SyncResult, summary="Пакет правок, накопленных без сети")
def sync(
    body: SyncIn,
    db: Session = Depends(get_db),
    principal: Principal = Depends(require(READ)),
) -> SyncResult:
    applied: list[str] = []
    conflicts = []
    for mutation in body.mutations:
        if db.get(AppliedMutation, mutation.id) is not None:
            applied.append(mutation.id)
            continue
        try:
            _apply_mutation(db, principal, mutation)
        except HTTPException as exc:
            conflicts.append({"id": mutation.id, "reason": str(exc.detail)})
            db.rollback()
            continue
        db.add(AppliedMutation(id=mutation.id, applied_at=_now()))
        db.commit()
        applied.append(mutation.id)
    return SyncResult(applied=applied, conflicts=conflicts, snapshot=_snap(db))


def _action_for(mutation: MutationIn) -> str:
    if mutation.entity == "journal" and mutation.op == "create":
        return WRITE_SUMMARIES
    if mutation.entity == "bundle_stat" or (
        mutation.entity == "transaction" and mutation.op == "create"
    ):
        return WRITE_STATS
    if mutation.entity == "geo" and mutation.op == "update":
        payload = mutation.payload
        if any(key in payload for key in ("status", "name", "subtitle")):
            return WRITE_ALL
        return WRITE_STATS
    return WRITE_ALL


def _apply_mutation(db: Session, principal: Principal, mutation: MutationIn) -> None:
    action = _action_for(mutation)
    if not principal.allows(action):
        raise HTTPException(status_code=403, detail="Этому ключу нельзя выполнять это действие")
    payload = mutation.payload
    when = mutation.client_updated_at
    if mutation.entity == "task" and mutation.op == "update":
        task = db.get(Task, int(payload["id"]))
        if task is None:
            raise HTTPException(status_code=404, detail="Задача не найдена")
        if when is not None and task.updated_at > when.replace(tzinfo=None):
            raise HTTPException(status_code=409, detail="На сервере более новая версия задачи")
        _apply_task_patch(task, payload)
        return
    if mutation.entity == "rule" and mutation.op == "update":
        rule = db.get(Rule, int(payload["id"]))
        if rule is None:
            raise HTTPException(status_code=404, detail="Правило не найдено")
        if when is not None and rule.updated_at > when.replace(tzinfo=None):
            raise HTTPException(status_code=409, detail="На сервере более новая версия правила")
        _apply_rule_patch(rule, payload)
        return
    if mutation.entity == "journal" and mutation.op == "create":
        create_payload = JournalIn.model_validate(payload)
        world = load_world(db)
        occurred = create_payload.occurred_at or datetime.combine(
            world.account.reporting_date, _now().time()
        )
        db.add(
            JournalEntry(
                occurred_at=occurred,
                title=create_payload.title.strip(),
                reason=create_payload.reason.strip(),
                result=create_payload.result.strip(),
                result_tone=create_payload.result_tone,
                updated_at=_now(),
            )
        )
        return
    if mutation.entity == "transaction" and mutation.op == "create":
        create_payload = TransactionIn.model_validate(payload)
        world = load_world(db)
        db.add(
            Transaction(
                occurred_at=create_payload.occurred_at
                or datetime.combine(world.account.reporting_date, _now().time()),
                title=create_payload.title.strip(),
                geo_name=create_payload.geo_name.strip(),
                amount=round(create_payload.amount, 2),
                updated_at=_now(),
            )
        )
        return
    if mutation.entity == "bundle" and mutation.op == "create":
        create_payload = BundleIn.model_validate(payload)
        last = db.scalar(select(Bundle.sort_order).order_by(Bundle.sort_order.desc()).limit(1)) or 0
        subtitle = create_payload.subtitle.strip() or (
            f"{create_payload.traffic_source} · {create_payload.network} · {create_payload.payout_model}"
        )
        db.add(
            Bundle(
                title=create_payload.title.strip(),
                subtitle=subtitle,
                vertical=create_payload.vertical.strip(),
                geo_code=create_payload.geo_code.strip().upper(),
                traffic_source=create_payload.traffic_source.strip(),
                network=create_payload.network.strip(),
                payout_model=create_payload.payout_model.strip(),
                status=create_payload.status,
                sort_order=int(last) + 1,
                updated_at=_now(),
            )
        )
        return
    if mutation.entity == "bundle_stat" and mutation.op == "create":
        bundle_id = int(payload["bundle_id"])
        if db.get(Bundle, bundle_id) is None:
            raise HTTPException(status_code=404, detail="Связка не найдена")
        body = StatIn.model_validate(payload)
        existing = db.scalar(
            select(BundleStat).where(BundleStat.bundle_id == bundle_id, BundleStat.day == body.day)
        )
        if existing is None:
            existing = BundleStat(
                bundle_id=bundle_id, day=body.day, spend=0, revenue=0, clicks=0, conversions=0
            )
            db.add(existing)
        existing.spend = round(body.spend, 2)
        existing.revenue = round(body.revenue, 2)
        existing.clicks = body.clicks
        existing.conversions = body.conversions
        return
    if mutation.entity == "geo" and mutation.op == "create":
        create_payload = GeoIn.model_validate(payload)
        last = db.scalar(select(Geo.sort_order).order_by(Geo.sort_order.desc()).limit(1)) or 0
        db.add(
            Geo(
                code=create_payload.code.strip().upper(),
                name=create_payload.name.strip(),
                subtitle=create_payload.subtitle.strip(),
                status=create_payload.status,
                cpc=round(create_payload.cpc, 4),
                epc=round(create_payload.epc, 4),
                trend_pct=round(create_payload.trend_pct, 2),
                bundle_id=create_payload.bundle_id,
                sort_order=int(last) + 1,
                updated_at=_now(),
            )
        )
        return
    if mutation.entity == "geo" and mutation.op == "update":
        geo = db.get(Geo, int(payload["id"]))
        if geo is None:
            raise HTTPException(status_code=404, detail="Гео не найдено")
        patch = GeoPatch.model_validate(payload)
        data = patch.model_dump(exclude_unset=True)
        if "name" in data and data["name"] is not None:
            geo.name = data["name"].strip()
        if "subtitle" in data and data["subtitle"] is not None:
            geo.subtitle = data["subtitle"].strip()
        if "status" in data and data["status"] is not None:
            geo.status = data["status"]
        if "cpc" in data and data["cpc"] is not None:
            geo.cpc = round(data["cpc"], 4)
        if "epc" in data and data["epc"] is not None:
            geo.epc = round(data["epc"], 4)
        if "trend_pct" in data and data["trend_pct"] is not None:
            geo.trend_pct = round(data["trend_pct"], 2)
        touch(geo)
        return
    raise HTTPException(status_code=400, detail="Неизвестная операция синхронизации")
