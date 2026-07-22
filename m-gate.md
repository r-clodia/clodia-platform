# M-gate — supervisione umana sui verbi sensibili (sostituisce M-sudo)

**Stato**: spec (22 lug 2026). Rimpiazza il modello *sudo* (SUDOERS/APPROVERS/
super-only prefix) con un modello a **gate** più generale e senza escalation.

## Principio

Alcuni verbi/tool sono **gated**: ogni loro esecuzione richiede una **conferma
umana esplicita**, *chiunque* la inneschi (agente o umano). Il gate **non
concede** capacità nuove — è un **checkpoint di supervisione** su azioni **già
permesse** dalla RBAC. Chi non è autorizzato a un verbo resta semplicemente
negato (nessun gate, nessuna escalation).

Corollario di delega: chi approva un gate presta la **propria** autorità, quindi
può approvare **solo i verbi per cui la sua RBAC lo autorizza**. Owner → qualunque
verbo; un utente normale (es. giovanni) → solo il sottoinsieme che il suo ruolo
aziona (≡ "i verbi della sua UI"). *Non puoi delegare ciò che non hai.*

## Due assi ortogonali (entrambi già presenti)

1. **RBAC** (M-authz, gateway = PDP): il verbo è permesso al principal/ruolo?
2. **Gate** (nuovo): il verbo è in `gated_verbs`? Se sì → serve conferma umana.

`autorizzato = RBAC(verbo, chi) == allow`. `richiede_gate = verbo ∈ gated_verbs`.
Esecuzione consentita ⇔ `autorizzato AND (not richiede_gate OR consenso_valido)`.

## Attori e flusso

- **Umano che aziona un verbo gated dalla propria UI**: è l'autorità, ma vede
  comunque un **popup di conferma** (anche l'owner). Autorizzato dalla RBAC →
  procede su conferma; non autorizzato → bloccato (niente auto-grant).
- **Agente che tenta un verbo gated** (che ha già nei suoi grant): parte una
  **richiesta di gate**; approva lo **user loggato nel contesto** dell'azione
  (la chat del topic o il DM in cui l'agente opera), purché la sua RBAC copra il
  verbo. L'approvazione conia una **capability time-boxed** (`ccap1`, firmata
  dalla CA, revocabile via `jti`) con cui l'agente completa quella singola azione.

## Sincrono vs asincrono

- **Sync** (sessione interattiva webui/pwa): **popup** nel contesto → Approva/Rifiuta.
- **Async** (verbo gated dentro un **job/workflow**, nessun umano in linea):
  **Telegram** all'owner del contesto (job/topic) autorizzato al verbo, con un
  **link firmato one-time** a una pagina Approva/Rifiuta (riuso della route
  `/gate/` e del meccanismo di gate-link dei *job proposal*).
  - Fallback (utente senza contatto Telegram configurato): la richiesta resta in
    **coda** e compare come popup alla sua prossima sessione webui.

## `gated_verbs`

Insieme **configurabile** (env / profilo d'istanza). Default ≈ gli attuali
super-only: `packs.*`, `providers.*`, `mcp.*`, `agents.*`, `settings.*`,
`pki.*`, `ca.*`, + i `workflows.*` distruttivi (`start`/`cancel`/`delete`/
`terminate`). Estendibile senza toccare il codice.

## Cosa si rimuove (M-sudo)

- Gruppi `SUDOERS` e `APPROVERS`; i "super-only prefix" come concetto legato a un
  gruppo di agenti; la logica "sudoer chiede escalation → approver eleva".

## Cosa si riusa

- Capability `ccap1` firmata dalla CA (minting delegato al gateway, keyless).
- Popup approvazioni (oggi `SudoApprovals` → `GateApprovals`).
- Gate-link firmato one-time + route `/gate/` (dai job proposal) per l'async.
- Notifica Telegram (bot + chat_id per-umano).
- RBAC del gateway per calcolare "cosa può approvare l'approvatore".

## Modello dati (richiesta di gate)

`{ id, verb, args_digest, requested_by (agent|principal), context (tier/name|dm),
   principal_target (chi può approvare), mode (sync|async), status
   (pending|approved|denied|expired), created_at, decided_by, capability_jti }`

## Punti di enforcement

Il **gateway** (PDP unico) è dove il gate scatta: prima di eseguire un verbo
gated verifica (a) RBAC del richiedente, (b) presenza di un consenso valido
(capability `ccap1` per l'azione) — altrimenti apre una richiesta di gate e
sospende/rifiuta l'azione finché non arriva la decisione.
