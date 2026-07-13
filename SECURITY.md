# Security posture — Clodia Platform

**Ultimo aggiornamento:** 2026-07-13
**Valutazione ancorata ai commit:** `clodia-logic@fde43ea` · `clodia-tools@ccdee04` · `clodia-web@333117c` · `clodia-pwa@e55eba6`

Questo documento descrive lo **stato corrente dei controlli tecnici di sicurezza**
implementati da Clodia Platform, mappati sui controlli tecnologici (Tema 8)
dell'**Annex A di ISO/IEC 27001:2022**. È un'istantanea onesta di *ciò che il
software fa oggi* — non una certificazione né una garanzia.

---

## ⚠️ Usa il sistema a tuo rischio e pericolo (as-is / no warranty)

Clodia Platform è software **self-hosted** distribuito **"COSÌ COM'È" (AS-IS)**,
**senza alcuna garanzia** di alcun tipo, espressa o implicita, incluse — a titolo
esemplificativo — le garanzie di commerciabilità, idoneità a uno scopo
particolare, sicurezza, assenza di difetti o non violazione. Coerentemente con la
licenza del progetto (**GNU AGPL v3**, sezioni 15–17; vedi [`LICENSE`](LICENSE) e
[`LICENSING.md`](LICENSING.md)):

- **Ti assumi l'intero rischio** relativo a qualità, prestazioni e sicurezza del
  software quando lo esegui sulla *tua* infrastruttura.
- **Gli autori non sono responsabili** per alcun danno diretto, indiretto,
  incidentale o consequenziale (perdita di dati, violazioni, interruzioni,
  mancati guadagni) derivante dall'uso o dall'impossibilità di usare il software.
- I controlli qui elencati come `OK` sono implementati **ma non sono stati
  sottoposti ad audit indipendente né a penetration test**. Uno stato `OK` indica
  presenza del controllo nel codice, non un livello di assurance certificato.
- **Nessuna certificazione ISO 27001**: ISO 27001 certifica l'ISMS di
  un'organizzazione, non un prodotto software. Questa tabella serve a *abilitare*
  i controlli tecnici per chi deploya, fornendo evidenza, non ad attestare
  conformità.

Se questo modello di rischio non è accettabile per il tuo contesto, **non usare il
software in produzione** senza una valutazione di sicurezza indipendente.

---

## Modello di responsabilità condivisa

Clodia Platform è un **artefatto software**: implementa controlli *tecnici*
(architettura, crittografia, controllo accessi, backup). I controlli
**organizzativi, sulle persone e fisici** dell'Annex A (leadership, gestione
fornitori, HR, sicurezza fisica dell'host, incident management d'organizzazione)
restano **responsabilità dell'organizzazione che deploya** e del suo ISMS.

Questo documento copre **solo i controlli tecnologici (Annex A, Tema 8)**.

---

## Controlli tecnici (ISO/IEC 27001:2022, Annex A — Tema 8)

**Legenda stato:** `OK` implementato · `PARZ` parziale · `PLAN` pianificato ·
`N/A` non applicabile (con giustificazione).
**(Deployer)** = responsabilità dell'organizzazione che deploya, non del software.

