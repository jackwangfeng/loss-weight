#!/usr/bin/env node
/*
 * E2E 测试用的零依赖静态服务器。
 *
 * 为什么不用 `python3 -m http.server`：它在给 headless Chromium serve
 * release 构建（main.dart.js 2.8MB + canvaskit.wasm + 若干 chunk）时
 * 表现极不稳定，长跑容易卡死。Node 的 http 模块基于事件循环，
 * 大量并发静态文件请求下稳得多。
 *
 * 用法:
 *   node tests/static_server.js              # 默认 8888, 服务 build/web/
 *   PORT=9000 node tests/static_server.js    # 自定义端口
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', 'build', 'web');
const PORT = parseInt(process.env.PORT || '8888', 10);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript',
  '.mjs':  'application/javascript',
  '.json': 'application/json',
  '.css':  'text/css',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif':  'image/gif',
  '.svg':  'image/svg+xml',
  '.ico':  'image/x-icon',
  '.wasm': 'application/wasm',
  '.ttf':  'font/ttf',
  '.otf':  'font/otf',
  '.woff':  'font/woff',
  '.woff2': 'font/woff2',
  '.map':  'application/json',
};

if (!fs.existsSync(path.join(ROOT, 'index.html'))) {
  console.error(`ERROR: ${ROOT}/index.html 不存在，请先 flutter build web --release`);
  process.exit(1);
}

const server = http.createServer((req, res) => {
  let url = decodeURIComponent(req.url.split('?')[0]);
  if (url === '/') url = '/index.html';

  // 路径越狱保护
  const filePath = path.join(ROOT, url);
  if (!filePath.startsWith(ROOT + path.sep) && filePath !== ROOT) {
    res.writeHead(403); res.end(); return;
  }

  fs.stat(filePath, (err, st) => {
    if (err || !st.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not Found');
      return;
    }
    const mime = MIME[path.extname(filePath).toLowerCase()] || 'application/octet-stream';
    res.writeHead(200, {
      'Content-Type': mime,
      'Content-Length': st.size,
      'Cache-Control': 'no-store',
    });
    fs.createReadStream(filePath).pipe(res);
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`static server serving ${ROOT}`);
  console.log(`listening on http://localhost:${PORT}`);
});

// 优雅退出
for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => server.close(() => process.exit(0)));
}
