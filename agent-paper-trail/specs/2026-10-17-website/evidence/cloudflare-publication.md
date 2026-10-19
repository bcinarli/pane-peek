---
task: cloudflare-publication
verdict: Pending
closed: ""
---

# Cloudflare publication

2026-10-19, agent-observed: Cloudflare Pages project `panepeek` deploys [merged source `cefced3`](https://github.com/bcinarli/pane-peek/commit/cefced33569ade7317f730ead8712d9ecb31d6a4) from `main`. Framework None, build `exit 0`, output `website`. [Hosted preview](https://panepeek.pages.dev) was checked before binding [panepeek.app](https://panepeek.app). Automatic production deployments are enabled.

Pages uses the existing GitHub installation scoped to this repository and requires no separate deployment API token. This replaces the proposed Workers Static Assets build approach because its creation form did not offer the custom scoped token and otherwise created a broader token. The live result and approach reconciliation await manual acceptance.

| Configuration | Value |
| --- | --- |
| Primary DNS | Proxied CNAME `panepeek.app` to `panepeek.pages.dev` |
| Redirect DNS | Proxied A records for `www.panepeek.app`, `panepeek.com` and `www.panepeek.com` to `192.0.2.1` |
| Primary-zone redirect match | `(http.host eq "www.panepeek.app")` |
| Secondary-zone redirect match | `(http.host in {"panepeek.com" "www.panepeek.com"})` |
| Redirect target | Dynamic `concat("https://panepeek.app", http.request.uri.path)`, status 301, preserve query string enabled |
| Email links | Email Address Obfuscation off on panepeek.app, preserving the source mailto links |

2026-10-19, agent-observed with certificate-validating public HTTPS requests: Home, Support and Privacy return 200 and match the accepted source byte for byte. Shared CSS, both scripts, logo and dark hero image also return 200 and match. Browser inspection confirms the live homepage renders. No source changes were needed for deployment.

2026-10-19, agent-observed: 16 HTTP/HTTPS requests cover all four hostnames at `/` and `/support/?source=launch&check=1`. Primary HTTPS returns 200; primary HTTP and every alias return 301 directly to the matching primary HTTPS URL. Paths and both query parameters are preserved without loops. All six original mail-related DNS records are unchanged: two MX, DKIM, SPF, DMARC and Apple domain verification.

2026-10-19, agent-observed: An unknown path and requests for `.git/HEAD`, `Package.swift` and the paper-trail README return the homepage with HTTP 200. Repository contents are not exposed; Pages' default homepage fallback remains. A dedicated 404 page is a separate possible improvement. Public GitHub download access and the remaining W4 accessibility checks stay open.

Tighten retained the static site and existing GitHub grant without adding a framework, server code or deployment secrets. Probe found and corrected Cloudflare's automatic email-link rewriting; post-change Support and Privacy responses match source. Manual review of the live result remains pending.

2026-10-19, agent-observed: Offline Gitleaks 8.30.1 and repository path/privacy checks report zero findings across 25 unique files covering the eight pending records, merged launch changes and all website files. Manual review of the pending diff found only public links/contact information and deployment settings. The added launch screenshot contains public website content and no private metadata. The pending changes are Markdown only; no credentials, private keys or certificate files are included.
