// Static Web App fuer die Profil-Website mw-labs.at
// Deploy: az deployment group create -g rg-mwlabs-web -f infra/swa.bicep
// Inhalte werden per GitHub Actions mit Deployment-Token deployt (keine Repo-Verknuepfung im Portal).
// Region: eastus2, weil westeurope fuer neue Subscriptions gesperrt ist (Okt. 2026).
// Die Region betrifft nur die Ressourcen-Metadaten; Inhalte werden global ausgeliefert.

param name string = 'swa-mwlabs-web'
param location string = 'eastus2'

resource swa 'Microsoft.Web/staticSites@2022-09-01' = {
  name: name
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    stagingEnvironmentPolicy: 'Enabled'   // PR-Previews als Test-/Abnahmeumgebung
    allowConfigFileUpdates: true          // staticwebapp.config.json aus dem Repo wird angewendet
  }
}

output defaultHostname string = swa.properties.defaultHostname
