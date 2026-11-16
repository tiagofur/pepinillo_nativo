// Static server for the built web app (build/) with SPA fallback.
// Survives rebuilds: serves from disk per-request, 404s instead of crashing.
// Usage: node scripts/serve-build.mjs [port]
import http from 'node:http';
import { promises as fs } from 'node:fs';
import path from 'node:path';

const ROOT = new URL('../web/build/', import.meta.url).pathname;
const PORT = Number(process.argv[2] || 4174);

const MIME = {
	'.html': 'text/html; charset=utf-8',
	'.js': 'text/javascript; charset=utf-8',
	'.mjs': 'text/javascript; charset=utf-8',
	'.css': 'text/css; charset=utf-8',
	'.svg': 'image/svg+xml',
	'.png': 'image/png',
	'.jpg': 'image/jpeg',
	'.webp': 'image/webp',
	'.ico': 'image/x-icon',
	'.json': 'application/json',
	'.webmanifest': 'application/manifest+json',
	'.xml': 'application/xml',
	'.txt': 'text/plain',
	'.woff2': 'font/woff2',
	'.map': 'application/json'
};

async function resolveFile(urlPath) {
	const decoded = decodeURIComponent(urlPath.split('?')[0]);
	let candidate = path.join(ROOT, decoded);
	if (!candidate.startsWith(ROOT)) return null; // traversal guard
	try {
		const st = await fs.stat(candidate);
		if (st.isDirectory()) candidate = path.join(candidate, 'index.html');
		await fs.access(candidate);
		return candidate;
	} catch {
		return null;
	}
}

const server = http.createServer(async (req, res) => {
	try {
		const urlPath = req.url || '/';
		let file = await resolveFile(urlPath);
		if (!file && !path.extname(urlPath)) {
			// SPA fallback: extensionless routes → the prerendered page or app shell.
			const asHtml = urlPath.replace(/\/$/, '') + '.html';
			file = await resolveFile(asHtml);
			if (!file) file = await resolveFile('/app.html');
		}
		if (!file) {
			res.writeHead(404, { 'Content-Type': 'text/plain' });
			res.end('Not found');
			return;
		}
		const data = await fs.readFile(file);
		res.writeHead(200, {
			'Content-Type': MIME[path.extname(file)] ?? 'application/octet-stream',
			'Cache-Control': 'no-cache'
		});
		res.end(data);
	} catch (err) {
		res.writeHead(500);
		res.end('Internal error');
	}
});

server.listen(PORT, '127.0.0.1', () => console.log(`static build server on :${PORT} → ${ROOT}`));
