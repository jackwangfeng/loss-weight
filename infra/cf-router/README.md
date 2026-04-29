# cf-router — Cloudflare Worker for recompdaily.com path-based routing

Routes traffic on `recompdaily.com/*`:

- `/v1/*` and `/health` → EC2 backend at `ec2-13-215-200-80.ap-southeast-1.compute.amazonaws.com:8000`
- everything else → Cloudflare Pages project `recompdaily-web` (Flutter web bundle)

## Why a Worker

We need apex `recompdaily.com` to serve the web app while keeping `/v1/*` going to the Go backend on EC2. Cloudflare offers three ways to do this; we picked the Worker:

| | Origin Rules | Page Rules | Worker |
|--|--|--|--|
| API permission | `Configuration Rules: Edit` (we don't have) | `Page Rules: Edit` (we have) — but no origin override | `workers (write) + workers_routes (write)` (we have) |
| Origin override by path | yes | no (forwarding only) | yes (free-form) |
| Speed | edge-native | edge-native | one extra V8 invocation (sub-ms) |

So Worker it is. The cost is one tiny V8 cold start per request (negligible).

## Deploy

```
cd infra/cf-router
npx wrangler deploy
```

Requires `wrangler login` first. Account ID `864167311d618f330747c17ada28b4c7` is hardcoded in wrangler.toml.

## EC2 hostname (not raw IP)

CF Workers reject `fetch()` to a raw IP origin (returns CF error 1003 → 403). We use the AWS-provided EC2 public DNS name (`ec2-13-215-200-80.ap-southeast-1.compute.amazonaws.com`) so the Worker fetch resolves through DNS to the same IP without tripping the IP-block.

If the EC2 IP ever changes, update `EC2_ORIGIN` in `src/index.js` and redeploy.

## DNS state

Apex `recompdaily.com` stays as **A → 13.215.200.80** (proxied). The Worker route `recompdaily.com/*` takes priority over DNS-based origin resolution, so the routing logic is entirely inside the Worker. **No DNS change is required for this Worker to function.**
