/* API client — Contract-First.
   Shapes mirror contracts/openapi.yaml (AuthSessionResponse, AuthTokens,
   User, EmailOnlyRequest, …). Base URL comes from VITE_API_BASE_URL with
   the contract's /api/v1 servers suffix appended, same convention the
   previous web client used. */

export type SubscriptionTier =
  | "free"
  | "pepinillo_plus"
  | "everywhere_monthly"
  | "everywhere_annual";

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface User {
  id: string;
  email: string;
  name: string;
  imageUrl: string | null;
  subscriptionTier: SubscriptionTier;
  subscriptionExpiresAt: string | null;
  emailVerified: boolean;
  aiCreditsBalance: number;
  metricsOptIn: boolean;
  pendingEmail: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface AuthSession {
  user: User;
  tokens: AuthTokens;
}

export interface ModeStats {
  totalTime: number;
  sessionCount: number;
  completed: number;
  avgDuration: number;
}

export interface TaskStat {
  taskId: number;
  taskTitle: string;
  focusTime: number;
  sessionCount: number;
  completed: boolean;
}

export interface ServerReport {
  weekStart?: string;
  weekEnd?: string;
  monthStart?: string;
  monthEnd?: string;
  totalFocusTime: number;
  totalSessions: number;
  pomodoroStats?: ModeStats | null;
  flowtimeStats?: ModeStats | null;
  timeblockStats?: ModeStats | null;
  stopwatchStats?: ModeStats | null;
  tasksCompleted: number;
  tasksCreated: number;
  topTasks?: TaskStat[];
}

export interface AiInsight {
  type?: string;
  title?: string;
  content?: string;
  generatedAt?: string;
}

export class ApiError extends Error {
  status: number;
  code: string;

  constructor(status: number, code: string, message?: string) {
    super(message || code);
    this.status = status;
    this.code = code;
  }
}

const TOKENS_KEY = "pepinillo:tokens.v1";

export function apiBase(): string {
  const raw =
    (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? "";
  const trimmed = raw.trim().replace(/\/+$/, "");
  return trimmed ? `${trimmed}/api/v1` : "";
}

export function isApiConfigured(): boolean {
  return apiBase().length > 0;
}

export function loadTokens(): AuthTokens | null {
  try {
    const raw = localStorage.getItem(TOKENS_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<AuthTokens>;
    if (typeof parsed.accessToken !== "string" || typeof parsed.refreshToken !== "string") {
      return null;
    }
    return { accessToken: parsed.accessToken, refreshToken: parsed.refreshToken, expiresIn: 0 };
  } catch {
    return null;
  }
}

export function saveTokens(tokens: AuthTokens | null): void {
  try {
    if (!tokens) localStorage.removeItem(TOKENS_KEY);
    else localStorage.setItem(TOKENS_KEY, JSON.stringify(tokens));
  } catch {
    /* Private mode: session lasts until reload. The UI stays honest. */
  }
}

interface ErrorEnvelope {
  error?: string;
  code?: string;
  message?: string;
}

async function parse<T>(res: Response): Promise<T> {
  if (res.status === 204) return undefined as T;
  let body: ErrorEnvelope & T;
  try {
    body = (await res.json()) as ErrorEnvelope & T;
  } catch {
    throw new ApiError(res.status, "bad_response", `HTTP ${res.status}`);
  }
  if (!res.ok) {
    const envelope = body as ErrorEnvelope;
    throw new ApiError(
      res.status,
      envelope.code || envelope.error || "unknown",
      envelope.message || envelope.error || `HTTP ${res.status}`,
    );
  }
  return body;
}

export class ApiClient {
  async register(email: string, name: string, password: string): Promise<AuthSession> {
    const session = await this.public<AuthSession>("/auth/register", {
      method: "POST",
      body: JSON.stringify({ email, name, password }),
    });
    saveTokens(session.tokens);
    return session;
  }

  async login(email: string, password: string): Promise<AuthSession> {
    const session = await this.public<AuthSession>("/auth/login", {
      method: "POST",
      body: JSON.stringify({ email, password }),
    });
    saveTokens(session.tokens);
    return session;
  }

  async forgotPassword(email: string): Promise<void> {
    await this.public("/auth/forgot-password", {
      method: "POST",
      body: JSON.stringify({ email }),
    });
  }

  async resetPassword(email: string, code: string, newPassword: string): Promise<void> {
    await this.public("/auth/reset-password", {
      method: "POST",
      body: JSON.stringify({ email, code, newPassword }),
    });
  }

  async verifyEmail(email: string, code: string): Promise<void> {
    await this.public("/auth/verify-email", {
      method: "POST",
      body: JSON.stringify({ email, code }),
    });
  }

  async resendVerification(email: string): Promise<void> {
    await this.public("/auth/resend-verification", {
      method: "POST",
      body: JSON.stringify({ email }),
    });
  }

  async me(): Promise<User> {
    return this.authed<User>("/users/me", { method: "GET" });
  }

  async updateMe(patch: { name?: string; imageUrl?: string; metricsOptIn?: boolean }): Promise<User> {
    return this.authed<User>("/users/me", { method: "PUT", body: JSON.stringify(patch) });
  }

  async requestEmailChange(newEmail: string): Promise<void> {
    await this.authed("/auth/request-email-change", {
      method: "POST",
      body: JSON.stringify({ newEmail }),
    });
  }

  async confirmEmailChange(code: string): Promise<User> {
    return this.authed<User>("/auth/confirm-email-change", {
      method: "POST",
      body: JSON.stringify({ code }),
    });
  }

  async cancelEmailChange(): Promise<void> {
    await this.authed("/auth/cancel-email-change", { method: "POST" });
  }

  async initialUpload(
    payload: { deviceId: string; tasks: unknown[]; sessions: unknown[]; settings: unknown[] },
    deviceId: string,
  ): Promise<{ tasks: unknown[]; sessions: unknown[]; settings: unknown[]; serverTimestamp: string; hasExistingData: boolean }> {
    return this.authed("/sync/initial-upload", {
      method: "POST",
      headers: { "X-Device-ID": deviceId },
      body: JSON.stringify(payload),
    });
  }

  async weeklyReport(): Promise<ServerReport> {
    return this.authed<ServerReport>("/analytics/weekly-report", { method: "GET" });
  }

  async monthlyReport(): Promise<ServerReport> {
    return this.authed<ServerReport>("/analytics/monthly-report", { method: "GET" });
  }

  async aiWeeklyReport(): Promise<AiInsight> {
    return this.authed<AiInsight>("/ai/weekly-report", { method: "GET" });
  }

  async deleteAccount(): Promise<void> {
    const tokens = loadTokens();
    try {
      await this.authed("/auth/account", {
        method: "DELETE",
        body: JSON.stringify({ refreshToken: tokens?.refreshToken ?? "" }),
      });
    } finally {
      saveTokens(null);
    }
  }

  async logout(): Promise<void> {
    const tokens = loadTokens();
    try {
      await this.authed("/auth/logout", {
        method: "POST",
        body: JSON.stringify({ refreshToken: tokens?.refreshToken ?? "" }),
      });
    } finally {
      saveTokens(null);
    }
  }

  private async public<T>(path: string, init: RequestInit): Promise<T> {
    const base = apiBase();
    if (!base) throw new ApiError(0, "api_not_configured", "Falta VITE_API_BASE_URL");
    const res = await fetch(`${base}${path}`, {
      ...init,
      headers: { "Content-Type": "application/json", Accept: "application/json", ...(init.headers ?? {}) },
    });
    return parse<T>(res);
  }

  private async authed<T>(path: string, init: RequestInit, retried = false): Promise<T> {
    const base = apiBase();
    if (!base) throw new ApiError(0, "api_not_configured", "Falta VITE_API_BASE_URL");
    const tokens = loadTokens();
    const res = await fetch(`${base}${path}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(tokens ? { Authorization: `Bearer ${tokens.accessToken}` } : {}),
        ...(init.headers ?? {}),
      },
    });
    if (res.status === 401 && !retried && tokens?.refreshToken) {
      const refreshed = await this.refresh(tokens.refreshToken);
      if (refreshed) return this.authed<T>(path, init, true);
      saveTokens(null);
      throw new ApiError(401, "session_expired", "Tu sesión caducó. Vuelve a entrar.");
    }
    return parse<T>(res);
  }

  private async refresh(refreshToken: string): Promise<boolean> {
    try {
      const out = await this.public<{ tokens: AuthTokens }>("/auth/refresh", {
        method: "POST",
        body: JSON.stringify({ refreshToken }),
      });
      saveTokens(out.tokens);
      return true;
    } catch {
      return false;
    }
  }
}

export const api = new ApiClient();
