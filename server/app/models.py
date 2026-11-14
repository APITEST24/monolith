from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class Account(Base):
    __tablename__ = "account"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    reporting_date: Mapped[date] = mapped_column(Date, nullable=False)
    invested: Mapped[float] = mapped_column(Float, nullable=False)
    returned: Mapped[float] = mapped_column(Float, nullable=False)
    reserve: Mapped[float] = mapped_column(Float, nullable=False)
    on_hold: Mapped[float] = mapped_column(Float, nullable=False)
    free: Mapped[float] = mapped_column(Float, nullable=False)


class PnLPoint(Base):
    __tablename__ = "pnl_points"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    day: Mapped[date] = mapped_column(Date, nullable=False, unique=True)
    profit: Mapped[float] = mapped_column(Float, nullable=False)


class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    geo_name: Mapped[str] = mapped_column(String(80), nullable=False)
    amount: Mapped[float] = mapped_column(Float, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)


class Bundle(Base):
    __tablename__ = "bundles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    subtitle: Mapped[str] = mapped_column(String(200), nullable=False)
    vertical: Mapped[str] = mapped_column(String(80), nullable=False)
    geo_code: Mapped[str] = mapped_column(String(8), nullable=False)
    traffic_source: Mapped[str] = mapped_column(String(80), nullable=False)
    network: Mapped[str] = mapped_column(String(80), nullable=False)
    payout_model: Mapped[str] = mapped_column(String(16), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)

    stats: Mapped[list["BundleStat"]] = relationship(
        back_populates="bundle",
        cascade="all, delete-orphan",
    )


class BundleStat(Base):
    __tablename__ = "bundle_stats"
    __table_args__ = (UniqueConstraint("bundle_id", "day", name="uq_bundle_day"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    bundle_id: Mapped[int] = mapped_column(ForeignKey("bundles.id"), nullable=False)
    day: Mapped[date] = mapped_column(Date, nullable=False)
    spend: Mapped[float] = mapped_column(Float, nullable=False)
    revenue: Mapped[float] = mapped_column(Float, nullable=False)
    clicks: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    conversions: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    bundle: Mapped[Bundle] = relationship(back_populates="stats")


class Geo(Base):
    __tablename__ = "geos"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    code: Mapped[str] = mapped_column(String(8), nullable=False)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    subtitle: Mapped[str] = mapped_column(String(200), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    cpc: Mapped[float] = mapped_column(Float, nullable=False)
    epc: Mapped[float] = mapped_column(Float, nullable=False)
    trend_pct: Mapped[float] = mapped_column(Float, nullable=False)
    bundle_id: Mapped[int | None] = mapped_column(ForeignKey("bundles.id"), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)


class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    detail: Mapped[str] = mapped_column(Text, nullable=False)
    note: Mapped[str] = mapped_column(Text, nullable=False, default="")
    note_tone: Mapped[str] = mapped_column(String(16), nullable=False, default="muted")
    done: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)


class JournalEntry(Base):
    __tablename__ = "journal"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    title: Mapped[str] = mapped_column(String(240), nullable=False)
    reason: Mapped[str] = mapped_column(Text, nullable=False)
    result: Mapped[str] = mapped_column(Text, nullable=False)
    result_tone: Mapped[str] = mapped_column(String(16), nullable=False, default="neutral")
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)


class Rule(Base):
    __tablename__ = "rules"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    key: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    params_json: Mapped[str] = mapped_column(Text, nullable=False, default="{}")
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)


class AppliedMutation(Base):
    __tablename__ = "applied_mutations"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    applied_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
