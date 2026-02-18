# KaselTech Demo Sites

Static file server that hosts client website demos at `https://demo.kasel.tech`.

Each demo is a statically exported Next.js site served under its own subpath (e.g., `/eliteautocare`). This repo contains **only compiled output** — no source code. The source code for each client site lives in its own separate repo.

**Live URL:** https://demo.kasel.tech

---

## How It Works

```
Client Source Repos                    This Repo (kasel-demos)
─────────────────                      ───────────────────────
eliteautocaresa/  ──build:demo──►      sites/eliteautocare/  ─┐
plumbingco/       ──build:demo──►      sites/plumbingco/     ─┼── Nginx ── demo.kasel.tech
roofingpros/      ──build:demo──►      sites/roofingpros/    ─┘
```

1. **Source repos** contain the full Next.js app (components, data, styles, API routes)
2. `npm run build:demo` produces a static HTML/CSS/JS export with a subpath prefix
3. The export gets copied into `sites/<demo-name>/` in this repo
4. Nginx serves all demo sites from a single container on Coolify
5. Cloudflare DNS + Tunnel routes `demo.kasel.tech` to the container

**Key point:** This repo is a deployment artifact — you never edit code here. All development happens in the client's source repo.

---

## Quick Reference

| Action | Command |
|--------|---------|
| Build + deploy a demo | `./build-demo.sh ../eliteautocaresa eliteautocare --deploy` |
| Build without deploying | `./build-demo.sh ../eliteautocaresa eliteautocare` |
| Test locally with Docker | `docker build -t kasel-demos . && docker run -p 8080:80 kasel-demos` |
| Trigger Coolify redeploy | `curl -sk -X POST "http://178.156.247.227:8000/api/v1/deploy" -H "Authorization: Bearer $COOLIFY_TOKEN" -H "Content-Type: application/json" -d '{"uuid": "lcgssowgkc444w4k004o0cck"}'` |
| View deployment dashboard | https://deploy.kasel.tech → KaselTech → production → kasel-demos |

---

## Adding a New Demo Site

### Step 1: Add demo export support to the client project

The client's Next.js project needs three things to support demo export:

#### 1a. `next.config.ts` — conditional static export

```ts
import type { NextConfig } from "next";

const isDemoExport = process.env.DEMO_EXPORT === 'true';

const nextConfig: NextConfig = {
  devIndicators: false,
  // ... any other config ...
  ...(isDemoExport && {
    output: 'export',
    basePath: process.env.DEMO_BASE_PATH || '',
    images: {
      loader: 'custom',
      loaderFile: './src/lib/demo-image-loader.ts',
    },
  }),
};

export default nextConfig;
```

When `DEMO_EXPORT` is not set (normal dev/production), the config is untouched — the site works as a full Next.js app with SSR, API routes, etc. When `DEMO_EXPORT=true`, it switches to static export mode with a basePath prefix.

#### 1b. `src/lib/demo-image-loader.ts` — image path fix

```ts
export default function demoImageLoader({ src }: { src: string }) {
  const basePath = process.env.NEXT_PUBLIC_BASE_PATH || '';
  return `${basePath}${src}`;
}
```

This is needed because Next.js `<Image>` component does NOT automatically prepend `basePath` to image `src` paths in static export mode. The custom loader handles this. It has zero effect in normal mode (basePath is empty string).

#### 1c. `package.json` — add build:demo script

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "build:demo": "DEMO_EXPORT=true NEXT_PUBLIC_BASE_PATH=$DEMO_BASE_PATH next build"
  }
}
```

#### 1d. Metadata routes (if they exist)

If the project has `robots.ts` or `sitemap.ts`, add `export const dynamic = 'force-static';` to each:

```ts
// src/app/robots.ts
import { MetadataRoute } from 'next';

export const dynamic = 'force-static';

export default function robots(): MetadataRoute.Robots {
  // ...
}
```

Without this, static export will fail with an error about these routes.

### Step 2: Build and deploy

```bash
cd /Users/charleskasel/apps/kasel-demos
./build-demo.sh ../newclient clientname --deploy
```

This will:
1. Run `build:demo` in the client project
2. Copy the output to `sites/clientname/`
3. Commit and push to GitHub
4. Trigger Coolify deployment

### Step 3: Update the landing page

Edit `index.html` to add the new demo to the list:

```html
<a href="/clientname/">
  <div class="site-name">Client Business Name</div>
  <div class="site-desc">Description of the business</div>
</a>
```

Commit, push, and redeploy.

---

## Updating an Existing Demo

After making changes in the client's source repo, just re-run the build script:

```bash
./build-demo.sh ../eliteautocaresa eliteautocare --deploy
```

The script replaces the old export with the new one and redeploys.

---

## Removing a Demo

```bash
# Delete the demo site files
rm -rf sites/demoname

