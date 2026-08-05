# Installare un'istanza su macOS (Apple Silicon)

Percorso **validato** su un Mac mini M1 (macOS 14.5, 8 GB) il 5 agosto 2026:
build nativo arm64, 332 test della suite del gateway verdi dentro l'immagine, con
le sole 3 rotture preesistenti anche su x86 — **nessun fallimento di
architettura**.

La piattaforma assume un host Linux. Su un Mac ci si arriva con una VM, e la
scelta della VM è meno importante di due dettagli che seguono.

## Runtime container

**Colima** (Apache-2.0) è la scelta consigliata per una macchina amministrata da
remoto: è nativamente da riga di comando, e la VM che crea è un Linux normale in
cui uid mappati, `root:root 700` e `setpriv` si comportano come su un host Linux
vero — cioè le difese della piattaforma valgono quello che dichiarano.

Si installa **senza privilegi di amministratore e senza Homebrew**, dai binari di
release in `~/bin`: `colima`, `limactl` (con il suo `share/lima` accanto) e il
client `docker` standalone. Con `--vm-type vz` usa Virtualization.framework e non
serve QEMU.

```bash
colima start --vm-type vz --cpu 6 --memory 5 --disk 60 --mount-type virtiofs
```

**OrbStack** è più veloce sull'I/O dei volumi e più comodo da GUI, ma richiede una
licenza per uso commerciale: sceglierlo è legittimo, ma va deciso, non ereditato.

**Budget di memoria.** Su un Mac la VM è annidata: macOS + VM + stack condividono
la stessa RAM. Misurato su 8 GB con la sola VM accesa (5 GB assegnati): a macOS
restavano 0,1 GB liberi più 3,5 GB inattivi riciclabili, swap a zero. Dentro la VM
4,4 GB disponibili — che sono il budget **totale** dell'istanza, subprocess degli
agenti compresi. Su 8 GB: topologia ridotta (si può omettere la `pwa`) e
`multi_spawn` spento in partenza.

## Due dettagli che costano tempo se si scoprono dopo

### 1. La datadir non va in una cartella del Mac

Con un mount virtiofs i permessi sono **asimmetrici**. Misurato:

```
dentro la VM:  drwx------ root root   → un uid di spawn è negato dal kernel ✓
dall'host:     -rw-r--r-- <utente>    → `cat` legge il contenuto            ✗
```

Quindi la vault dell'istanza (provider, token, chiavi) sarebbe leggibile da
chiunque abbia una shell sul Mac. Usa un percorso **interno alla VM**:

```
CLODIA_DATA=/var/clodia-data
CLODIA_GATEWAY_STATE=/var/clodia-gateway-state
```

Colima monta soltanto la home dell'utente, quindi `/var/...` è nel disco della VM
e da macOS **non esiste**. Conseguenza da accettare: il backup diventa il disco
della VM invece di una cartella sfogliabile — il job `restic` gira comunque dentro
il container, quindi non cambia nulla di sostanziale.

### 2. Login remoto: macOS ha una lista a parte

Su macOS non basta `authorized_keys`: l'utente deve appartenere al gruppo di
controllo accessi, altrimenti sshd **accetta la chiave e poi chiude la sessione** —
un sintomo che non assomiglia a un problema di autorizzazione.

```bash
dseditgroup -o checkmember -m <utente> com.apple.access_ssh   # verifica
sudo dseditgroup -o edit -a <utente> -t user com.apple.access_ssh
```

## Avvio automatico

Una VM avviata a mano non sopravvive a un riavvio. I runtime container su macOS
appartengono a una **sessione utente**, quindi l'avvio al boot richiede l'auto-login
(un LaunchAgent utente parte al login, non al boot). Con FileVault attivo questo è
in tensione: un Mac headless che si sblocca da sé è un disco non protetto a riposo,
e senza auto-login un riavvio imprevisto resta alla schermata di pre-boot — che su
una macchina senza tastiera significa un intervento fisico.

Non c'è una risposta giusta in astratto: dipende da dove sta la macchina. Va scelto
e scritto, perché è una decisione che un domani va motivata.

**Il test che chiude la questione**, qualunque runtime si scelga: si riavvia la
macchina e **non si fa login**. Se lo stack torna su e risponde, va bene per la
produzione; se serve sbloccare il Mac, va bene per lo sviluppo.
