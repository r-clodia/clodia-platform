# Writing a connector for a pack

This guide is for the author of a **pack** who wants it to bring a connector: a
card on the Tools page with a «Connetti» button, a button on the topic page, and
verbs that the gateway checks like its own. It covers what to write in
`pack.yaml`, where the code runs, the rules the gateway enforces, and how to test
the result on an instance.

The complete grammar is
[`server/connectors/SCHEMA.md`](https://github.com/r-clodia/clodia-tools/blob/main/server/connectors/SCHEMA.md)
in clodia-tools; the parser is `server/connectors/manifest.py` next to it. This
guide does not repeat every field: when it says "see SCHEMA.md", the details are
there.

One principle runs through all of it: **a manifest declares, it never grants.**
The pack says what the connector is — its address formats, which argument of
which verb is a destination, which button it adds. Whether an agent may reach a
given address is still decided by the owner, at the gate, and by the egress and
ingress lists of the instance and of each topic.

## 1. What a connector is

A connector is an entry of a top-level `connectors:` list in `pack.yaml`, next
to `plugins:` and `agents:`. The agent-server copies the block into the
installed manifest (`<datadir>/packs/<pack>/pack.yaml`), the gateway builds its
connector registry from those files, and the webui draws the Tools card and the
topic buttons from that registry. Nothing in the webui or the gateway names
your connector.

```yaml
name: sms-demo-pack
connectors:
  - id: sms-demo            # unique on the instance, [a-z][a-z0-9-]*
    manifest_version: 1     # a higher number is refused, not guessed at
    namespace: sms          # the verb namespace the pack owns, [a-z][a-z0-9_]*
    label: SMS (demo)       # shown in the UI; defaults to the id
    schemes:
      - scheme: sms
        direction: egress
        forms:
          - label: phone number
            pattern: '^\+[0-9]{6,15}$'
            example: '+393331234567'
```

A connector must declare at least one of `schemes`, `verbs`, `providers`,
`taint`, `unmapped`, or `extends`; an empty one is refused. SCHEMA.md («Two
kinds of connector») describes the useful shapes: a **vocabulary owner**
(declares schemes), a **contributor** (`extends:` plus providers only), a
**credential-only** connector (just a provider), and a **verb- or taint-only**
connector that maps its own verbs onto a vocabulary someone else declares.

### `schemes`

A scheme is the vocabulary of addresses the connector speaks: `sms:+39…`.
`direction` is `egress` (somewhere the platform writes to), `source` (somewhere
it reads from) or `both`.

- `forms` lists the accepted shapes of the part after the colon. Patterns match
  with `fullmatch`. An `example` that does not match its own pattern is an
  error.
- A pack's regular expressions must stay inside a **safe subset**: at most two
  quantified atoms with a maximum above one, at most two `?`, no quantified
  groups, at most one alternation of at most four alternatives, no
  back-references or lookarounds, at most 200 characters. A pack pattern is
  never applied to a value longer than 256 characters.
- `danger` is the sentence the owner reads on the gate card before granting an
  address of this scheme.
- Optional: `hierarchical`, `lowercase`, `wildcard`, `label`, `icon`,
  `canonicalise` (see SCHEMA.md).
- `http`, `https`, `topic` and `mcp` are platform schemes: a pack may point a
  verb at them but may not declare them.
- A scheme has exactly one owner on the instance. Declaring a scheme another
  installed pack already declares is refused.

### `providers`

A provider is an implementation with its credential. For a pack connector the
credential is `kind: form`: the owner fills in the declared fields at
«Connetti», and the gateway stores them in the declared vault entry.

```yaml
    providers:
      - id: gateway
        label: SMS gateway account
        credential:
          kind: form
          vault_entry: sms_api          # 'sms' or 'sms_<name>': inside the namespace
          fields:
            - name: api_key
              label: API key
              secret: true              # never echoed back
            - name: sender
              label: Sender name
              required: false           # fields are required by default
              placeholder: 'ACME'
```

A `form` credential with no fields is refused. `vault_entry` must be the
namespace itself or `<namespace>_<name>` (section 3).

`kind: oauth` (`authorize_url`, `token_url`, `scopes`) parses, but the generic
connect route does not handle it — an OAuth consent needs provider-specific
routes — so a third-party pack should use `kind: form`.

### `verbs`

A verb mapping tells the gateway's policy decision point (PDP) where a call
goes, or where a read comes from. This is what puts your verbs under the same
egress whitelist and gate as the gateway's own.

```yaml
    verbs:
      - verb: sms.send          # must start with '<namespace>.'
        direction: egress       # egress = a destination, source = a read
        scheme: sms
        arg: to                 # the argument the destination is read from
        multi: true             # the argument may carry several addresses
        dtype: sms              # the destination family shown at the gate
```

- The URI is `<scheme>:{value}` unless `template` says otherwise (it must use
  `{value}`).
- A verb may be mapped more than once (several arguments, or two schemes); all
  destinations of one call must be inside the perimeter. Two mappings of one
  verb may not disagree on `dtype`.
- A verb may point at a scheme that another connector declares, or at a
  platform scheme: using a vocabulary is not owning it. The scheme must exist on
  the instance, in the right direction.
- Other fields: `prefix`, `normalise`, `reads: result` (only for `source`). See
  SCHEMA.md.
- A verb with no egress mapping is not checked against the egress whitelist.
  Map every verb that sends something out.

### `taint`

A list of verb prefixes, inside the namespace, whose answers bring
uncontrolled third-party content into the conversation: a call to one of them
taints the channel.

```yaml
    taint:
      - sms.inbox
```

What the gateway does (`server/taint.py`): a verb taints if it has a
`direction: source` mapping, or matches a `taint:` prefix, or is served by a
mounted MCP backend and has no egress mapping. Use `taint:` for reads that mix
several authors in one answer, where there is no single source to vet.

### `unmapped`

Exact verb names of the namespace that deliberately have no destination and no
source the PDP reads. It changes no PDP answer. It matters for gateway
components (section 2), whose verbs are served only when the manifest
classifies them.

```yaml
    unmapped: [sms.status]
```

A verb may not be both mapped and listed here.

### `topic_actions`

A topic action is a button on the topic page. The owner fills in its fields and
the gateway writes the rendered URIs into **that topic's** ingress and egress
lists.

```yaml
    topic_actions:
      - id: sms-number
        label: Authorise a phone number
        fields:
          - name: number
            label: Phone number
            placeholder: '+39…'
        adds:
          egress:
            - 'sms:{number}'
```

- Every template must start with one of the connector's **own** schemes,
  written out (`sms:{number}`, never `{url}`), and that scheme must declare
  `forms`. A template naming a field the action does not declare is an error.
- At run time each value is canonicalised, checked against the scheme's forms
  and against the grantable rules of the egress lists before anything is
  written.
- Only the topic's owner or an admin may run an action; never an agent token.
  The page shows the buttons to the topic owner.
- `admin_only: true` offers the button only to an instance admin.
- `options` turns a field into a choice among values the **gateway** supplies.
  The list of option sets is closed (today: `mailboxes`, which also makes
  `{account}` and `{address}` available to the templates). A pack may point at
  an option set, never define one.
- `binding` has one value, `channel`: running the action also binds the topic
  to the chat named by the field. The bindings registry behind it is today the
  one the gateway keeps for Telegram chats (`connectors/actions.py`), so leave
  `binding` out unless your connector is that kind of chat channel.

### `tools_card`

Without `tools_card` a connector is a vocabulary and gets no card.

```yaml
    tools_card:
      setup_label: Paste an API key     # the label of the connect button
      blurb: Send text messages from the pack's verbs.
      scope: api.sms.example.org
      icon: generic                     # an unknown icon falls back to the generic glyph
      docs_url: https://example.org/docs/sms
```

`docs_url` must be an absolute `https://` URL with a host and no userinfo;
anything else is refused when the manifest is parsed. `status_verb` and
`test_verb` are also accepted (see SCHEMA.md).

### `context`, `defaults`, `files`

Three ways for the **gateway** to fill arguments of your verbs, because your
backend cannot be trusted to know them — and neither can the agent calling it.

```yaml
    context:                  # always overwritten by the gateway
      - arg: agent
        value: agent          # who is calling; 'channel' = the room of the call
    defaults:                 # filled only when the caller omitted the argument
      - verb: sms.send
        arg: to
        value: binding        # the chat bound to the calling topic
    files:                    # the gateway reads a topic file and passes bytes
      - verb: sms.send_mms
        path_arg: path
        bytes_arg: content_b64
        name_arg: filename
```

- `context` values are a closed list: `channel`, `agent`. They apply to every
  verb of the namespace. An argument that a verb mapping reads its destination
  from may not be a `context` argument.
- `defaults` has one value, `binding`, resolved through the bindings registry
  that `binding: channel` writes; an unresolvable default is an explained error.
- `files`: the gateway checks that the caller is a participant of the topic,
  records the crossing, and replaces the path arguments with the bytes. The
  backend never sees a path.
- All three must name verbs of the connector's own namespace, and a contributor
  (`extends`) may not declare them.

### `extends`

A contributor adds a provider to a vocabulary another connector owns. It may
declare only `providers` (with no `schemes`, `verbs`, `taint`, `topic_actions`,
`context`, `files` or `defaults`), and the connector it names must be installed
and must itself be a vocabulary owner.

```yaml
  - id: sms-demo-backup
    manifest_version: 1
    namespace: smsbackup
    label: SMS backup provider
    extends: sms-demo
    providers:
      - id: backup
        label: Backup SMS gateway
        credential:
          kind: form
          vault_entry: smsbackup_api
          fields:
            - name: api_key
              label: API key
              secret: true
```

### `services`

A connector may declare long-running processes that the gateway's supervisor
starts, each under its own OS user, with only its declared credentials, on
loopback only. The contract is in SCHEMA.md («`services[]`»).

## 2. Where the implementation runs

The manifest describes the connector. The code that serves its verbs runs in
one of two places.

### An MCP backend shipped by the pack

This is the path for a third-party pack. A plugin of the pack declares an MCP
server — `.mcp.json` (or `mcpServers` in `plugin.json`) for a Claude plugin,
`mcp_servers` in `plugin.yaml` for a Clodia plugin. Once the server is mounted
in the gateway, its tools are exposed as `<server>.<tool>`: a server named `sms`
serves `sms.send`. The connector's `namespace` is therefore the server's name,
and its verb mappings, taint and context apply to those tools.

Three things depend on the mount being **the pack's own**: when the agent-server
mounts a pack's server, the gateway records the pack's name on the mount
(`pack:`), and only that record proves ownership.

- **Namespace.** A connector whose namespace is a mounted MCP backend that does
  not belong to its pack is refused at runtime.
- **Credential.** A pack's backend may reference the vault entries its own
  connectors declare, with `${VAULT:<entry>.<field>}` in its `env`, `args`,
  `headers` or `url`, for example `${VAULT:sms_api.api_key}`. A backend that
  references any other entry is refused when the session opens. A backend
  without a pack record reads only its own entries (`mcp_<server>_*`,
  `mcp_cred_<server>`, `mcp_oauth_<server>`).
- **Grants.** A mounted backend is granted to no agent. An agent gets its verbs
  by declaring them in its seed's `agent.yaml`.

When the agent-server mounts a pack's servers depends on the source: an Update
of a pack from an `r-clodia/*` upstream mounts them; an import from any other
source does not start any process and reports the servers as `pending`
(`mcp_mount.pending` in the import answer), for the owner to review. See
`catalogs/PACKS.md` in clodia-logic.

> **Known limitation.** The Tools page's «Add MCP» mounts a server without a
> pack record. A third-party pack's server mounted that way belongs to no pack:
> its connector, in the same namespace, is then refused, and the server cannot
> read the connector's credential. The connector's card and topic button do not
> depend on a backend (section 5), but its verbs do. Tracked in
> [clodia-platform#573](https://github.com/r-clodia/clodia-platform/issues/573).

### A gateway component (first-party only)

A pack may also ship code that the **gateway** fetches, pins by commit, and
imports in its own process: a `components:` entry with `target: gateway`. This
is how google-pack and comms-pack implement their verbs.

```yaml
first_party: true
components:
  - id: gateway
    target: gateway
    source:
      repo: r-clodia/clodia-logic
      path: catalogs/packs/weather-pack/gateway
      ref: main
    entry: weather_component      # module defining register(host)
    connectors: [weather]         # connectors of this pack it implements
    credentials: [weather_]       # vault prefixes or entries it may use
```

A component runs with the gateway's privileges, and nothing in its host API is
a sandbox. The boundary is where the code comes from, so **gateway components
are first-party only**:

- the pack must be listed in `connectors.builtin.FIRST_PARTY_SOURCES`, a table
  in gateway code mapping each pack to its repository and directory;
  `source.repo` must equal that repository and `source.path` must lie under
  that directory;
- the manifest must say `first_party: true` (necessary, not sufficient);
- the repository's organisation must be in the allowed list (default
  `r-clodia`);
- `source.ref` must be the default branch; the pin moves only on an admin's
  refresh, and never to an older commit unless the admin explicitly allows a
  downgrade.

Any other component is refused: `GET /internal/components` shows it with status
`refused` and a reason ending in «(third-party gateway components are
refused)». There is no approval path for third-party components today.

For first-party authors: the component's `register(host)` uses the host API
(`server/components/host.py`):

- `host.register_verb(tool, handler)` adds a verb, only in the namespaces of the
  connectors listed in `connectors:`; it then runs through the same checks as a
  native verb (whitelist, gates, the egress PDP and taint from the pack's
  mappings, audit). A component verb that the pinned manifest does not classify
  — by a mapping, a taint prefix or `unmapped` — is denied.
- `host.register_route(path, methods, handler, auth="owner")` mounts a route at
  `/tools/<pack>/<path>`. Both `owner` and `admin` require a human admin; there
  is no public route; every call is audited.
- `host.register_service(name, handler)` registers a callable that the
  gateway's own code calls by a fixed name; no agent reaches it.
- `host.credentials(prefix)` gives scoped access to the declared credentials.

Registration closes when `register` returns. After a pack Update, a human admin
moves the pin with `POST /internal/components/<pack>/refresh`. SCHEMA.md
(«Components») has the full contract.

## 3. The namespace rule

A pack declares verbs and credentials **only in its own namespace**. Without
this, a pack could map someone else's verb (`email.send`) as a harmless read and
walk past the egress check, or have a form write over another connector's
credential. The rule is applied when a manifest is validated and again at call
time.

What is refused, with the message the author sees (`P` is the pack, `C` the
connector, `N` the namespace):

| Declaration | Message |
|---|---|
| A namespace the gateway or another installed pack owns, or a reserved core stem (`google`, `gmail`, `telegram`, `github`, `mailbox`, `openai`, `provider`, `mcp`, `app`, …) | `pack 'P', connector 'C': namespace 'N' is already taken; a pack cannot claim a namespace that is not its own` |
| A verb in `verbs`, `unmapped`, `defaults` or `files` outside `N.` | `pack 'P', connector 'C': verb 'V' is outside namespace 'N'. A pack may map only verbs it owns: …` |
| A `taint` prefix outside `N.` | `pack 'P', connector 'C': taint prefix 'T' is outside namespace 'N'. …` |
| A `vault_entry` that is not `N` or `N_<name>` | `pack 'P', connector 'C'.providers 'X': vault entry 'E' is outside namespace 'N': a connector stores its credential as 'N' or 'N_<name>'` |
| A `vault_entry` with a core prefix (`app_`, `backup_`, `github_`, `gmail_`, `google_`, `gworkspace_`, `mailbox_`, `mcp_`, `openai_`, `profile_`, `provider_`, `scope_`, `telegram_`) | `… vault entry 'E' is a core credential name ('github_…'), which a pack cannot write` |
| A namespace that is a `_`-prefix of a gateway namespace (`foo` when the gateway owns `foo_bar`) | `pack 'P', connector 'C': namespace 'N' is a prefix of the gateway's namespace '…', so its vault entries would overlap; choose a namespace that is not` |
| A scheme another pack declares | `scheme 'S' is declared by both 'P1' (connector 'C1') and 'P2' (connector 'C2'); a scheme vocabulary has exactly one owner` |
| A platform scheme in `schemes` | `pack 'P', connector 'C': scheme 'https' is platform-intrinsic and stays in the core manifest; …` |

A refusal applies to the whole `connectors:` block: a connector accepted minus
the mapping that failed would be a connector whose verbs go unchecked. At
install time it stops the import.

A connector whose namespace, id or scheme belongs to a connector the gateway
itself declares is not an error: it is reported in `ignored`, with the reason,
and stays inactive.

One refusal happens only at runtime, because it depends on what is mounted: a
namespace that is a mounted MCP backend not belonging to the pack (section 2).
It is listed in `problems` and `ignored` of `GET /internal/connectors` (also
served at `GET /tools/connectors`), and only that connector is dropped.

## 4. What the owner sees

**Tools card.** Every installed connector with a `tools_card` gets a card:
`label` as the title, `blurb`, `scope`, `icon`, and the documentation link. A
connector with a `form` provider is connectable from the card; one with neither
a credential nor an option set shows a disabled button.

**«Connetti».** The button (labelled with `setup_label`) opens a form with the
provider's declared fields. Submitting posts to
`POST /tools/connectors/<id>/connect`; the gateway writes the declared fields —
and only those — into the declared vault entry, as an infrastructure credential
with no per-agent grant. The answer says that something is stored, never what.
Submitting all fields empty disconnects. The credential is asked for at
connect time; a pack never carries it, and the registry exposes only the vault
entry's name and whether something is stored under it.

**Topic buttons.** On a topic page, in the «Egress/Ingress» section, the topic
owner sees one button per `topic_actions` entry of every installed connector
(`admin_only` ones only for an admin). The entries the action writes appear in
that section's lists.

**Which connectors an edition shows.** The instance profile
(`<datadir>/profile.yaml`) may restrict the connectors to a list of ids:

```yaml
integrations:
  connectors: [sms-demo]
```

Absent, every installed connector is shown; an empty list shows none. A
connector outside the list is left out of `GET /internal/connectors` — no card,
no topic button — and its connect route answers 403. A clodia-build blueprint
writes this key from its own `integrations.connectors`.

## 5. Testing

### Validate a manifest

The gateway answers whether a `connectors:` block would be accepted on this
instance, without writing anything:

```
POST /internal/connectors/validate
Authorization: Bearer <human admin session token>
Content-Type: application/json

{"pack": "sms-demo-pack", "connectors": [ … the connectors: list, as JSON … ]}
```

The answer:

```json
{"ok": true, "pack": "sms-demo-pack", "errors": [], "ignored": [],
 "connectors": [{"id": "sms-demo", "label": "SMS (demo)", "namespace": "sms",
                 "schemes": […], "providers": […], "verbs": […],
                 "topic_actions": […], "tools_card": {…}, "taint": […], …}]}
```

- `ok: false` comes with one message in `errors`: the first refusal, which is
  the one to fix.
- `ignored` lists declarations that are well formed but inactive on this
  instance, with the reason; they do not make `ok` false.
- `connectors` is the same summary the Tools page reads.
- The candidate replaces an installed pack of the same name, so re-validating
  an installed pack is not a clash with itself.
- `401 {"error": "unauthorized"}` without an admin token;
  `400 {"error": "bad_json"}` for a body that is not JSON.

`/internal/` is not proxied by the webui: call the gateway directly (port 7849
on the host with the default `docker-compose.yml`). From a `pack.yaml`:

```bash
python3 -c 'import json, yaml; m = yaml.safe_load(open("pack.yaml"));
print(json.dumps({"pack": m["name"], "connectors": m["connectors"]}))' |
curl -sS -X POST http://127.0.0.1:7849/internal/connectors/validate \
     -H "Authorization: Bearer $ADMIN_TOKEN" \
     -H 'Content-Type: application/json' --data @-
```

The agent-server makes the same call when a pack is imported: a negative verdict
— or a gateway that cannot answer — refuses the import with the gateway's
message, and nothing is installed. The `ignored` lines come back in the import
answer's `warnings`.

### A minimal test pack

The card and the topic button come from the manifest alone, so a test pack needs
no backend. The agent-server refuses an empty pack, so it carries one plugin
with one skill:

```
sms-demo-pack/
├── pack.yaml
└── plugins/
    └── sms-demo/
        └── skills/
            └── sms-demo-howto/
                └── SKILL.md
```

`SKILL.md` can be a few lines:

```markdown
---
name: sms-demo-howto
description: Explains the SMS demo connector.
---
The SMS demo connector is a test fixture: it declares a card and a topic button.
```

`pack.yaml`:

```yaml
name: sms-demo-pack
description: Test fixture for a pack connector (card and topic button).
version: 0.1.0
plugins:
  - sms-demo
connectors:
  - id: sms-demo
    manifest_version: 1
    namespace: sms
    label: SMS (demo)
    schemes:
      - scheme: sms
        direction: egress
        label: Phone number
        danger: >-
          a phone number: a text message cannot be recalled once it is sent.
        forms:
          - label: phone number
            pattern: '^\+[0-9]{6,15}$'
            example: '+393331234567'
    providers:
      - id: gateway
        label: SMS gateway account
        credential:
          kind: form
          vault_entry: sms_api
          fields:
            - name: api_key
              label: API key
              secret: true
    verbs:
      - verb: sms.send
        direction: egress
        scheme: sms
        arg: to
        multi: true
        dtype: sms
    taint:
      - sms.inbox
    topic_actions:
      - id: sms-number
        label: Authorise a phone number
        fields:
          - name: number
            label: Phone number
            placeholder: '+39…'
        adds:
          egress:
            - 'sms:{number}'
    tools_card:
      setup_label: Paste an API key
      blurb: Test connector. Sends nothing; it exists to check the card and the button.
      scope: api.sms.example.org
      icon: generic
```

The verb mapping is inert until something serves `sms.*`; it is there so the
validation also exercises a mapping.

### Check that it appears

1. Validate the block as above: expect `"ok": true` and one connector.
2. Import the pack from the Packs page (a zip of `sms-demo-pack/`). The answer
   lists `connectors.declared: ["sms-demo"]`.
3. `GET /tools/connectors` (admin): `sms-demo` is in `connectors`, with
   `providers[0].connected: false`. If it is missing, read `problems` and
   `ignored` in the same answer, and check `integrations.connectors` in the
   profile.
4. Tools page: the «SMS (demo)» card, with a «Paste an API key» button. Fill in
   a value and submit: the card turns connected, and `GET /tools/connectors`
   shows `connected: true` for the provider.
5. Open a topic you own, expand «Egress/Ingress»: the «Authorise a phone
   number» button is there. Enter `+393331234567`: `sms:+393331234567` appears
   among the topic's egress entries. A value that does not match the form, such
   as `12345`, is refused.

Removing the pack (Packs page) removes its connector from the registry, and the
card and button with it.

## 6. First-party packs on a fresh instance

`base-pack`, `comms-pack` and `google-pack` are bundled with clodia-logic in
`catalogs/packs/`, and clodia-logic's `docker/init-datadir.sh` registers their
manifests in `<datadir>/packs/` on a new datadir. comms-pack (mail, Telegram)
and google-pack (Drive, Sheets, Docs, Calendar, Gmail) declare their connectors
in `connectors:` and implement them with gateway components; their `pack.yaml`
files are real, reviewed examples of the grammar.

it-pack (GitHub, OpenAI Images) is not bundled with the public build; an
instance gets it by importing it (clodia-build blueprint `packs:`).
