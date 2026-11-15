import { useCallback, useEffect, useState } from "react";
import { api, isApiConfigured, loadTokens, saveTokens, type User } from "../api/client";

export type SessionStatus = "guest" | "checking" | "authed";

export interface Session {
  status: SessionStatus;
  user: User | null;
  configured: boolean;
  login: (email: string, password: string) => Promise<User>;
  register: (email: string, name: string, password: string) => Promise<User>;
  logout: () => Promise<void>;
  reload: () => Promise<User>;
}

/** App-level account session. Tokens live in localStorage; the user comes
    from GET /users/me so the tier/email flags are always server truth. */
export function useSession(): Session {
  const configured = isApiConfigured();
  const [status, setStatus] = useState<SessionStatus>(() =>
    configured && loadTokens() ? "checking" : "guest",
  );
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    if (status !== "checking") return;
    api
      .me()
      .then((u) => {
        setUser(u);
        setStatus("authed");
      })
      .catch(() => {
        saveTokens(null);
        setStatus("guest");
      });
  }, [status]);

  const login = useCallback(async (email: string, password: string) => {
    const session = await api.login(email, password);
    setUser(session.user);
    setStatus("authed");
    return session.user;
  }, []);

  const register = useCallback(async (email: string, name: string, password: string) => {
    const session = await api.register(email, name, password);
    setUser(session.user);
    setStatus("authed");
    return session.user;
  }, []);

  const logout = useCallback(async () => {
    try {
      await api.logout();
    } finally {
      setUser(null);
      setStatus("guest");
    }
  }, []);

  const reload = useCallback(async () => {
    const u = await api.me();
    setUser(u);
    setStatus("authed");
    return u;
  }, []);

  return { status, user, configured, login, register, logout, reload };
}
