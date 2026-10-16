# mw-labs-web

Persönliche Profil-Website von Mathias Würflinger – [mw-labs.at](https://mw-labs.at).

Reines HTML + CSS: kein Build-Step, kein Framework, kein JavaScript, keine externen Ressourcen, keine Cookies. Gehostet auf Azure Static Web Apps (`swa-mwlabs-web`, Free-Tier), deployt per GitHub Actions.

## Struktur

```
src/                          Wird 1:1 deployt (app_location)
  index.html                  Startseite DE            → /
  offenlegung.html            Offenlegung § 25 MedienG → /offenlegung
  datenschutz.html            Datenschutzerklärung     → /datenschutz
  404.html                    Fehlerseite (DE/EN)
  en/
    index.html                Startseite EN            → /en/
    legal-notice.html         Legal notice             → /en/legal-notice
    privacy.html              Privacy policy           → /en/privacy
  css/style.css               Einziges Stylesheet (System-Fonts, Hell/Dunkel)
  img/favicon.svg             Selbst erstelltes Favicon
  .well-known/security.txt    RFC 9116
  staticwebapp.config.json    Security-Header, 404-Handling
infra/swa.bicep               Static Web App als IaC (Referenz, nicht Teil der Pipeline)
.github/workflows/deploy.yml  Deployment + PR-Previews
.github/dependabot.yml        Wöchentliche Updates der gepinnten Actions
```

Interne Links sind ohne `.html` geschrieben (`/offenlegung`). Azure Static Web Apps liefert dafür die passende `.html`-Datei aus.

## Inhalte pflegen

- DE- und EN-Seiten immer gemeinsam ändern, Paare: `index.html` ↔ `en/index.html`, `offenlegung.html` ↔ `en/legal-notice.html`, `datenschutz.html` ↔ `en/privacy.html`.
- Neue Seite: `canonical`, `hreflang` (de, en, x-default), Sprachwechsel-Link im Header und Footer-Links mitführen.
- Kein Inline-CSS/-JS (`style="…"`, `<style>`, `<script>`) – die CSP blockiert es.
- Keine externen Ressourcen (Fonts, Bilder, Skripte von fremden Hosts). Externe Links mit `rel="noopener noreferrer"`.
- Bei Änderungen an der Datenschutzerklärung das Stand-Datum anpassen.
- Laufend prüfen:
  - „fast neun Jahre“ auf der Startseite (DE/EN) aktualisieren, wenn es nicht mehr stimmt.
  - Jahreszahl im Footer (`© 2026`) jährlich anpassen.
  - `Expires` in `src/.well-known/security.txt` vor Ablauf verlängern (aktuell 2027-10-17), am besten jährlich zusammen mit der Token-Rotation.

## Lokal testen

Ohne Toolchain, mit Python:

```powershell
python -m http.server 8080 --directory src
```

Dann http://localhost:8080 öffnen. Einschränkungen des einfachen Servers: Er setzt keine Security-Header, liefert die 404-Seite nicht aus und kennt keine Links ohne `.html` (`/offenlegung` ergibt dort 404; zum Testen `/offenlegung.html` aufrufen).

Realitätsnah, inkl. `staticwebapp.config.json` (Header, 404, Links ohne Endung), mit der SWA CLI. Sie wird nur lokal genutzt und ist nicht Teil des Deployments:

```powershell
npx @azure/static-web-apps-cli start src
```

→ http://localhost:4280

Die verbindliche Abnahme erfolgt in der PR-Preview (siehe unten).

## Deployment

Workflow: `.github/workflows/deploy.yml`, Action `Azure/static-web-apps-deploy` mit dem Deployment-Token aus dem Repository-Secret `AZURE_STATIC_WEB_APPS_API_TOKEN`. Die SWA ist bewusst **nicht** über das Azure-Portal mit dem Repo verknüpft.

Ablauf:

1. Branch von `main` anlegen, Änderungen committen, pushen.
2. Pull Request auf `main` öffnen → der Workflow erstellt eine **Preview-Umgebung** und kommentiert die URL im PR. Jeder weitere Push aktualisiert sie.
3. Preview prüfen.
4. Squash-Merge auf GitHub → Push auf `main` deployt in **Produktion** (https://mw-labs.at); die Preview-Umgebung wird beim Schließen des PRs automatisch entfernt.

Hinweise:

- Free-Tier: maximal **3 Preview-Umgebungen** gleichzeitig. Sind alle belegt, schlägt der Preview-Deploy fehl – alte PRs schließen.
- Previews sind öffentlich erreichbar (unkritisch, alle Inhalte sind öffentlich).
- `main` ist per Ruleset geschützt: nur per PR, nur Squash-Merge.

### Pipeline-Sicherheit

Das Repo ist öffentlich, daher:

- Trigger nur `push` auf `main` und `pull_request` auf `main`. **Kein `pull_request_target`**, kein `workflow_run` mit Secrets.
- Deploy- und Close-Job laufen nur für Pushes auf `main` und PRs aus diesem Repo – PRs aus Forks erhalten keine Secrets und deployen nicht.
- `permissions`: workflowweit `contents: read`, im Deploy-Job zusätzlich `pull-requests: write` (Preview-Kommentar).
- Alle Actions auf vollständigen Commit-SHA gepinnt (Version als Kommentar). Updates schlägt Dependabot wöchentlich als PR vor; vor dem Merge Release-Notes prüfen.
- `actions/checkout` mit `persist-credentials: false`.

## Token-Rotation

Das Deployment-Token jährlich (z. B. jeden Oktober) und sofort bei Verdacht auf Kompromittierung erneuern:

1. Azure-Portal → Static Web App **swa-mwlabs-web** → **Übersicht** → **Bereitstellungstoken verwalten**.
2. **Zurücksetzen** wählen und bestätigen. Das alte Token ist damit sofort ungültig.
3. Neues Token kopieren.
4. GitHub → Repo `mw-labs-web` → **Settings** → **Secrets and variables** → **Actions** → `AZURE_STATIC_WEB_APPS_API_TOKEN` → **Update** → neues Token einfügen und speichern.
5. Workflow testen: unter **Actions** den letzten Lauf auf `main` mit **Re-run jobs** erneut ausführen oder einen PR öffnen.

Alternativ per CLI:

```powershell
az staticwebapp secrets reset-api-key -n swa-mwlabs-web -g rg-mwlabs-web
az staticwebapp secrets list -n swa-mwlabs-web -g rg-mwlabs-web --query properties.apiKey -o tsv | gh secret set AZURE_STATIC_WEB_APPS_API_TOKEN -R Wuerfi33/mw-labs-web
```

Das Token nie in Logs, Issues oder Commits ausgeben.

## Infrastruktur

`infra/swa.bicep` beschreibt die Static Web App (Free, eastus2, Staging-Umgebungen aktiv). Sie ist bereits angelegt; die Datei dient als Referenz und zur Wiederherstellung:

```powershell
az deployment group create -g rg-mwlabs-web -f infra/swa.bicep
```

DNS-Zone und Custom Domains (`mw-labs.at`, `www.mw-labs.at` → 301) werden im privaten Repo `mw-labs-infra` verwaltet.
