export interface SeriesPoint {
  date: string;
  profit: number;
}

export interface FinanceDisplay {
  profit_today: string;
  spend_today: string;
  income_today: string;
  roi_today: string;
  stop_ratio: string;
  balance: string;
  reserve: string;
  on_hold: string;
  free: string;
  invested: string;
  returned: string;
  break_even: string;
}

export interface Snapshot {
  as_of: string;
  date_label: string;
  finance: {
    balance: number;
    reserve: number;
    on_hold: number;
    free: number;
    invested: number;
    returned: number;
    break_even_ratio: number;
    profit_today: number;
    spend_today: number;
    income_today: number;
    roi_today_pct: number;
    stop_limit: number;
    stop_spent: number;
    series: SeriesPoint[];
    display: FinanceDisplay;
  };
  transactions: {
    id: number;
    title: string;
    subtitle: string;
    amount: number;
    amount_label: string;
  }[];
  bundles: Bundle[];
  geos: Geo[];
  geo_summary: {
    live_count: number;
    stopped_line: string;
    avg_cpc_label: string;
    avg_epc_label: string;
  };
  tasks: Task[];
  task_summary: {
    done: number;
    total: number;
    open: number;
    headline: string;
    subline: string;
    date_line: string;
  };
  journal: Journal[];
  journal_summary: { count: number; headline: string; subline: string };
  rules: Rule[];
  rule_summary: { enabled: number; total: number; headline: string; subline: string };
  home: {
    bundles_label: string;
    geos_label: string;
    tasks_label: string;
    journal_label: string;
    rules_label: string;
  };
}

export interface Bundle {
  id: number;
  title: string;
  subtitle: string;
  vertical: string;
  geo_code: string;
  traffic_source: string;
  network: string;
  payout_model: string;
  status: string;
  status_label: string;
  spend: number;
  profit: number;
  roi_pct: number;
  spend_label: string;
  profit_label: string;
  roi_label: string;
  sort_order: number;
}

export interface Geo {
  id: number;
  code: string;
  name: string;
  subtitle: string;
  status: string;
  status_label: string;
  trend_pct: number;
  cpc_label: string;
  epc_label: string;
  trend_label: string;
  sort_order: number;
}

export interface Task {
  id: number;
  title: string;
  detail: string;
  note: string;
  note_tone: string;
  done: boolean;
  sort_order: number;
}

export interface Journal {
  id: number;
  occurred_at: string;
  date_label: string;
  title: string;
  reason: string;
  result: string;
  result_tone: string;
}

export interface Rule {
  id: number;
  key: string;
  title: string;
  value_label: string;
  value_muted: boolean;
  detail: string;
  enabled: boolean;
  params: { limit?: number };
  sort_order: number;
}

export interface Mutation {
  id: string;
  entity: "task" | "rule" | "journal" | "bundle" | "geo";
  op: "create" | "update";
  payload: Record<string, unknown>;
  client_updated_at: string;
}

export type Route = "home" | "finance" | "bundles" | "geo" | "tasks" | "journal" | "rules";

export type Sheet =
  | null
  | "settings"
  | "range"
  | "task"
  | "journal"
  | "bundle"
  | "geo"
  | "key";