| # | Controllo | Stato | Note |
|---|-----------|:-----:|------|
| 8.1 | Dispositivi endpoint | OK | Container isolati; hardening dell'host = deployer |
| 8.2 | Accessi privilegiati | PARZ | Keystore DENY-default; super-agent bypassa la whitelist senza justification-trail né time-limit; rank model non enforced |
| 8.3 | Restrizione accesso alle informazioni | OK | Tiering SEAL-0..4 + appartenenza al topic + clearance firmata nel token di sessione |
| 8.4 | Accesso al codice sorgente | PARZ | Keystore broker per `git_push` (fast-forward, i non-super non possono spingere su branch protetti); manca branch-protection su `main` |
| 8.5 | Autenticazione sicura | PARZ | Token di sessione firmati Ed25519; nessun MFA umano, nessun rate-limit sul login; UI del gateway aperta se `CLODIA_TOOLS_UI_TOKEN` non è impostato |
| 8.6 | Gestione della capacità | PLAN | Nessun limite di risorse per container, nessun monitoraggio disco/RAM |
| 8.7 | Protezione da malware | PARZ | Immagini slim + shell in denial-by-default; nessun AV/scansione immagini |
| 8.8 | Gestione delle vulnerabilità tecniche | PARZ | Gitleaks in CI (segreti); nessuno scanning CVE (pip-audit/dependabot), pinning delle dipendenze lasco |
| 8.9 | Gestione della configurazione | PARZ | compose/config versionati; possibile drift della configurazione al deploy, nessun audit dei cambi di config |
| 8.10 | Cancellazione delle informazioni | PARZ | Soft-delete (cestino topic / trash Drive); nessuna policy di retention/TTL |
| 8.11 | Mascheramento dei dati | PARZ | Keystore/vault non restituiscono **mai** il valore di un segreto al modello; i messaggi d'errore espongono i nomi (non i valori); nessuna redazione dell'output |
| 8.12 | Prevenzione della fuga di dati | PARZ | `.dockerignore` esclude segreti/dati/topic; cap SEAL per canale; ACL di appartenenza; segreti mai passati al modello; manca hard-block dei dati sensibili verso provider a sovranità inferiore in lettura file |
| 8.13 | Backup | OK | Restic cifrato lato client → object storage; snapshot SQLite consistente; retention; restore-test automatico |
| 8.14 | Ridondanza | N/A | Design single-node; il requisito di disponibilità è una scelta del deployer; il disaster-recovery passa dal backup |
| 8.15 | Logging | PARZ | Audit delle operazioni (`colony.events`) + activity log + Langfuse opzionale; manca un log dedicato agli eventi di sicurezza e un sink centralizzato |
| 8.16 | Monitoraggio | PARZ | Pagina attività agenti + introspezione runtime + heartbeat; nessun alerting/soglia automatica |
| 8.17 | Sincronizzazione degli orologi | PARZ | Timestamp interni in UTC; scheduler in fuso locale; nessun `TZ` esplicito nei container, nessun healthcheck di clock-skew |
| 8.18 | Uso di utility privilegiate | OK | CLI PKI non esposta via API; keystore come broker; immutabilità dei super-agent |
| 8.19 | Installazione del software | PARZ | Pinning parziale (versioni via ARG); nessuna firma delle immagini né hash-lock |
| 8.20 | Sicurezza delle reti | PARZ | Bind su loopback + docker bridge; il perimetro di rete è responsabilità del deployer (es. VPN/Tailscale) |
| 8.21 | Sicurezza dei servizi di rete | PARZ | Autenticazione al gateway via PKI (chiave pubblica); il token bearer viaggia in HTTP in chiaro tra container; UI aperta di default |
| 8.22 | Segregazione delle reti | PARZ | Singolo bridge di default; nessuna segregazione tra gateway e agent-server |
| 8.23 | Filtraggio web | N/A | L'accesso al web avviene solo tramite tool whitelisted; nessun browser generico esposto |
| 8.24 | Uso della crittografia | PARZ | TLS verso i provider esterni presente; **il vault dei segreti non è cifrato a riposo** (solo permessi OS `0600`); traffico inter-container in HTTP in chiaro |
| 8.25 | Ciclo di vita di sviluppo sicuro | PARZ | Gitleaks + processo PR; nessun SSDLC formalizzato, test non eseguiti in CI |
| 8.26 | Requisiti di sicurezza delle applicazioni | OK | Documenti `POLICY.md` normativi + guard (anti path-traversal, whitelist shell, denial-by-default) |
| 8.27 | Architettura e principi di sicurezza | OK | Gateway come reference monitor + PKI della colonia + custodia dei segreti nel keystore; la chiave privata dell'agente non entra mai nel workspace |
| 8.28 | Secure coding | PARZ | Subprocess con argomenti a lista + whitelist dei path + anti shell-injection; nessuno strumento SAST, review non obbligatoria |
| 8.29 | Test di sicurezza in sviluppo e collaudo | PLAN | Suite di unit test presente ma non eseguita in CI; nessun penetration test / SAST / DAST |
| 8.30 | Sviluppo affidato in outsourcing | N/A | Sviluppo interno; nessun fornitore di sviluppo |
| 8.31 | Separazione degli ambienti | PARZ | Stack multipli via prefisso progetto + datadir distinte; nessun isolamento di rete tra ambienti |
| 8.32 | Gestione del cambiamento | PARZ | Git + processo PR + gitleaks; nessuna branch-protection, possibile drift del compose al deploy |
| 8.33 | Informazioni di test | N/A | Il prodotto non contiene dati di produzione/PII usati per i test |
| 8.34 | Protezione dei sistemi in fase di audit | N/A | Audit su sistemi operativi live = responsabilità del deployer |

**Sintesi Tema 8 (34 controlli):** 6 `OK` · 21 `PARZ` · 2 `PLAN` · 5 `N/A`
(29 applicabili). Aree calde attuali: **8.24** (cifratura del vault a riposo +
TLS inter-container), **8.9/8.32** (drift della configurazione), **8.29/8.8**
(test e scanning delle vulnerabilità fuori dalla CI).

---

## Segnalare una vulnerabilità

Se individui una vulnerabilità, **non aprire una issue pubblica**. Scrivi in
privato a **Davide Carboni — dcarboni@gmail.com** con una descrizione del
problema e i passi per riprodurlo. Faremo del nostro meglio per rispondere, ma —
coerentemente con la clausola as-is qui sopra — **nessun SLA di risposta o di
remediation è garantito**.
