// recompdaily.com 路由分流 Worker.
//
// /v1/* + /health  → EC2 后端 (http://13.215.200.80:8000)
// 其它              → Cloudflare Pages 静态站 (recompdaily-web.pages.dev)
//
// 为啥用 Worker 不用 Origin Rule：
// 现有 token 没有 Configuration Rules / ruleset 权限，但有 workers_routes/
// workers write。Worker 还能直接用 IP 而不是 hostname 转后端，省一层 DNS。

// CF Workers 不允许 fetch 裸 IP origin（返回 403 + error 1003）。
// 用 AWS 给 EC2 自动分配的公共 DNS 名，解析下来还是同一个 IP。
const EC2_ORIGIN = "http://ec2-13-215-200-80.ap-southeast-1.compute.amazonaws.com:8000";
const PAGES_ORIGIN = "https://recompdaily-web.pages.dev";

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname;

    // 走后端的路径
    const isBackend = path === "/health" || path.startsWith("/v1/");

    const targetOrigin = isBackend ? EC2_ORIGIN : PAGES_ORIGIN;
    const targetUrl = `${targetOrigin}${path}${url.search}`;

    // 复制 headers，去掉 cf-connecting-ip 之类不该回传的头
    // 注意 Host 必须改成目标 origin 的 host，否则 EC2 可能拒
    const newHeaders = new Headers(request.headers);
    const targetHost = new URL(targetOrigin).host;
    newHeaders.set("host", targetHost);

    const init = {
      method: request.method,
      headers: newHeaders,
      body: request.body,
      redirect: "manual",
    };

    return fetch(targetUrl, init);
  },
};
