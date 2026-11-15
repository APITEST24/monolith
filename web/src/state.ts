import type { Journal, Mutation, Route, Sheet, Snapshot, Task } from "./types";

const DB_NAME = "monolith";
const STORE = "kv";

export const state: {
  route: Route;
  sheet: Sheet;
  snapshot: Snapshot | null;
  note: string | null;
  mono: boolean;
  apiKey: string;
  filter: string;
  online: boolean;
  source: "none" | "cache" | "demo" | "api";
  queue: Mutation[];
  alerts: boolean;
  keyError: string;
  ready: boolean;
} = {
  route: "home",
  sheet: null,
  snapshot: null,
  note: null,
  mono: false,
  apiKey: "",
  filter: "all",
  online: navigator.onLine,
  source: "none",
  queue: [],
  alerts: false,
  keyError: "",
  ready: false,
};

type Listener = () => void;
const listeners = new Set<Listener>();

export function subscribe(fn: Listener): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function renderNow(): void {
  document.documentElement.dataset.theme = state.mono ? "mono" : "color";
  for (const fn of listeners) fn();
}

function db(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => {
      if (!req.result.objectStoreNames.contains(STORE)) req.result.createObjectStore(STORE);
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function idbGet<T>(key: string): Promise<T | null> {
  const database = await db();
  return new Promise((resolve, reject) => {
    const req = database.transaction(STORE, "readonly").objectStore(STORE).get(key);
    req.onsuccess = () => resolve((req.result ?? null) as T | null);
    req.onerror = () => reject(req.error);
  });
}

async function idbSet(key: string, value: unknown): Promise<void> {
  const database = await db();
  return new Promise((resolve, reject) => {
    const tx = database.transaction(STORE, "readwrite");
    tx.objectStore(STORE).put(value, key);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

export function stamp(): string {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())}T${p(d.getUTCHours())}:${p(d.getUTCMinutes())}:${p(d.getUTCSeconds())}`;
}

function plural(n: number, one: string, few: string, many: string): string {
  const abs = Math.abs(n);
  const n10 = abs % 10;
  const n100 = abs % 100;
  if (n10 === 1 && n100 !== 11) return one;
  if (n10 >= 2 && n10 <= 4 && !(n100 >= 12 && n100 <= 14)) return few;
  return many;
}

function taskSubline(open: number): string {
  if (open === 0) return "все задачи закрыты";
  if (open === 1) return "одна задача ещё открыта";
  if (open === 2) return "две задачи ещё открыты";
  if (open === 3) return "три задачи ещё открыты";
  if (open === 4) return "четыре задачи ещё открыты";
  return `${open} ${plural(open, "задача", "задачи", "задач")} ещё открыты`;
}

function rulesSubline(enabled: number): string {
  if (enabled === 0) return "все правила выключены";
  if (enabled === 1) return "правило сейчас включено";
  return "правил сейчас включены";
}

function countLabel(n: number, one: string, few: string, many: string): string {
  return `${n} ${plural(n, one, few, many)}`;
}

function refreshTaskSummary(snap: Snapshot): void {
  const done = snap.tasks.filter((task) => task.done).length;
  const total = snap.tasks.length;
  const open = total - done;
  snap.task_summary = {
    done,
    total,
    open,
    headline: `${done} из ${total}`,
    subline: taskSubline(open),
    date_line: snap.task_summary?.date_line || `Сегодня · ${snap.date_label}`,
  };
}

function refreshRuleSummary(snap: Snapshot): void {
  const enabled = snap.rules.filter((rule) => rule.enabled).length;
  snap.rule_summary = {
    enabled,
    total: snap.rules.length,
    headline: `${enabled} из ${snap.rules.length}`,
    subline: rulesSubline(enabled),
  };
}

function refreshJournalSummary(snap: Snapshot): void {
  const headline = countLabel(snap.journal.length, "запись", "записи", "записей");
  const latest = snap.journal[0];
  const subline = latest
    ? `последняя — ${latest.date_label.slice(0, 1).toLowerCase()}${latest.date_label.slice(1)}`
    : "журнал пуст";
  snap.journal_summary = { count: snap.journal.length, headline, subline };
  snap.home.journal_label = headline;
}

function tempId(ids: number[]): number {
  const lowest = ids.length ? Math.min(...ids) : 0;
  return lowest > 0 ? -1 : lowest - 1;
}

async function remember(snap: Snapshot): Promise<void> {
  state.snapshot = snap;
  await idbSet("snapshot", snap);
}

async function enqueue(mutation: Omit<Mutation, "id" | "client_updated_at">): Promise<void> {
  const item: Mutation = { ...mutation, id: crypto.randomUUID(), client_updated_at: stamp() };
  state.queue = [...state.queue, item];
  await idbSet("queue", state.queue);
  void flush();
  void registerSync();
}

export async function flush(): Promise<void> {
  if (!state.apiKey || state.queue.length === 0 || !state.online) return;
  const pending = state.queue.slice();
  try {
    const response = await fetch("/api/v1/sync", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-API-Key": state.apiKey,
      },
      body: JSON.stringify({ mutations: pending }),
    });
    if (response.status === 401) {
      state.note = "Ключ не подошёл";
      renderNow();
      return;
    }
    if (!response.ok) throw new Error(String(response.status));
    const body = (await response.json()) as {
      applied: string[];
      conflicts: { id: string }[];
      snapshot: Snapshot;
    };
    const applied = new Set(body.applied);
    const rejected = new Set(body.conflicts.map((item) => item.id));
    state.queue = state.queue.filter((item) => !applied.has(item.id) && !rejected.has(item.id));
    await idbSet("queue", state.queue);
    await remember(body.snapshot);
    state.note = state.queue.length ? "Правки сохранены на телефоне и уйдут на сервер, когда связь вернётся" : null;
    state.source = "api";
    renderNow();
  } catch {
    state.note = "Правки сохранены на телефоне и уйдут на сервер, когда связь вернётся";
    renderNow();
  }
}

async function registerSync(): Promise<void> {
  if (!("serviceWorker" in navigator)) return;
  try {
    const reg = await navigator.serviceWorker.ready;
    const sync = (reg as ServiceWorkerRegistration & { sync?: { register: (tag: string) => Promise<void> } }).sync;
    if (sync) await sync.register("monolith-sync");
  } catch {
    /* Background Sync is absent on iOS; the page flushes itself. */
  }
}

export async function refresh(): Promise<void> {
  if (!state.apiKey) return;
  try {
    const response = await fetch("/api/v1/snapshot", {
      headers: { "X-API-Key": state.apiKey },
    });
    if (response.status === 401) {
      state.note = "Ключ не подошёл";
      state.keyError = "Ключ не подошёл";
      renderNow();
      return;
    }
    if (!response.ok) throw new Error(String(response.status));
    const snap = (await response.json()) as Snapshot;
    await remember(snap);
    state.note = null;
    state.source = "api";
    state.keyError = "";
    renderNow();
    await flush();
    void pullAlerts();
  } catch {
    if (!state.snapshot) await loadDemo();
    state.note = "Нет связи · показаны сохранённые данные";
    renderNow();
  }
}

async function pullAlerts(): Promise<void> {
  if (!state.alerts || !state.apiKey) return;
  if (!("Notification" in window) || Notification.permission !== "granted") return;
  try {
    const response = await fetch("/api/v1/rules/check", { headers: { "X-API-Key": state.apiKey } });
    if (!response.ok) return;
    const report = (await response.json()) as {
      violations: { key: string; status: string; message: string; title: string }[];
      warnings: { key: string; status: string; message: string; title: string }[];
    };
    const notable = [...report.violations, ...report.warnings];
    const signature = notable.map((item) => `${item.key}:${item.status}:${item.message}`).join("|");
    if (signature === localStorage.getItem("monolith.alertSignature")) return;
    localStorage.setItem("monolith.alertSignature", signature);
    for (const item of notable.slice(0, 3)) {
      new Notification(item.title, { body: item.message, lang: "ru" });
    }
  } catch {
    /* alerts are best-effort */
  }
}

export async function loadDemo(): Promise<void> {
  const response = await fetch("/demo-snapshot.json");
  const snap = (await response.json()) as Snapshot;
  state.snapshot = snap;
  state.source = "demo";
  await idbSet("snapshot", snap);
}

export async function saveKey(raw: string): Promise<boolean> {
  const apiKey = raw.trim();
  if (!apiKey) {
    state.keyError = "Введите ключ";
    renderNow();
    return false;
  }
  const previous = state.apiKey;
  state.apiKey = apiKey;
  localStorage.setItem("monolith.apiKey", apiKey);
  await idbSet("apiKey", apiKey);
  try {
    const response = await fetch("/api/v1/snapshot", { headers: { "X-API-Key": apiKey } });
    if (response.status === 401) {
      state.apiKey = previous === apiKey ? "" : previous;
      if (state.apiKey) localStorage.setItem("monolith.apiKey", state.apiKey);
      else localStorage.removeItem("monolith.apiKey");
      await idbSet("apiKey", state.apiKey);
      state.keyError = "Ключ не подошёл";
      renderNow();
      return false;
    }
    if (response.ok) {
      const snap = (await response.json()) as Snapshot;
      await remember(snap);
      state.source = "api";
      state.note = null;
    } else {
      throw new Error(String(response.status));
    }
  } catch {
    if (!state.snapshot) await loadDemo();
    state.note = "Нет связи · показаны сохранённые данные";
  }
  state.sheet = null;
  state.keyError = "";
  renderNow();
  await flush();
  return true;
}

export function setMono(mono: boolean): void {
  state.mono = mono;
  localStorage.setItem("monolith.mono", mono ? "1" : "0");
  renderNow();
}

export async function toggleTask(id: number): Promise<void> {
  const snap = state.snapshot;
  if (!snap) return;
  const task = snap.tasks.find((item) => item.id === id);
  if (!task) return;
  task.done = !task.done;
  refreshTaskSummary(snap);
  await remember(snap);
  renderNow();
  await enqueue({ entity: "task", op: "update", payload: { id, done: task.done } });
}

export async function toggleRule(id: number): Promise<void> {
  const snap = state.snapshot;
  if (!snap) return;
  const rule = snap.rules.find((item) => item.id === id);
  if (!rule) return;
  rule.enabled = !rule.enabled;
  if (rule.key === "withdraw_to_zero") {
    rule.value_label = rule.enabled ? "ВКЛ" : "ВЫКЛ";
    rule.value_muted = !rule.enabled;
  }
  refreshRuleSummary(snap);
  await remember(snap);
  renderNow();
  await enqueue({ entity: "rule", op: "update", payload: { id, enabled: rule.enabled } });
}

export async function addTask(title: string, detail: string, note: string): Promise<void> {
  const snap = state.snapshot;
  if (!snap) return;
  const item: Task = {
    id: tempId(snap.tasks.map((task) => task.id)),
    title,
    detail,
    note,
    note_tone: "accent",
    done: false,
    sort_order: Math.max(0, ...snap.tasks.map((task) => task.sort_order)) + 1,
  };
  snap.tasks.push(item);
  refreshTaskSummary(snap);
  snap.home.tasks_label = `${snap.tasks.length} на сегодня`;
  await remember(snap);
  await enqueue({
    entity: "task",
    op: "create",
    payload: { title, detail, note, note_tone: "accent" },
  });
}

export async function addJournal(title: string, reason: string, result: string): Promise<void> {
  const snap = state.snapshot;
  if (!snap) return;
  const when = stamp();
  const item: Journal = {
    id: tempId(snap.journal.map((entry) => entry.id)),
    occurred_at: when,
    date_label: `Сегодня, ${when.slice(11, 16)}`,
    title,
    reason,
    result,
    result_tone: "neutral",
  };
  snap.journal.unshift(item);
  refreshJournalSummary(snap);
  await remember(snap);
  await enqueue({
    entity: "journal",
    op: "create",
    payload: { title, reason, result, result_tone: "neutral", occurred_at: when },
  });
}

export async function addBundle(fields: {
  title: string;
  vertical: string;
  geo: string;
  source: string;
  network: string;
  model: string;
}): Promise<void> {
  const snap = state.snapshot;
  if (!snap) return;
  const vertical = fields.vertical || fields.title;
  const model = fields.model || "CPA";
  const subtitle = `${fields.source} · ${fields.network} · ${model}`;
  snap.bundles.push({
    id: tempId(snap.bundles.map((bundle) => bundle.id)),
    title: fields.title,
    subtitle,
    vertical,
    geo_code: fields.geo.toUpperCase(),
    traffic_source: fields.source,
    network: fields.network,
    payout_model: model,
    status: "test",
    status_label: "Тест",
    spend: 0,
    profit: 0,
    roi_pct: 0,
    spend_label: "$0",
    profit_label: "+$0",
    roi_label: "0%",
    sort_order: Math.max(0, ...snap.bundles.map((bundle) => bundle.sort_order)) + 1,
  });
  const n = snap.bundles.length;
  snap.home.bundles_label = `${n} ${plural(n, "активная", "активные", "активных")}`;
  await remember(snap);
  await enqueue({
    entity: "bundle",
    op: "create",
    payload: {
      title: fields.title,
      subtitle,
      vertical,
      geo_code: fields.geo.toUpperCase(),
      traffic_source: fields.source,
      network: fields.network,
      payout_model: model,
      status: "test",
    },
  });
}

export async function addGeo(code: string, name: string, subtitle: string): Promise<void> {
  const snap = state.snapshot;
  if (!snap) return;
  snap.geos.push({
    id: tempId(snap.geos.map((geo) => geo.id)),
    code: code.toUpperCase(),
    name,
    subtitle,
    status: "test",
    status_label: "Тест",
    trend_pct: 0,
    cpc_label: "$0.00",
    epc_label: "$0.00",
    trend_label: "0%",
    sort_order: Math.max(0, ...snap.geos.map((geo) => geo.sort_order)) + 1,
  });
  const live = snap.geos.filter((geo) => geo.status !== "stop").length;
  snap.geo_summary.live_count = live;
  snap.home.geos_label = `${live} ${plural(live, "страна", "страны", "стран")}`;
  await remember(snap);
  await enqueue({
    entity: "geo",
    op: "create",
    payload: { code: code.toUpperCase(), name, subtitle, status: "test", cpc: 0, epc: 0, trend_pct: 0 },
  });
}

export async function restoreDemo(): Promise<void> {
  state.queue = [];
  await idbSet("queue", []);
  await loadDemo();
  state.note = null;
  renderNow();
}

export function go(route: Route): void {
  state.route = route;
  state.sheet = null;
  if (location.hash !== `#/${route === "home" ? "" : route}`) {
    history.pushState({ route }, "", route === "home" ? "#/" : `#/${route}`);
  }
  renderNow();
}

export function openSheet(sheet: Sheet): void {
  state.sheet = sheet;
  state.keyError = "";
  renderNow();
}

export function closeSheet(): void {
  state.sheet = null;
  renderNow();
}

export async function boot(): Promise<void> {
  const params = new URLSearchParams(location.search);
  const shot = params.get("shot");
  state.mono = localStorage.getItem("monolith.mono") === "1";
  state.alerts = localStorage.getItem("monolith.alerts") === "1";
  state.apiKey = localStorage.getItem("monolith.apiKey") || "";
  if (shot) {
    const allowed: Route[] = ["home", "finance", "bundles", "geo", "tasks", "journal", "rules"];
    if (allowed.includes(shot as Route)) state.route = shot as Route;
    document.documentElement.style.setProperty("--safe-top", "59px");
    document.documentElement.style.setProperty("--safe-bottom", "34px");
  } else {
    const hash = location.hash.replace(/^#\/?/, "");
    const allowed: Route[] = ["home", "finance", "bundles", "geo", "tasks", "journal", "rules"];
    if (allowed.includes(hash as Route)) state.route = hash as Route;
  }
  try {
    const cachedKey = await idbGet<string>("apiKey");
    if (!state.apiKey && cachedKey) state.apiKey = cachedKey;
    const cached = await idbGet<Snapshot>("snapshot");
    const queue = await idbGet<Mutation[]>("queue");
    if (cached) {
      state.snapshot = cached;
      state.source = "cache";
    }
    if (queue) state.queue = queue;
    if (state.apiKey) await idbSet("apiKey", state.apiKey);
  } catch {
    /* private mode can block IndexedDB; memory state still works */
  }
  if (!state.snapshot) {
    try {
      await loadDemo();
    } catch {
      state.note = "Нет сохранённых данных";
    }
  }
  if (!state.apiKey && !shot) state.sheet = "key";
  state.ready = true;
  renderNow();
  if (state.apiKey) await refresh();
  window.addEventListener("online", () => {
    state.online = true;
    void refresh();
  });
  window.addEventListener("offline", () => {
    state.online = false;
    state.note = "Нет связи · показаны сохранённые данные";
    renderNow();
  });
  window.addEventListener("hashchange", () => {
    if (shot) return;
    const hash = location.hash.replace(/^#\/?/, "");
    const allowed: Route[] = ["home", "finance", "bundles", "geo", "tasks", "journal", "rules"];
    state.route = allowed.includes(hash as Route) ? (hash as Route) : "home";
    state.sheet = null;
    renderNow();
  });
  navigator.serviceWorker?.addEventListener("message", (event: MessageEvent) => {
    const data = event.data as { type?: string; snapshot?: Snapshot; queue?: Mutation[] };
    if (data?.type !== "synced") return;
    if (data.snapshot) {
      state.snapshot = data.snapshot;
      state.source = "api";
    }
    if (data.queue) state.queue = data.queue;
    state.note = state.queue.length ? state.note : null;
    renderNow();
  });
}

export function money(value: number, signed = false): string {
  const negative = value < -0.0000001;
  let mag = Math.abs(value);
  mag = Math.round(mag * 100) / 100;
  const cents = Math.abs(mag - Math.round(mag)) > 0.001;
  const raw = cents ? mag.toFixed(2) : String(Math.round(mag));
  const [whole, frac] = raw.split(".");
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, " ");
  const body = frac ? `${grouped}.${frac}` : grouped;
  const sign = negative ? "−" : signed && mag > 0.0000001 ? "+" : "";
  return `${sign}$${body}`;
}
