import type { Bundle, Geo, Journal, Rule, Snapshot, Task } from "./types";
import { money, state } from "./state";

const BACK = `<svg viewBox="0 0 24 24" width="15" height="15" aria-hidden="true"><path d="M14.5 5.5 8 12l6.5 6.5" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
const PLUS = `<svg viewBox="0 0 24 24" width="15" height="15" aria-hidden="true"><path d="M12 5v14M5 12h14" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>`;
const CLOCK = `<svg viewBox="0 0 24 24" width="15" height="15" aria-hidden="true"><circle cx="12" cy="12" r="7.2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 8.2V12l2.6 2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`;
const MORE = `<svg viewBox="0 0 24 24" width="15" height="15" aria-hidden="true"><circle cx="6" cy="12" r="1.35" fill="currentColor"/><circle cx="12" cy="12" r="1.35" fill="currentColor"/><circle cx="18" cy="12" r="1.35" fill="currentColor"/></svg>`;
const CHECK = `<svg viewBox="0 0 24 24" width="13" height="13" aria-hidden="true"><path d="M5 12.5 9.2 17 19 7" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
const LOCK = `<svg viewBox="0 0 24 24" width="28" height="28" aria-hidden="true"><rect x="6" y="10.5" width="12" height="9" rx="2" fill="none" stroke="#fff" stroke-width="1.8"/><path d="M8.2 10.5V8.2a3.8 3.8 0 0 1 7.6 0v2.3" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round"/></svg>`;

