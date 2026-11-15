import "./style.css";
import { markup } from "./render";
import {
  addBundle,
  addGeo,
  addJournal,
  addTask,
  boot,
  closeSheet,
  flush,
  go,
  openSheet,
  refresh,
  renderNow,
  restoreDemo,
  saveKey,
  setMono,
  state,
  subscribe,
  toggleRule,
  toggleTask,
} from "./state";
import type { Route } from "./types";

document.documentElement.dataset.theme = localStorage.getItem("monolith.mono") === "1" ? "mono" : "color";

const app = document.querySelector<HTMLElement>("#app");
if (!app) throw new Error("missing app");

subscribe(() => {
  const scroll = app.querySelector<HTMLElement>(".scroll");
  const top = scroll?.scrollTop ?? 0;
  app.innerHTML = markup();
  app.dataset.ready = state.ready ? "1" : "0";
  app.dataset.source = state.source;
  app.dataset.screen = state.route;
  const next = app.querySelector<HTMLElement>(".scroll");
  if (next && top) next.scrollTop = top;
});

function field(name: string): string {
  const el = app?.querySelector<HTMLInputElement | HTMLTextAreaElement>(`[data-field="${name}"]`);
  return el?.value.trim() ?? "";
}

app.addEventListener("click", (event) => {
  const target = event.target as HTMLElement;
  if (target.closest("[data-sheet-panel]") && target.dataset.action === "close-sheet") return;
  const goTo = target.closest<HTMLElement>("[data-go]");
  if (goTo?.dataset.go) {
    go(goTo.dataset.go as Route);
    return;
  }
  const filter = target.closest<HTMLElement>("[data-filter]");
  if (filter?.dataset.filter) {
    state.filter = filter.dataset.filter;
    renderNow();
    return;
  }
  const task = target.closest<HTMLElement>("[data-task]");
  if (task?.dataset.task) {
    void toggleTask(Number(task.dataset.task));
    return;
  }
  const rule = target.closest<HTMLElement>("[data-rule]");
  if (rule?.dataset.rule) {
    void toggleRule(Number(rule.dataset.rule));
    return;
  }
  const mono = target.closest<HTMLElement>("[data-mono]");
  if (mono?.dataset.mono) {
    setMono(mono.dataset.mono === "1");
    return;
  }
  const button = target.closest<HTMLElement>("[data-action]");
  const action = button?.dataset.action;
  if (!action) return;
  if (action === "close-sheet" && target.closest("[data-sheet-panel]")) return;
  if (action === "back") {
    if (history.length > 1) history.back();
    else go("home");
    return;
  }
  if (action === "settings") openSheet("settings");
  else if (action === "range") openSheet("range");
  else if (action === "bundle-form") openSheet("bundle");
  else if (action === "geo-form") openSheet("geo");
  else if (action === "task-form") openSheet("task");
  else if (action === "journal-form") openSheet("journal");
  else if (action === "close-sheet") closeSheet();
  else if (action === "save-key") void saveKey(field("apiKey"));
  else if (action === "preview") {
    state.sheet = null;
    renderNow();
  } else if (action === "retry") void refresh();
  else if (action === "save-settings") void saveKey(field("apiKey"));
  else if (action === "demo") void restoreDemo();
  else if (action === "alerts") void toggleAlerts();
  else if (action === "test-alert") void testAlert();
  else if (action === "save-task") {
    const title = field("title");
    if (!title) return;
    void addTask(title, field("detail"), field("note")).then(() => closeSheet());
  } else if (action === "save-journal") {
    const title = field("title");
    const reason = field("reason");
    if (!title || !reason) return;
    void addJournal(title, reason, field("result")).then(() => closeSheet());
  } else if (action === "save-bundle") {
    const title = field("title");
    const geo = field("geo");
    if (!title || !geo) return;
    void addBundle({
      title,
      vertical: field("vertical"),
      geo,
      source: field("source"),
      network: field("network"),
      model: field("model"),
    }).then(() => closeSheet());
  } else if (action === "save-geo") {
    const code = field("code");
    const name = field("name");
    if (!code || !name) return;
    void addGeo(code, name, field("subtitle")).then(() => closeSheet());
  }
});

async function toggleAlerts(): Promise<void> {
  state.alerts = !state.alerts;
  localStorage.setItem("monolith.alerts", state.alerts ? "1" : "0");
  if (state.alerts && "Notification" in window) {
    await Notification.requestPermission();
  }
  renderNow();
}

async function testAlert(): Promise<void> {
  if (!("Notification" in window)) return;
  const permission = await Notification.requestPermission();
  if (permission !== "granted") return;
  const body = "Проверка уведомлений: стоп-лосс дня, осталось $12.";
  if (navigator.serviceWorker?.controller) {
    navigator.serviceWorker.controller.postMessage({ type: "warm", urls: [] });
  }
  new Notification("Monolith", { body, lang: "ru" });
}

function stopRubberBand(): void {
  let startY = 0;
  document.addEventListener(
    "touchstart",
    (event) => {
      startY = event.touches[0]?.clientY ?? 0;
    },
    { passive: true },
  );
  document.addEventListener(
    "touchmove",
    (event) => {
      const scroller = (event.target as HTMLElement | null)?.closest<HTMLElement>(".scroll, .sheet");
      if (!scroller) {
        event.preventDefault();
        return;
      }
      const dy = (event.touches[0]?.clientY ?? 0) - startY;
      const atTop = scroller.scrollTop <= 0;
      const atBottom = scroller.scrollTop + scroller.clientHeight >= scroller.scrollHeight - 1;
      if ((atTop && dy > 0) || (atBottom && dy < 0)) event.preventDefault();
    },
    { passive: false },
  );
}

async function registerWorker(): Promise<void> {
  if (!("serviceWorker" in navigator)) return;
  try {
    const reg = await navigator.serviceWorker.register("/sw.js", { scope: "/" });
    const worker = navigator.serviceWorker.controller;
    if (worker) {
      const urls = [...document.querySelectorAll<HTMLScriptElement | HTMLLinkElement>("script[src], link[rel='stylesheet']")]
        .map((el) => ("src" in el ? el.src : el.href))
        .filter(Boolean);
      worker.postMessage({ type: "warm", urls });
    }
    await reg.update();
  } catch {
    /* the app still works online without a worker */
  }
}

/* Optional Web Push. Stays idle until a VAPID public key is configured. */
export const VAPID_PUBLIC_KEY: string = "";

export async function preparePush(registration: ServiceWorkerRegistration): Promise<void> {
  if (!VAPID_PUBLIC_KEY || !("PushManager" in window)) return;
  const existing = await registration.pushManager.getSubscription();
  if (existing) return;
  const padding = "=".repeat((4 - (VAPID_PUBLIC_KEY.length % 4)) % 4);
  const bytes = Uint8Array.from(atob(VAPID_PUBLIC_KEY.replace(/-/g, "+").replace(/_/g, "/") + padding), (c) => c.charCodeAt(0));
  await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: bytes });
}

stopRubberBand();
void boot().then(async () => {
  await registerWorker();
  if (VAPID_PUBLIC_KEY && navigator.serviceWorker) {
    const reg = await navigator.serviceWorker.ready;
    void preparePush(reg);
  }
});

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") void flush();
});
