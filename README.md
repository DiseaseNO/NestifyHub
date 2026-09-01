# Nestify Hub

Samleapp for husholdet, til mobil. **Foreløpig et tomt skall** — prosjektfil, signering og
TestFlight-løype står klart, men appen har ingen moduler og ingen datalag ennå.

Kameraene bor i sin egen app (`CameraRelay`) og skal ikke inn her.

## Navn

| | | |
|---|---|---|
| Bundle-ID | `no.gustavs1.hjemme` | permanent — bytte betyr ny app i App Store Connect, nye profiler og ny paring på hver enhet |
| Visningsnavn | **Nestify Hub** | settes av secreten `DISPLAY_NAME`, kan byttes uten kodeendring |
| Repo / prosjekt / scheme | `Navet` | **internt** navn. Var visningsnavnet en periode; endres ikke, for det koster mer enn det smaker |

Appen er ikke et smarthus — den samler husholdet: lys og varme, strøm, bilene,
handleliste, kalender, søppel, barnas oppgaver og FPL. Navnet er valgt så det tåler at
det kommer til ting som ikke handler om huset.

Skallet leser visningsnavnet fra bundelen i stedet for å hardkode det, så teksten i appen
følger med hvis `DISPLAY_NAME` endres.

## Hvorfor GitHub og ikke intern GitLab

iOS-bygg krever macOS. GitHub Actions har `macos-15`-løpere; den interne GitLab-en har
ingen. Derfor ligger app-repoene på GitHub, mens alt annet i hjemmenettet ligger på
GitLab.

## Oppsett før første bygg

Xcode-prosjektet er **generert** av XcodeGen fra `project.yml` og ligger ikke i git.
Det holder fila fri for merge-konflikter og gjør at CI bygger fra samme kilde.

```bash
brew install xcodegen
DEVELOPMENT_TEAM=<team> BUILD_NUMBER=1 DISPLAY_NAME=Hjemme xcodegen generate
open Hjemme.xcodeproj
```

### GitHub-secrets som må settes

Samme sett som `CameraRelay` bruker. Uten dem stopper TestFlight-jobben.

| Secret | Hva |
|---|---|
| `APPLE_TEAM_ID` | Apple Developer team-ID |
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64` | App Store Connect API-nøkkel |
| `MATCH_GIT_URL`, `MATCH_GIT_BASIC_AUTHORIZATION`, `MATCH_PASSWORD` | sertifikat-repoet til fastlane match |
| `DISPLAY_NAME` | `Nestify Hub` — navnet under ikonet. Må være unikt på App Store (ITMS-90129) |

### App Store Connect

Bundle-ID **`no.gustavs1.hjemme`** må registreres og appen opprettes i App Store Connect
før første opplasting. Appnavnet der må også være unikt. `match` lager profilen ved første kjøring (`readonly: false`).

## Versjonering — bump FØR hver TestFlight-opplasting

Øk `MARKETING_VERSION` i `project.yml` hver gang det pushes en ny endring til TestFlight.
Ett sted, én linje — `CFBundleShortVersionString` følger med automatisk.

| Endring | Bump |
|---|---|
| Feilretting, justering av utseende | **patch** — 0.1.1 |
| Ny modul eller noe merkbart nytt i bruk | **minor** — 0.2 |
| Appen gjør noe vesentlig annet enn før | **major** — 1.0 |

**Byggnummeret skal du ALDRI røre.** `CFBundleVersion` settes fra `github.run_number` og
stiger av seg selv.

Status: **0.1 = ikke lastet opp ennå.**

## Merk

- **Ingen adresser, IP-er eller hemmeligheter i repoet.** Server og token legges inn i
  appen manuelt, slik CameraRelay gjør det.
- App-ikonet er et midlertidig plassholder-ikon. Byttes før noe går til App Store.