function esc(value: string): string {
  return value.replace(/[&<>"']/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[ch] ?? ch);
}

function jelly(skin: string, extra: string, body: string, calm = false): string {
  return `<div class="jelly ${calm ? "calm" : ""} ${skin} ${extra}">
    <div class="deep"></div><div class="slab"></div>
    <div class="jelly-face"><div class="wash"></div><div class="gloss"></div><div class="gloss-soft"></div>
      <div class="jelly-body">${body}</div>
    </div>
  </div>`;
}

function icon(action: string, glyph: string, label: string): string {
  return `<button class="icon-btn" type="button" data-action="${action}" aria-label="${label}">${glyph}</button>`;
}

function header(title: string, trailing: "plus" | "clock" | "more" | null, action: string): string {
  const trail =
    trailing === "plus"
      ? icon(action, PLUS, "Добавить")
      : trailing === "clock"
        ? icon(action, CLOCK, "Период")
        : trailing === "more"
          ? icon(action, MORE, "Меню")
          : `<span class="icon-btn" style="visibility:hidden"></span>`;
  return `<header class="screen-head">
    ${icon("back", BACK, "Назад")}
    <div class="screen-title t-nav">${esc(title)}</div>
    ${trail}
  </header>`;
}

function bar(fraction: number, kind: "amber" | "teal"): string {
  const tone = state.mono ? "bar-mono" : kind === "amber" ? "bar-amber" : "bar-teal";
  const width = Math.max(0, Math.min(1, fraction)) * 100;
  return `<div class="bar ${tone}"><span style="width:max(8px, ${width}%)"></span></div>`;
}

function pill(title: string, status: string): string {
  const kind = ["profit", "live", "test", "stop"].includes(status) ? status : "other";
  return `<span class="pill ${kind}">${esc(title)}</span>`;
}

function note(): string {
  if (!state.note || state.route !== "home") return "";
  return `<div class="note">${esc(state.note)}</div>`;
}

function home(snap: Snapshot): string {
  const display = snap.finance.display;
  const fraction = snap.finance.stop_limit > 0 ? snap.finance.stop_spent / snap.finance.stop_limit : 0;
  const finance = jelly(
    "skin-finance",
    "hero-finance",
    `<div class="t-strong" style="font-size:15px;letter-spacing:-0.3px">Финансы</div>
     <div class="hero-gap"></div>
     <div class="t-kicker onhero">Сегодня</div>
     <div class="hero-profit">${esc(display.profit_today)}</div>
     <div class="hero-sub onhero">прибыль за день</div>
     <div class="hero-spacer"></div>
     <div class="well"><div class="metrics">
       <div class="metric"><div class="k">Расход</div><div class="v">${esc(display.spend_today)}</div></div>
       <div class="metric split"><div class="k">Доход</div><div class="v">${esc(display.income_today)}</div></div>
       <div class="metric split"><div class="k">ROI</div><div class="v">${esc(display.roi_today)}</div></div>
     </div></div>
     <div class="stop-row">
       <span class="t-label onhero">Стоп-лосс дня</span>
       <span class="t-demi">${esc(display.stop_ratio)}</span>
     </div>
     ${bar(fraction, "amber")}`,
  );
  const peeks: [string, string, string, string, string][] = [
    ["bundles", "Связки", snap.home.bundles_label, "skin-bundles peek-bundles", "peek-0"],
    ["geo", "Гео", snap.home.geos_label, "skin-geo", "peek-1"],
    ["tasks", "Задачи", snap.home.tasks_label, "skin-tasks", "peek-2"],
    ["journal", "Журнал решений", snap.home.journal_label, "skin-journal", "peek-3"],
    ["rules", "Правила", snap.home.rules_label, "skin-rules", "peek-4"],
  ];
  const rows = peeks
    .map(
      ([route, title, meta, skin, mono]) =>
        `<button class="card-hit" type="button" data-go="${route}">${jelly(
          `${skin} ${mono} peek`,
          "",
          `<span class="name">${esc(title)}</span><span class="meta">${esc(meta)}</span>`,
        )}</button>`,
    )
    .join("");
  const financeLink = `<button class="card-hit" type="button" data-go="finance">${finance}</button>`;
  return `<section class="screen" data-screen="home">
    <header class="home-head">
      <div class="home-titles">
        <div class="t-title">Дисциплина</div>
        <div class="t-date">${esc(snap.date_label)}</div>
      </div>
      <div class="grow"></div>
      <button class="dot-btn" type="button" data-action="settings" aria-label="Меню"><i></i><i></i><i></i></button>
    </header>
    ${note()}
    <div class="scroll"><div class="stack">${financeLink}${rows}</div></div>
  </section>`;
}

function chart(series: Snapshot["finance"]["series"]): string {
  const width = 360;
  const height = 80;
  const profits = series.map((point) => point.profit);
  const max = Math.max(...profits, 0);
  const min = Math.min(0, ...profits);
  const span = max - min || 1;
  const points = series.map((point, index) => {
    const x = series.length === 1 ? width / 2 : (index / (series.length - 1)) * width;
    const y = height - ((point.profit - min) / span) * (height - 8) - 4;
    return { x, y };
  });
  const line = catmull(points);
  const last = points[points.length - 1];
  const area = `${line} L ${last?.x ?? width} ${height} L ${points[0]?.x ?? 0} ${height} Z`;
  const stroke = state.mono ? "#d8d8d4" : "#7ad4c8";
  const top = state.mono ? "rgba(255,255,255,.28)" : "rgba(44,184,168,.38)";
  return `<svg class="chart" viewBox="0 0 ${width} ${height}" preserveAspectRatio="none" aria-hidden="true">
    <defs><linearGradient id="area" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${top}"/><stop offset="1" stop-color="${top}" stop-opacity="0"/>
    </linearGradient></defs>
    <path d="${area}" fill="url(#area)"></path>
    <path d="${line}" fill="none" stroke="${stroke}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke"></path>
    ${last ? `<circle cx="${last.x}" cy="${last.y}" r="3.2" fill="${state.mono ? "#f2f2f0" : "#f3eee9"}"></circle>` : ""}
  </svg>`;
}

function catmull(points: { x: number; y: number }[]): string {
  if (!points.length) return "";
  if (points.length === 1) return `M ${points[0].x} ${points[0].y}`;
  let d = `M ${points[0].x.toFixed(2)} ${points[0].y.toFixed(2)}`;
  for (let i = 0; i < points.length - 1; i += 1) {
    const p0 = points[i - 1] ?? points[i];
    const p1 = points[i];
    const p2 = points[i + 1];
    const p3 = points[i + 2] ?? p2;
    const c1x = p1.x + (p2.x - p0.x) / 6;
    const c1y = p1.y + (p2.y - p0.y) / 6;
    const c2x = p2.x - (p3.x - p1.x) / 6;
    const c2y = p2.y - (p3.y - p1.y) / 6;
    d += ` C ${c1x.toFixed(2)} ${c1y.toFixed(2)}, ${c2x.toFixed(2)} ${c2y.toFixed(2)}, ${p2.x.toFixed(2)} ${p2.y.toFixed(2)}`;
  }
  return d;
}

function finance(snap: Snapshot): string {
  const display = snap.finance.display;
  const balance = jelly(
    "skin-finance",
    "",
    `<div class="pad-card">
      <div class="t-kicker onhero">Баланс</div>
      <div class="balance-num">${esc(display.balance)}</div>
      <div class="chips">
        <div><div class="k">Резерв</div><div class="v">${esc(display.reserve)}</div></div>
        <div><div class="k">На холде</div><div class="v">${esc(display.on_hold)}</div></div>
        <div><div class="k">Свободно</div><div class="v">${esc(display.free)}</div></div>
      </div>
    </div>`,
  );
  const txs = snap.transactions
    .map((item) => {
      const color = item.amount < 0 ? "neg" : "pos";
      const dot = item.amount < 0 ? "#e06a62" : state.mono ? "#f2f2f0" : "#7ee0d4";
      return `<div class="tx">
        <i class="dot" style="background:${dot}"></i>
        <div class="grow"><div class="title">${esc(item.title)}</div><div class="sub">${esc(item.subtitle)}</div></div>
        <div class="amt ${color}">${esc(item.amount_label)}</div>
      </div>`;
    })
    .join("");
  const book = jelly(
    "skin-sheet skin-book",
    "",
    `<div class="book">
      <div class="stat-row">
        <div class="stat-tile"><div class="k">Вложено</div><div class="v">${esc(display.invested)}</div></div>
        <div class="stat-tile"><div class="k">Вернулось</div><div class="v">${esc(display.returned)}</div></div>
      </div>
      <div class="be-row"><span class="t-kicker muted">До безубыточности</span><span class="t-demi">${esc(display.break_even)}</span></div>
      ${bar(snap.finance.break_even_ratio, "teal")}
      <div class="section-label">Прибыль за 14 дней</div>
      ${chart(snap.finance.series)}
      <div class="section-label" style="margin-bottom:4px">Операции</div>
      ${txs}
    </div>`,
    true,
  );
  return `<section class="screen push" data-screen="finance">
    ${header("Финансы", "clock", "range")}
    <div class="scroll"><div class="stack">${balance}${book}</div></div>
  </section>`;
}

function bundles(snap: Snapshot): string {
  const filters = [
    ["all", "Все"],
    ["test", "Тест"],
    ["profit", "Прибыль"],
    ["stop", "Стоп"],
  ];
  const chips = filters
    .map(
      ([key, title]) =>
        `<button class="chip ${state.filter === key ? "on" : ""}" type="button" data-filter="${key}">${title}</button>`,
    )
    .join("");
  const rows = snap.bundles.filter((bundle) => state.filter === "all" || bundle.status === state.filter);
  const cards = rows.length
    ? rows.map(bundleCard).join("")
    : `<div class="empty">Нет связок в этом статусе</div>`;
  return `<section class="screen push" data-screen="bundles">
    ${header("Связки", "plus", "bundle-form")}
    <div class="scroll"><div class="stack"><div class="filters">${chips}</div>${cards}</div></div>
  </section>`;
}

function bundleCard(bundle: Bundle): string {
  const roi = bundle.roi_pct < 0 ? "neg" : bundle.status === "profit" ? "pos" : "";
  const profit = bundle.profit < 0 ? "neg" : "pos";
  const rail = bundle.status === "profit" ? "rail-profit" : bundle.status === "test" ? "rail-test" : "rail-stop";
  const wash =
    bundle.status === "profit" ? "bundle-profit" : bundle.status === "test" ? "bundle-test" : "bundle-stop";
  return jelly(
    `skin-sheet skin-bundle bundle ${wash}`,
    "",
    `<i class="rail ${rail}"></i>
     <div class="bundle-top">
       <div class="grow"><div class="bundle-title">${esc(bundle.title)}</div><div class="bundle-sub">${esc(bundle.subtitle)}</div></div>
       ${pill(bundle.status_label, bundle.status)}
     </div>
     <div class="well"><div class="metrics">
       <div class="figure"><div class="k">ROI</div><div class="v ${roi}">${esc(bundle.roi_label)}</div></div>
       <div class="figure split"><div class="k">Прибыль</div><div class="v ${profit}">${esc(bundle.profit_label)}</div></div>
       <div class="figure split"><div class="k">Расход</div><div class="v">${esc(bundle.spend_label)}</div></div>
     </div></div>`,
    true,
  );
}

function spark(trend: number, color: string): string {
  const samples = Math.abs(trend) < 0.5 ? [8, 8.2, 7.8, 8.1, 7.9, 8] : trend > 0 ? [9.8, 9.2, 9.4, 7.4, 5.6, 3.4] : [5.4, 6.2, 7, 8, 9.2, 10.6];
  const step = 36 / (samples.length - 1);
  const points = samples.map((y, index) => `${(index * step).toFixed(1)},${((y / 16) * 16).toFixed(1)}`).join(" ");
  return `<svg class="spark" viewBox="0 0 36 16" aria-hidden="true"><polyline points="${points}" fill="none" stroke="${color}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
}

function geo(snap: Snapshot): string {
  const summary = snap.geo_summary;
  const hero = jelly(
    "skin-geo",
    "geo-hero",
    `<div>
       <div class="t-kicker onhero">Живые гео</div>
       <div class="geo-count">${summary.live_count}</div>
       <div class="geo-sub">${esc(summary.stopped_line)}</div>
     </div>
     <div class="rates">
       <div class="rate"><span class="k">Средний CPC</span><span class="v">${esc(summary.avg_cpc_label)}</span></div>
       <div class="rate"><span class="k">Средний EPC</span><span class="v">${esc(summary.avg_epc_label)}</span></div>
     </div>`,
  );
  return `<section class="screen push" data-screen="geo">
    ${header("Гео", "plus", "geo-form")}
    <div class="scroll"><div class="stack">${hero}${snap.geos.map(geoCard).join("")}</div></div>
  </section>`;
}

function geoCard(item: Geo): string {
  const stopped = item.status === "stop";
  const trendColor = item.trend_pct < 0 ? "neg" : Math.abs(item.trend_pct) < 0.5 ? "" : "pos";
  const sparkColor = item.trend_pct < 0 ? (state.mono ? "#c8c8c4" : "#e8898a") : state.mono ? "#f2f2f0" : "#7ee0d4";
  const skin = stopped ? "skin-sheet skin-geo-stop" : "skin-sheet skin-geo-card";
  return jelly(
    skin,
    "geo-card",
    `<div class="geo-top">
       <div class="badge ${stopped ? "stop" : "skin-geo"}">${esc(item.code)}</div>
       <div class="grow"><div class="geo-name">${esc(item.name)}</div><div class="geo-subline">${esc(item.subtitle)}</div></div>
       ${pill(item.status_label, item.status)}
     </div>
     <div class="well" style="--well-radius:14px;margin-top:12px"><div class="metrics">
       <div class="cell"><div class="k">CPC</div><div class="v">${esc(item.cpc_label)}</div></div>
       <div class="cell split"><div class="k">EPC</div><div class="v">${esc(item.epc_label)}</div></div>
       <div class="cell split"><div class="k">Тренд</div><div class="v trend ${trendColor}">${spark(item.trend_pct, sparkColor)}<span>${esc(item.trend_label)}</span></div></div>
     </div></div>`,
    true,
  );
}

function tasks(snap: Snapshot): string {
  const hero = jelly(
    "skin-tasks",
    "task-hero",
    `<div class="t-kicker onhero">${esc(snap.task_summary.date_line)}</div>
     <div class="big">${esc(snap.task_summary.headline)}</div>
     <div class="task-sub">${esc(snap.task_summary.subline)}</div>`,
  );
  const rows = snap.tasks.length ? snap.tasks.map(taskCard).join("") : `<div class="empty">На сегодня задач нет</div>`;
  return `<section class="screen push" data-screen="tasks">
    ${header("Задачи", "plus", "task-form")}
    <div class="scroll"><div class="stack">${hero}${rows}</div></div>
  </section>`;
}

function taskCard(task: Task): string {
  const noteColor = task.done ? "pos" : state.mono ? "ink" : "";
  const accent = !task.done && !state.mono ? "color:#9f78b7" : "";
  return jelly(
    "skin-sheet skin-tasks-card",
    `task-card ${task.done ? "done" : ""}`,
    `<div class="task-row">
       <button class="check ${task.done ? "on" : ""}" type="button" data-task="${task.id}" aria-label="${task.done ? "Снять" : "Готово"}">${task.done ? CHECK : ""}</button>
       <div class="task-copy">
         <div class="task-title ${task.done ? "done" : ""}">${esc(task.title)}</div>
         <div class="task-detail">${esc(task.detail)}</div>
         ${task.note ? `<div class="task-note ${noteColor}" style="${accent}">${esc(task.note)}</div>` : ""}
       </div>
     </div>`,
    true,
  );
}

function journal(snap: Snapshot): string {
  const hero = jelly(
    "skin-journal",
    "journal-hero",
    `<div class="t-kicker onhero">Журнал</div>
     <div class="big m40">${esc(snap.journal_summary.headline)}</div>
     <div class="lead-sub">${esc(snap.journal_summary.subline)}</div>`,
  );
  const rows = snap.journal.length ? snap.journal.map(journalCard).join("") : `<div class="empty">Журнал пуст</div>`;
  return `<section class="screen push" data-screen="journal">
    ${header("Журнал решений", "plus", "journal-form")}
    <div class="scroll"><div class="stack">${hero}${rows}</div></div>
  </section>`;
}

function journalCard(entry: Journal): string {
  const tone = entry.result_tone === "positive" ? "pos" : entry.result_tone === "negative" ? "neg" : "ink";
  return jelly(
    "skin-sheet skin-journal-card",
    "journal-card",
    `<div class="journal-date">${esc(entry.date_label)}</div>
     <div class="journal-title">${esc(entry.title)}</div>
     <div class="journal-reason">Причина: ${esc(entry.reason)}</div>
     <div class="journal-result ${tone}">Результат: ${esc(entry.result)}</div>`,
    true,
  );
}

function rules(snap: Snapshot): string {
  const hero = jelly(
    "skin-rules",
    "rules-hero",
    `<div class="t-kicker onhero">Дисциплина</div>
     <div class="big m40">${esc(snap.rule_summary.headline)}</div>
     <div class="lead-sub">${esc(snap.rule_summary.subline)}</div>`,
  );
  return `<section class="screen push" data-screen="rules">
    ${header("Правила", "more", "settings")}
    <div class="scroll"><div class="stack">${hero}${snap.rules.map(ruleCard).join("")}</div></div>
  </section>`;
}

function ruleCard(rule: Rule): string {
  return jelly(
    "skin-sheet skin-rules-card",
    `rule-card ${rule.enabled ? "" : "off"}`,
    `<div class="rule-row">
       <div class="rule-copy">
         <div class="rule-top">
           <div class="rule-title">${esc(rule.title)}</div>
           <div class="rule-value ${rule.enabled ? "" : "muted"}">${esc(rule.value_label)}</div>
         </div>
         <div class="rule-detail">${esc(rule.detail)}</div>
       </div>
       <button class="toggle ${rule.enabled ? "on" : ""}" type="button" data-rule="${rule.id}" aria-pressed="${rule.enabled}" aria-label="${esc(rule.title)}"><i></i></button>
     </div>`,
    true,
  );
}

function field(name: string, placeholder: string, area = false): string {
  return area
    ? `<textarea class="field" data-field="${name}" placeholder="${esc(placeholder)}"></textarea>`
    : `<input class="field" data-field="${name}" placeholder="${esc(placeholder)}" autocomplete="off" autocapitalize="off" />`;
}

function sheet(): string {
  if (state.sheet === "key") return "";
  if (state.sheet === "settings") return settings();
  if (state.sheet === "range") {
    const total = state.snapshot?.finance.series.reduce((sum, point) => sum + point.profit, 0) ?? 0;
    return overlay(
      `<h2>Прибыль за 14 дней</h2><p class="help">Сумма дневной прибыли на графике — ${esc(money(total, true))}.</p>`,
      true,
    );
  }
  if (state.sheet === "task") {
    return overlay(`<h2>Новая задача</h2>${field("title", "Название")}${field("detail", "Подробности")}${field("note", "Пометка")}<button class="jelly-btn" type="button" data-action="save-task">Сохранить</button>`);
  }
  if (state.sheet === "journal") {
    return overlay(`<h2>Запись в журнал</h2>${field("title", "Решение")}${field("reason", "Причина")}${field("result", "Результат")}<button class="jelly-btn" type="button" data-action="save-journal">Сохранить</button>`);
  }
  if (state.sheet === "bundle") {
    return overlay(
      `<h2>Новая связка</h2>${field("title", "Название, например VPN · Польша")}${field("vertical", "Вертикаль")}${field("geo", "Код гео, PL")}${field("source", "Источник трафика")}${field("network", "Партнёрка")}${field("model", "Модель, CPA")}<button class="jelly-btn" type="button" data-action="save-bundle">Сохранить</button>`,
    );
  }
  if (state.sheet === "geo") {
    return overlay(`<h2>Новое гео</h2>${field("code", "Код, DE")}${field("name", "Страна")}${field("subtitle", "Подпись")}<button class="jelly-btn" type="button" data-action="save-geo">Сохранить</button>`);
  }
  return "";
}

function settings(): string {
  return overlay(`<h2>Меню</h2>
    <div class="group-label">Тема</div>
    <div class="segment">
      <button type="button" class="${state.mono ? "" : "on"}" data-mono="0">Цветная</button>
      <button type="button" class="${state.mono ? "on" : ""}" data-mono="1">Монохром</button>
    </div>
    <div class="group-label">Ключ телефона</div>
    <input class="secret" data-field="apiKey" type="password" placeholder="API-ключ" value="${esc(state.apiKey)}" autocomplete="off" />
    <button class="jelly-btn" type="button" data-action="save-settings">Сохранить</button>
    <div class="error-line">${esc(state.keyError)}</div>
    <div class="row-switch" style="margin-top:16px">
      <span class="text-btn" style="width:auto">Уведомления</span>
      <button class="toggle ${state.alerts ? "on" : ""}" type="button" data-action="alerts" aria-pressed="${state.alerts}"><i></i></button>
    </div>
    <button class="text-btn" type="button" data-action="test-alert">Проверить уведомление</button>
    <button class="text-btn quiet" type="button" data-action="demo">Вернуть пример</button>
    <p class="help">Пока ключ не сохранён, Monolith показывает пример с бюджетом $1 000 и копит правки на этом телефоне. Когда сервер ответит, очередь уйдёт сама на /api/v1/sync. Web Push включится, если сервер начнёт присылать сообщения: разрешение браузера уже можно выдать здесь.</p>`);
}

function overlay(inner: string, short = false): string {
  return `<div class="sheet-back" data-action="close-sheet"><div class="sheet ${short ? "short" : ""}" data-sheet-panel="1">${inner}</div></div>`;
}

function gate(): string {
  if (state.sheet !== "key") return "";
  const orb = jelly("skin-finance", "lock-orb", LOCK);
  return `<div class="gate">
    <div class="gate-inner">
      ${orb}
      <h2 style="text-align:center">Monolith</h2>
      <p>Ключ телефона из файла server/.env. Он хранится только на этом устройстве.</p>
      <input class="secret" data-field="apiKey" type="password" placeholder="API-ключ" autocomplete="off" enterkeyhint="done" />
      <div class="error-line">${esc(state.keyError)}</div>
      <button class="jelly-btn" type="button" data-action="save-key">Продолжить</button>
      <button class="ghost" type="button" data-action="preview">Смотреть пример</button>
    </div>
  </div>`;
}

export function markup(): string {
  const snap = state.snapshot;
  let screen = `<section class="screen"><div class="center-fill"><div class="t-body">Нет сохранённых данных</div><button class="text-btn" type="button" data-action="retry">Повторить</button></div></section>`;
  if (!snap && !state.ready) screen = `<section class="screen"><div class="center-fill">Загрузка</div></section>`;
  if (snap && state.route === "home") screen = home(snap);
  if (snap && state.route === "finance") screen = finance(snap);
  if (snap && state.route === "bundles") screen = bundles(snap);
  if (snap && state.route === "geo") screen = geo(snap);
  if (snap && state.route === "tasks") screen = tasks(snap);
  if (snap && state.route === "journal") screen = journal(snap);
  if (snap && state.route === "rules") screen = rules(snap);
  return `${screen}${sheet()}${gate()}`;
}
