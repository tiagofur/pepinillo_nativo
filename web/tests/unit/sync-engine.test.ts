import { describe, expect, it } from 'vitest';
import { runFullPull } from '$lib/data/sync/engine';
import type { FullSyncResponse } from '$lib/data/remote/types';

/**
 * Minimal ApiClient stub: only `fullSync` is exercised by runFullPull. Pages
 * are returned in order from the `pages` array.
 */
function makeApi(pages: FullSyncResponse[]) {
	let i = 0;
	return {
		async fullSync(): Promise<FullSyncResponse> {
			return pages[i++] ?? {
				tasks: { items: [], hasMore: false },
				sessions: { items: [], hasMore: false },
				settings: [],
				serverTimestamp: '2026-08-05T00:00:00.000Z'
			};
		}
	};
}

describe('runFullPull', () => {
	it('follows task and session cursors until both done', async () => {
		const api = makeApi([
			{
				tasks: { items: [{ syncId: 't1' } as never], nextCursor: 'c1', hasMore: true },
				sessions: { items: [{ id: 's1' } as never], nextCursor: 'c1', hasMore: true },
				settings: [{ key: 'locale', value: 'es' }],
				serverTimestamp: '2026-08-05T00:00:00.000Z'
			},
			{
				tasks: { items: [{ syncId: 't2' } as never], hasMore: false },
				sessions: { items: [{ id: 's2' } as never], hasMore: false },
				settings: [{ key: 'locale', value: 'es' }],
				serverTimestamp: '2026-08-05T00:00:01.000Z'
			}
		]);

		const result = await runFullPull(api as never, 100, 10);
		expect(result.tasks).toHaveLength(2);
		expect(result.sessions).toHaveLength(2);
		expect(result.settings).toEqual([{ key: 'locale', value: 'es' }]);
		expect(result.serverTimestamp).toBe('2026-08-05T00:00:01.000Z');
	});

	it('stops when the first page has no more on either collection', async () => {
		const api = makeApi([
			{
				tasks: { items: [], hasMore: false },
				sessions: { items: [], hasMore: false },
				settings: [],
				serverTimestamp: '2026-08-05T00:00:00.000Z'
			}
		]);
		const result = await runFullPull(api as never, 100, 10);
		expect(result.tasks).toHaveLength(0);
		expect(result.sessions).toHaveLength(0);
	});
});
