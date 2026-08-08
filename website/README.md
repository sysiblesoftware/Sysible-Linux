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

## Hosting options

**GitHub Pages (simplest).** Either:
- move `index.html` to the repo root or a `/docs` folder and set Pages source
  to that folder, or
- keep `website/` and publish it with a tiny Pages workflow that uploads the
  `website` directory as the Pages artifact.

**Your own site.** Copy `website/index.html` to your web root (rename to
`downloads.html` or drop it at `/downloads/index.html`). That's it — it's one
file. The GitHub API calls are unauthenticated and cached by the browser; the
page still works if they're blocked (it falls back to the Releases pages).

## Updating

Nothing to update per release — the page reads the **latest** GitHub release
automatically. Change the two repo constants at the top of the `<script>` if the
repositories are ever renamed.
