# Sysible downloads website

A single, self-contained download page for **Sysible Linux** and **Sysible
Controller CE**. It lists the latest release assets, groups the split Sysible
Linux ISO parts by architecture (amd64 / arm64), and shows the verify +
reassemble commands and a VMware Fusion install guide.

## How it works

- `index.html` is fully self-contained — inline CSS, JS and SVG, no external
  assets or fonts. It works offline and drops into any static host.
- The download lists are **progressively enhanced**: the page renders complete
  static content first, then, when the browser can reach `api.github.com`, it
  fetches the latest releases of
  `sysiblesoftware/Sysible-Linux` and `sysiblesoftware/sysible-controller`
  and fills in the real part files, sizes and checksums.
- No build step. No backend. No tracking.

## Deploy — Cloudflare Pages (current)

The site auto-deploys to **Cloudflare Pages** via
`.github/workflows/website.yml` on every push to `main` that touches `website/`.
Project name **`sysible`** → served at **https://sysible.pages.dev**.

**One-time setup (do this once):**

1. **Create a Cloudflare API token** — dashboard → *My Profile → API Tokens →
   Create Token → "Create Custom Token"*. Give it the permission
   **Account → Cloudflare Pages → Edit** (scoped to your account). Copy the token.
2. **Find your Account ID** — Cloudflare dashboard → any domain / *Workers &
   Pages* → the *Account ID* shown in the right sidebar (or *Account Home → copy
   Account ID*).
3. **Add two GitHub repo secrets** — repo → *Settings → Secrets and variables →
   Actions → New repository secret*:
   - `CLOUDFLARE_API_TOKEN` = the token from step 1
   - `CLOUDFLARE_ACCOUNT_ID` = the Account ID from step 2
4. **Trigger a deploy** — push any change under `website/`, or run the **Website**
   workflow manually (*Actions → Website → Run workflow*). The workflow creates
   the `sysible` Pages project on first run and deploys `website/`.

Until the secrets exist, the workflow runs green but **skips** the deploy with a
warning (so it never blocks). `_headers` sets sensible cache/security headers.

**Add a custom domain later** — Cloudflare dashboard → *Workers & Pages →
sysible → Custom domains → Set up a domain* (e.g. `get.sysible.io`). Requires the
domain's DNS to be on Cloudflare; it provisions the certificate automatically.

## Other hosting options

- **GitHub Pages** — move `index.html` to `/docs` (or root) and set Pages source
  there, or publish `website/` via a Pages workflow.
- **Any static host / your own site** — copy `website/index.html` to your web
  root. It's one self-contained file; the GitHub API calls are unauthenticated
  and the page still works if they're blocked (it falls back to the Releases
  pages).

## Updating

Nothing to update per release — the page reads the **latest** GitHub release
automatically. Change the two repo constants at the top of the `<script>` if the
repositories are ever renamed.
