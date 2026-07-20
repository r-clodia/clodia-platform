# M3 — Sandbox keyless del runtime agente

> Spec tecnico. Chiude il gap #1 di [architecture.md](architecture.md): il
> subprocess SDK dell'agente gira oggi come **root**, nella stessa datadir che
> contiene chiavi/segreti/stato-gateway → con `bash` bypassa tutto l'RBAC.
> Obiettivo: rendere il filesystem dell'agente un `/proc`-like — **solo lo spawn**.

## Principio (una riga)
Non si limita cosa l'agente *può fare* col filesystem — **si toglie il filesystem**.
Bash resta pure disponibile: se il container non monta né `secrets`, né `vault`,
né lo stato-gateway, né le chiavi, allora `cat`/`python3`/`curl` non hanno nulla
di sensibile da raggiungere. La sicurezza non dipende più da una denylist di
comandi (aggirabile) ma dall'**assenza** dei dati nel perimetro.

## Perché non basta stringere i tool SDK (interim vs robusto)
- **Interim (debole)**: settare `allowed_tools` = solo `mcp__clodia-tools__*` (niente
  Bash/Read/Write built-in). L'agente può solo chiamare verbi gateway. **Ma**:
  (a) dipende dalla copertura tool completa (skill che fanno shell si rompono);
  (b) il filesystem resta montato → una singola misconfig che riabilita un tool
  fs re-espone tutto. È un confine a livello applicativo (SDK), non di sistema.
- **Robusto (questo M3)**: il filesystem sensibile **non è montato**. Vale anche
  se un domani un tool fs viene riabilitato o una skill prova a shellare: non c'è
  nulla da leggere. **Non dipende** dalla copertura tool. È il confine giusto.

Si possono combinare (SDK-tighten + sandbox), ma la sandbox è quella che conta.

## Runtime: runc-hardened ora, gVisor come upgrade
Il workload è **untrusted by design** (bash generato dall'LLM + skill/pack di
terze parti) → filosoficamente è il caso d'uso di **gVisor** (kernel user-space,
difesa dall'escape). Ma sul minipc `marte` (4c/8GB) il 99% del guadagno viene dal
**non montare i segreti + non-root + egress controllato**, che si ottiene con
**runc** standard + hardening, a costo quasi zero.

**Decisione**: partire con **runc-hardened** (containment immediato, nessuna
dipendenza aggiuntiva). Documentare **gVisor** (`runsc`) come upgrade quando si
esegue codice di terze parti su larga scala / multi-tenant (difesa dall'escape
del kernel). Su un box condiviso singolo il delta di gVisor non giustifica ora
l'overhead; lo si attiva cambiando il `runtime` del container, senza riscrivere.

## Il modello di lancio
Oggi: l'agent-server (FastAPI) **è** il container che ospita il subprocess `claude`
/`codex`. Target: l'agent-server resta l'**orchestrator trusted** (monta la
datadir, conia i token, scheduler, API), ma **non esegue più il subprocess al suo
interno**. Lo lancia in un **container-runtime sandbox effimero per-spawn**.

```
┌─ orchestrator (trusted) ──────────────┐        ┌─ gateway (trusted) ─┐
│ agent-server: spawn mgmt, MINT token, │        │ PDP + tool exec +   │
│ scheduler, API. Monta /datadir.        │        │ vault. Monta secrets│
│                                        │        └─────────▲───────────┘
│  per ogni turno/sessione:              │                  │ MCP (ckt1 iniettato)
│   1. materializza spawns/<id>/         │        ┌─────────┴───────────┐
│   2. conia ckt1 (TTL sessione)         │        │ SANDBOX per-spawn    │
│   3. lancia il subprocess in sandbox ──┼───────▶│ - rootfs minimale    │
└────────────────────────────────────────┘        │ - mount: SOLO        │
                                                   │   spawns/<id> (rw)   │
                                                   │ - user: NON-root     │
                                                   │ - env: ckt1 + SDK    │
                                                   │   home effimera      │
                                                   │ - egress: SOLO gw    │
                                                   └──────────────────────┘
```

### Cosa monta il sandbox
| Path | Modo | Note |
|---|---|---|
| `spawns/<id>/` | rw | l'unico bind-mount: il `/proc` dell'agente (scratch, skill materializzate, cwd) |
| **niente** `secrets`/`clodia-vault`/`pki`/stato-gateway/`agents`/`topics` | — | irraggiungibili: non montati |

### Identità e credenziali (keyless)
- **ckt1 token**: coniato dall'orchestrator, passato via **env/`mcp_servers` header** al subprocess (già così oggi, in-memory). Il subprocess **non ha la CA key** → non può coniarne altri.
- **SDK home** (`claude-home`/`codex-home`, con l'`auth.json` del provider): materializzata **effimera** dentro `spawns/<id>/.home` per la durata della sessione, poi distrutta. Non è un mount della datadir.

### Rete (egress)
Il sandbox può raggiungere **solo** il gateway (MCP HTTP). Nessun accesso a
Internet o alla LAN se non mediato da un tool gateway. Realizzabile con una
**network docker dedicata** agente↔gateway (niente default bridge verso l'esterno),
o regole egress. Così `curl` da bash non esfiltra e non raggiunge endpoint interni
diversi dal gateway (che comunque applica l'RBAC).

### Utente
Il subprocess gira come **uid non privilegiato** (non root). Anche i pochi file
montati (lo spawn) sono di sua proprietà; nient'altro è accessibile.

## Cosa cambia per l'agente
- **Invariato**: parla col gateway via MCP (topic.*, email.*, memory.*, …) — stessa UX.
- **Bash**: resta, ma vede solo lo spawn → utile per computazione locale (render, manipolazione file nel proprio scratch), **inutile per bypassare** (niente segreti/dati montati).
- **Skill che shellavano i vecchi CLI dei tool**: già vietate; usano gli MCP equivalenti (dove esistono — vedi gap copertura in architecture.md).

## Migrazione (incrementale, non-breaking)
1. **Volume split**: separare la datadir in (a) `secrets`+`vault`+`pki`+stato-gateway (montati solo da gateway/minter) e (b) resto. L'orchestrator resta trusted.
2. **Launcher sandbox**: introdurre il lancio del subprocess in container/runtime isolato con il solo bind-mount dello spawn. Rollout **per-kind**: prima gli agenti confinati (responder di topic), poi clodia/ophelia.
3. **SDK home effimera** + **egress network** dedicata.
4. **gVisor** (opzionale): `runtime: runsc` sul container sandbox quando serve difesa dall'escape.

Ogni passo è verificabile: dopo (1)+(2), `bash` in un agente sandbox su `ls /datadir/secrets` → *No such file or directory* (non "permission denied": proprio **assente**).

## Criterio di accettazione
Un agente sandboxato, istruito a fare `cat /datadir/secrets/ca/ca.key` via bash,
**non trova il file**; e una `curl` verso un endpoint non-gateway **fallisce**.
A quel punto tutto l'RBAC del gateway (M-sudo, M-authz, owner-check) diventa un
**confine reale**, non una convenzione.
