import type { AuthResponse, AuthTokens, AuthUser, InitialUploadRequest, InitialUploadResponse } from './types';

export class ApiError extends Error {
	status: number;
	code: string;

	constructor(status: number, code: string, message?: string) {
		super(message || code);
		this.status = status;
		this.code = code;
	}
}

export type TokenProvider = {
	getAccessToken: () => string | null;
	getRefreshToken: () => string | null;
	setTokens: (tokens: AuthTokens | null) => void | Promise<void>;
	getDeviceId: () => string;
};

function baseUrl(): string {
	const raw = import.meta.env.PUBLIC_API_BASE_URL as string | undefined;
	return (raw || '').replace(/\/$/, '');
}

export function isApiConfigured(): boolean {
	return baseUrl().length > 0;
}

export class ApiClient {
	constructor(private tokens: TokenProvider) {}

	async register(email: string, name: string, password: string): Promise<AuthResponse> {
		return this.requestUnauthed<AuthResponse>('/api/v1/auth/register', {
			method: 'POST',
			body: JSON.stringify({ email, name, password })
		});
	}

	async login(email: string, password: string): Promise<AuthResponse> {
		return this.requestUnauthed<AuthResponse>('/api/v1/auth/login', {
			method: 'POST',
			body: JSON.stringify({ email, password })
		});
	}

	async refresh(refreshToken: string): Promise<{ tokens: AuthTokens }> {
		return this.requestUnauthed<{ tokens: AuthTokens }>('/api/v1/auth/refresh', {
			method: 'POST',
			body: JSON.stringify({ refreshToken })
		});
	}

	async logout(refreshToken: string | null): Promise<void> {
		await this.request('/api/v1/auth/logout', {
			method: 'POST',
			body: JSON.stringify({ refreshToken: refreshToken || '' })
		});
	}

	async me(): Promise<AuthUser> {
		return this.request<AuthUser>('/api/v1/users/me', { method: 'GET' });
	}

	async initialUpload(payload: InitialUploadRequest): Promise<InitialUploadResponse> {
		return this.request<InitialUploadResponse>('/api/v1/sync/initial-upload', {
			method: 'POST',
			body: JSON.stringify(payload)
		});
	}

	async fullSync(limit = 100): Promise<unknown> {
		return this.request(`/api/v1/sync/full?limit=${limit}`, { method: 'GET' });
	}

	private async requestUnauthed<T>(path: string, init: RequestInit): Promise<T> {
		const url = `${baseUrl()}${path}`;
		if (!baseUrl()) throw new ApiError(0, 'api_not_configured', 'PUBLIC_API_BASE_URL is empty');
		const res = await fetch(url, {
			...init,
			headers: {
				'Content-Type': 'application/json',
				Accept: 'application/json',
				...(init.headers || {})
			}
		});
		return this.parse<T>(res);
	}

	private async request<T>(path: string, init: RequestInit, retried = false): Promise<T> {
		const url = `${baseUrl()}${path}`;
		if (!baseUrl()) throw new ApiError(0, 'api_not_configured', 'PUBLIC_API_BASE_URL is empty');

		const access = this.tokens.getAccessToken();
		const headers: Record<string, string> = {
			Accept: 'application/json',
			'X-Device-ID': this.tokens.getDeviceId(),
			...(init.headers as Record<string, string>)
		};
		if (init.body) headers['Content-Type'] = 'application/json';
		if (access) headers.Authorization = `Bearer ${access}`;

		const res = await fetch(url, { ...init, headers });

		if (res.status === 401 && !retried) {
			const refreshed = await this.tryRefresh();
			if (refreshed) return this.request<T>(path, init, true);
		}

		return this.parse<T>(res);
	}

	private async tryRefresh(): Promise<boolean> {
		const rt = this.tokens.getRefreshToken();
		if (!rt) return false;
		try {
			const { tokens } = await this.refresh(rt);
			await this.tokens.setTokens(tokens);
			return true;
		} catch {
			await this.tokens.setTokens(null);
			return false;
		}
	}

	private async parse<T>(res: Response): Promise<T> {
		if (res.status === 204) return undefined as T;
		const text = await res.text();
		let data: unknown = null;
		if (text) {
			try {
				data = JSON.parse(text);
			} catch {
				data = { message: text };
			}
		}
		if (!res.ok) {
			const body = data as { error?: string; message?: string } | null;
			const code = body?.error || body?.message || `http_${res.status}`;
			throw new ApiError(res.status, code, code);
		}
		return data as T;
	}
}
