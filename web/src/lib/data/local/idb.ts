import { openDB, type DBSchema, type IDBPDatabase } from 'idb';
import {
	DEFAULT_PREFERENCES,
	type FocusSession,
	type Preferences,
	type Task
} from '$lib/domain/entities/types';

const DB_NAME = 'pepinillo-web';
const DB_VERSION = 1;

interface PepinilloDB extends DBSchema {
	tasks: {
		key: string;
		value: Task;
		indexes: { 'by-status': string };
	};
	sessions: {
		key: string;
		value: FocusSession;
		indexes: { 'by-startedAt': string };
	};
	prefs: {
		key: string;
		value: Preferences & { id: string };
	};
	meta: {
		key: string;
		value:
			| { id: string; deviceId: string; schemaVersion: number }
			| AuthMeta
			| { id: string; [k: string]: unknown };
	};
}

export type AuthMeta = {
	id: 'auth';
	refreshToken: string | null;
	userJson: string | null;
};

let dbPromise: Promise<IDBPDatabase<PepinilloDB>> | null = null;

export async function openDb(): Promise<IDBPDatabase<PepinilloDB>> {
	if (!dbPromise) {
		dbPromise = openDB<PepinilloDB>(DB_NAME, DB_VERSION, {
			upgrade(db) {
				if (!db.objectStoreNames.contains('tasks')) {
					const tasks = db.createObjectStore('tasks', { keyPath: 'id' });
					tasks.createIndex('by-status', 'status');
				}
				if (!db.objectStoreNames.contains('sessions')) {
					const sessions = db.createObjectStore('sessions', { keyPath: 'id' });
					sessions.createIndex('by-startedAt', 'startedAt');
				}
				if (!db.objectStoreNames.contains('prefs')) {
					db.createObjectStore('prefs', { keyPath: 'id' });
				}
				if (!db.objectStoreNames.contains('meta')) {
					db.createObjectStore('meta', { keyPath: 'id' });
				}
			}
		});
	}
	return dbPromise;
}

export async function closeDb(): Promise<void> {
	if (dbPromise) {
		const db = await dbPromise;
		db.close();
		dbPromise = null;
	}
}

/** Test helper: wipe DB and reset connection. */
export async function resetDbForTests(): Promise<void> {
	await closeDb();
	await new Promise<void>((resolve, reject) => {
		const req = indexedDB.deleteDatabase(DB_NAME);
		req.onsuccess = () => resolve();
		req.onerror = () => reject(req.error);
		req.onblocked = () => resolve();
	});
	dbPromise = null;
}

function uuidV4(): string {
	if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) {
		return crypto.randomUUID();
	}
	return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
		const r = (Math.random() * 16) | 0;
		const v = c === 'x' ? r : (r & 0x3) | 0x8;
		return v.toString(16);
	});
}

const DEVICE_META_ID = 'device';
const PREFS_ID = 'preferences';

export async function getDeviceId(): Promise<string> {
	const db = await openDb();
	const existing = await db.get('meta', DEVICE_META_ID);
	if (existing && 'deviceId' in existing && typeof existing.deviceId === 'string' && existing.deviceId) {
		return existing.deviceId;
	}
	const deviceId = uuidV4();
	await db.put('meta', {
		id: DEVICE_META_ID,
		deviceId,
		schemaVersion: DB_VERSION
	});
	return deviceId;
}

const AUTH_META_ID = 'auth';

export async function loadAuthMeta(): Promise<AuthMeta> {
	const db = await openDb();
	const row = await db.get('meta', AUTH_META_ID);
	if (row && row.id === 'auth') {
		return row as AuthMeta;
	}
	return { id: 'auth', refreshToken: null, userJson: null };
}

export async function saveAuthMeta(meta: Omit<AuthMeta, 'id'>): Promise<void> {
	const db = await openDb();
	await db.put('meta', { id: AUTH_META_ID, ...meta });
}

export async function clearAuthMeta(): Promise<void> {
	const db = await openDb();
	await db.delete('meta', AUTH_META_ID);
}

export async function getPreferences(): Promise<Preferences> {
	const db = await openDb();
	const row = await db.get('prefs', PREFS_ID);
	if (!row) {
		return { ...DEFAULT_PREFERENCES };
	}
	const { id: _id, ...prefs } = row;
	return { ...DEFAULT_PREFERENCES, ...prefs };
}

export async function savePreferences(prefs: Preferences): Promise<void> {
	const db = await openDb();
	await db.put('prefs', { id: PREFS_ID, ...prefs });
}

export async function upsertTask(task: Task): Promise<void> {
	const db = await openDb();
	await db.put('tasks', task);
}

export async function removeTask(id: string): Promise<void> {
	const db = await openDb();
	await db.delete('tasks', id);
}

export async function listActiveTasks(): Promise<Task[]> {
	const db = await openDb();
	const all = await db.getAll('tasks');
	return all
		.filter((t) => t.status === 'active')
		.sort((a, b) => a.order - b.order || a.createdAt.localeCompare(b.createdAt));
}

export async function listAllTasks(): Promise<Task[]> {
	const db = await openDb();
	const all = await db.getAll('tasks');
	return all.sort((a, b) => a.order - b.order || a.createdAt.localeCompare(b.createdAt));
}

export async function saveSession(session: FocusSession): Promise<void> {
	const db = await openDb();
	await db.put('sessions', session);
}

/**
 * Bulk-replace task rows after a server merge. Each task is upserted (put) so
 * records absent from `tasks` are left intact — callers pass the merged superset.
 */
export async function saveAllTasks(tasks: Task[]): Promise<void> {
	const db = await openDb();
	const tx = db.transaction('tasks', 'readwrite');
	await Promise.all(tasks.map((t) => tx.store.put(t)));
	await tx.done;
}

/**
 * Bulk-replace session rows after a server merge. Same upsert semantics as
 * saveAllTasks.
 */
export async function saveAllSessions(sessions: FocusSession[]): Promise<void> {
	const db = await openDb();
	const tx = db.transaction('sessions', 'readwrite');
	await Promise.all(sessions.map((s) => tx.store.put(s)));
	await tx.done;
}

export async function listSessions(): Promise<FocusSession[]> {
	const db = await openDb();
	const all = await db.getAll('sessions');
	return all.sort((a, b) => {
		const aKey = a.startedAt ?? a.createdAt;
		const bKey = b.startedAt ?? b.createdAt;
		return bKey.localeCompare(aKey);
	});
}

export type SyncMeta = {
	id: 'sync';
	/** ISO time of the last successful full round-trip (push + pull). */
	lastSyncAt: string | null;
	/** Epoch ms of the last pull-only refresh (used to throttle refocus pulls). */
	lastPullAt: number | null;
};

const SYNC_META_ID = 'sync';

export async function getSyncMeta(): Promise<SyncMeta> {
	const db = await openDb();
	const row = await db.get('meta', SYNC_META_ID);
	if (row && row.id === 'sync') {
		return row as SyncMeta;
	}
	return { id: 'sync', lastSyncAt: null, lastPullAt: null };
}

export async function saveSyncMeta(meta: Omit<SyncMeta, 'id'>): Promise<void> {
	const db = await openDb();
	await db.put('meta', { id: SYNC_META_ID, ...meta });
}

export async function clearSyncMeta(): Promise<void> {
	const db = await openDb();
	await db.delete('meta', SYNC_META_ID);
}