# Remove the link from index.html
# (edit manually)

# Commit and deploy
git add -A && git commit -m "Remove demo: demoname" && git push
```

Coolify will auto-deploy on push, or trigger manually.

---

## Going Live (Demo → Production)

When a client is ready to go live, the source repo is already production-ready. The demo is just a static snapshot — the real repo has everything.

1. **Deploy the source repo to Vercel** (or any hosting):
   - Connect the client's GitHub repo (e.g., `kaseltech/eliteautocaresa`) to Vercel
   - Standard `next build` — no `DEMO_EXPORT` flag, no basePath
   - Full SSR, API routes, and all dynamic features work normally

2. **Point the client's domain** to Vercel (or configure DNS)

3. **Optionally remove the demo** from this repo (see "Removing a Demo" above)

Nothing needs to be "pulled out" of the demo repo — the demo is just compiled output. The source repo is the single source of truth and deploys independently.

---

## Demo Limitations

Static demo exports have these limitations compared to the full site:

| Feature | Demo | Production |
|---------|------|------------|
| Pages & navigation | Works | Works |
| Styling & animations | Works | Works |
| Images | Works (via custom loader) | Works |
| Contact form submission | Shows error on submit | Works |
| API routes | Not available | Works |
| Server components (dynamic) | Pre-rendered at build time | Dynamic |
| Image optimization | Disabled (unoptimized) | Full Next.js optimization |

These limitations are fine for demos — clients see the design, layout, and content. The contact form renders correctly but won't actually submit.

---

## Infrastructure Details

### Architecture

```
Browser → Cloudflare CDN → Cloudflare Tunnel → Traefik (Coolify) → Nginx container
                                                                     ├── /index.html (landing)
                                                                     ├── /eliteautocare/ (demo)
                                                                     └── /otherdemo/ (demo)
```

### Coolify

| Field | Value |
|-------|-------|
| Dashboard | https://deploy.kasel.tech |
| App name | kasel-demos |
| App UUID | `lcgssowgkc444w4k004o0cck` |
| Build type | Dockerfile |
| Domain | `https://demo.kasel.tech` |
| Port exposed | 80 |
| Server | Hetzner VPS (`bww4408c80os4sk80sog4wc0`) |
| Project | KaselTech (`pwowwsg404484w88c8w8w4o4`) |
| Environment | production |

### Cloudflare

| Field | Value |
|-------|-------|
| DNS record | `demo` CNAME → `8912efa2-...cfargotunnel.com` (proxied) |
| Tunnel | `kaseltech-prod` (`8912efa2-a960-4f35-bc04-64f49098a2ea`) |
| Ingress rule | `demo.kasel.tech` → `https://localhost:443` (noTLSVerify) |

### GitHub

| Field | Value |
|-------|-------|
| Repo | [kaseltech/kasel-demos](https://github.com/kaseltech/kasel-demos) (public) |
| GitHub App | `kaseltech-deploy` (grants Coolify access) |

---

## Repo Structure

```
kasel-demos/
├── README.md           # This file
├── Dockerfile          # Nginx container definition
├── nginx.conf          # Nginx server config (gzip, caching, routing)
├── index.html          # Landing page listing all demos
├── build-demo.sh       # Build + deploy automation script
├── .gitignore
├── .dockerignore
└── sites/
    └── eliteautocare/  # Static export from eliteautocaresa repo
        ├── index.html
        ├── about.html
        ├── services.html
        ├── contact.html
        ├── _next/          # JS/CSS/fonts
        └── images/         # Static images
```

---

## Troubleshooting

### Build fails with "force-static not configured"

The client project has `robots.ts` or `sitemap.ts` without `export const dynamic = 'force-static'`. Add it to each metadata route file. See Step 1d above.

### Images broken on demo site

The client project is missing the custom image loader (`src/lib/demo-image-loader.ts`) or `next.config.ts` isn't using it. Next.js `<Image>` does not prepend `basePath` to image paths in static export mode — the custom loader fixes this.

### Client-side navigation works but direct URL returns 404

The Nginx config uses `try_files` to serve `index.html` for SPA-style routing. If a new route pattern isn't working, check `nginx.conf`. Next.js static export creates both `/page.html` and `/page/index.html` — both should resolve.

### Deployment didn't update

1. Check that the git push went through: `git log --oneline -1`
2. Check Coolify dashboard for deployment status
3. Try a manual deploy trigger via the API (see Quick Reference table)
4. Cloudflare may cache aggressively — try `Cmd+Shift+R` to hard refresh

### "build:demo" script not found

The client project needs the `build:demo` script in `package.json`. See Step 1c above.
