-- contacts.db schema — estratto da DB live, aggiunto IF NOT EXISTS dove mancava
-- Applicato da docker/init-datadir.sh su ogni nuova istanza Clodia.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS contacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome_completo TEXT NOT NULL,
    azienda TEXT,
    email TEXT,
    tel_contatto TEXT,
    contatto_2 TEXT,
    channel TEXT,
    contact_level TEXT DEFAULT 'none',
    intent TEXT DEFAULT 'unknown',
    ultimo_update TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    rubrica_id TEXT,
    nome TEXT,
    cognome TEXT,
    tipo TEXT DEFAULT 'persona',
    ruolo TEXT,
    relazione TEXT,
    partita_iva TEXT,
    codice_fiscale TEXT,
    pec TEXT,
    fonte TEXT DEFAULT 'crm',
    data_inserimento TEXT,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE SET NULL,
    UNIQUE(rubrica_id)
);

CREATE TABLE IF NOT EXISTS organizations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ragione_sociale TEXT NOT NULL,
    partita_iva TEXT,
    codice_fiscale TEXT,
    forma_giuridica TEXT,
    sede_legale TEXT,
    pec TEXT,
    codice_sdi TEXT,
    email TEXT,
    telefono TEXT,
    sito_web TEXT,
    referente_contact_id INTEGER,
    tipo TEXT DEFAULT 'cliente',
    tags TEXT,
    note TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (referente_contact_id) REFERENCES contacts(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS updates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    contact_id INTEGER NOT NULL,
    update_text TEXT NOT NULL,
    date TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS contact_emails (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    indirizzo  TEXT NOT NULL,
    tipo       TEXT DEFAULT 'lavoro',
    is_primary INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS contact_phones (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    numero     TEXT NOT NULL,
    tipo       TEXT DEFAULT 'mobile',
    is_primary INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS contact_addresses (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    via        TEXT,
    cap        TEXT,
    comune     TEXT,
    paese      TEXT DEFAULT 'IT'
);

CREATE TABLE IF NOT EXISTS contact_extra (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    key        TEXT NOT NULL,
    value      TEXT
);

-- Indici
CREATE INDEX IF NOT EXISTS idx_contacts_level          ON contacts(contact_level);
CREATE INDEX IF NOT EXISTS idx_contacts_email          ON contacts(email);
CREATE INDEX IF NOT EXISTS idx_contacts_intent         ON contacts(intent);
CREATE INDEX IF NOT EXISTS idx_contacts_azienda        ON contacts(azienda);
CREATE INDEX IF NOT EXISTS idx_contacts_ultimo_update  ON contacts(ultimo_update DESC);
CREATE INDEX IF NOT EXISTS idx_contacts_rubrica_id     ON contacts(rubrica_id) WHERE rubrica_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_fonte          ON contacts(fonte);
CREATE INDEX IF NOT EXISTS idx_contacts_organization   ON contacts(organization_id);
CREATE INDEX IF NOT EXISTS idx_updates_contact_id      ON updates(contact_id);
CREATE INDEX IF NOT EXISTS idx_updates_date            ON updates(date DESC);
CREATE INDEX IF NOT EXISTS idx_cemails_contact         ON contact_emails(contact_id);
CREATE INDEX IF NOT EXISTS idx_cemails_indirizzo       ON contact_emails(LOWER(indirizzo));
CREATE INDEX IF NOT EXISTS idx_cphones_contact         ON contact_phones(contact_id);
CREATE INDEX IF NOT EXISTS idx_caddr_contact           ON contact_addresses(contact_id);
CREATE INDEX IF NOT EXISTS idx_cextra_contact          ON contact_extra(contact_id);
CREATE INDEX IF NOT EXISTS idx_cextra_key              ON contact_extra(key);
CREATE INDEX IF NOT EXISTS idx_org_partita_iva         ON organizations(partita_iva);
CREATE INDEX IF NOT EXISTS idx_org_referente           ON organizations(referente_contact_id);
CREATE INDEX IF NOT EXISTS idx_org_ragione_sociale     ON organizations(ragione_sociale);

-- Trigger aggiornamento timestamp
CREATE TRIGGER IF NOT EXISTS update_contacts_timestamp
AFTER UPDATE ON contacts FOR EACH ROW
BEGIN
    UPDATE contacts SET updated_at = datetime('now') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS update_organizations_timestamp
AFTER UPDATE ON organizations FOR EACH ROW
BEGIN
    UPDATE organizations SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Viste
CREATE VIEW IF NOT EXISTS active_contacts AS
SELECT * FROM contacts
WHERE task IN ('agire', 'in attesa', 'posticipato', 'attenzionare')
ORDER BY ultimo_update DESC;

CREATE VIEW IF NOT EXISTS contacts_with_latest_update AS
SELECT
    c.*,
    (SELECT update_text FROM updates WHERE contact_id = c.id ORDER BY date DESC LIMIT 1) as latest_update_text,
    (SELECT date FROM updates WHERE contact_id = c.id ORDER BY date DESC LIMIT 1) as latest_update_date
FROM contacts c;

CREATE VIEW IF NOT EXISTS contact_update_counts AS
SELECT c.id, c.nome_completo, c.azienda, COUNT(u.id) as update_count
FROM contacts c
LEFT JOIN updates u ON c.id = u.contact_id
GROUP BY c.id;
