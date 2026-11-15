import { beforeEach, describe, expect, it, vi } from "vitest";
import { ApiClient, ApiError, apiBase, isApiConfigured } from "./client";

const BASE = "http://api.test/api/v1";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const TOKENS = { accessToken: "a1", refreshToken: "r1", expiresIn: 900 };
const USER = {
  id: "u1",
  email: "a@b.c",
  name: "Ana",
  imageUrl: null,
  subscriptionTier: "free",
  subscriptionExpiresAt: null,
  emailVerified: true,
  aiCreditsBalance: 100,
  metricsOptIn: false,
};

function memoryStorage(): Storage {
  const mem = new Map<string, string>();
  return {
    getItem: (k: string) => mem.get(k) ?? null,
    setItem: (k: string, v: string) => void mem.set(k, v),
    removeItem: (k: string) => void mem.delete(k),
    clear: () => mem.clear(),
    key: (i: number) => [...mem.keys()][i] ?? null,
    get length() {
      return mem.size;
    },
  } as Storage;
}

beforeEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
  vi.stubGlobal("localStorage", memoryStorage());
  vi.stubEnv("VITE_API_BASE_URL", "http://api.test");
});

describe("config", () => {
  it("appends /api/v1 and reports configured", () => {
    expect(apiBase()).toBe(BASE);
    expect(isApiConfigured()).toBe(true);
  });

  it("is not configured when the env is empty", async () => {
    vi.stubEnv("VITE_API_BASE_URL", "");
    expect(isApiConfigured()).toBe(false);
    await expect(new ApiClient().me()).rejects.toMatchObject({ code: "api_not_configured" });
  });
});

describe("login", () => {
  it("posts credentials and persists tokens", async () => {
    const fetchMock = vi.fn(async () => json({ user: USER, tokens: TOKENS }, 201));
    vi.stubGlobal("fetch", fetchMock);
    const session = await new ApiClient().login("a@b.c", "secret123");
    expect(fetchMock).toHaveBeenCalledWith(
      `${BASE}/auth/login`,
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({ email: "a@b.c", password: "secret123" }),
      }),
    );
    expect(session.user.email).toBe("a@b.c");
    expect(JSON.parse(localStorage.getItem("pepinillo:tokens.v1") ?? "{}").refreshToken).toBe("r1");
  });

  it("surfaces the contract error envelope", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => json({ error: "invalid_credentials" }, 401)));
    const err = await new ApiClient().login("a@b.c", "nope").catch((e) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err).toMatchObject({ status: 401, code: "invalid_credentials" });
  });
});

describe("token refresh", () => {
  it("retries once with a fresh access token after 401", async () => {
    localStorage.setItem(
      "pepinillo:tokens.v1",
      JSON.stringify({ accessToken: "old", refreshToken: "r1", expiresIn: 0 }),
    );
    const calls: string[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string, init?: RequestInit) => {
        calls.push(`${url}|${(init?.headers as Record<string, string>).Authorization ?? ""}`);
        if (String(url).endsWith("/auth/refresh")) return json({ tokens: TOKENS });
        if (calls.length === 1) return json({ error: "unauthorized" }, 401);
        return json(USER);
      }),
    );
    const me = await new ApiClient().me();
    expect(me.email).toBe("a@b.c");
    expect(calls[1]).toContain("/auth/refresh");
    expect(calls[2]).toContain("Bearer a1");
  });

  it("clears the session when refresh fails", async () => {
    localStorage.setItem(
      "pepinillo:tokens.v1",
      JSON.stringify({ accessToken: "old", refreshToken: "bad", expiresIn: 0 }),
    );
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) =>
        String(url).endsWith("/auth/refresh")
          ? json({ error: "invalid_token" }, 401)
          : json({ error: "unauthorized" }, 401),
      ),
    );
    await expect(new ApiClient().me()).rejects.toMatchObject({ code: "session_expired" });
    expect(localStorage.getItem("pepinillo:tokens.v1")).toBeNull();
  });
});
