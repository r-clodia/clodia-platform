# Licensing — Clodia Platform

## The model: dual licensing

This repository is part of **Clodia Platform** and is distributed under two
licences:

1. **GNU AGPL v3** (see `LICENSE`) — for the community: you may use, study,
   modify and redistribute the code. If you offer a modified version as a
   network service, you must make the source of your modifications available to
   the users of that service (AGPL art. 13).
2. **Commercial licence** — for those who cannot or do not wish to accept the
   AGPL terms (use inside proprietary products or services, corporate policies
   that exclude the AGPL, custom editions without a publication obligation).
   Contact: **Davide Carboni** — dcarboni@gmail.com.

## The version boundary

- Releases published **up to and including the `apache2-final` tag** remain
  available under the **Apache License 2.0** (irrevocably, for those releases).
- Every release **after** that tag is under **AGPL v3** (or a commercial
  licence).

## Packs, skills, agent seeds and MCP servers are NOT derivative works

Stated plainly, for anyone building on top of the platform:

- **packs** — skills in Markdown, rules, agent-seed YAML, templates — are
  **content the platform loads**, not derived code: they may carry any licence,
  including a proprietary one;
- **MCP servers** mounted on the gateway run as **separate processes** speaking
  a protocol (the Model Context Protocol): they do not constitute a derivative
  work of the platform;
- terraformed **editions** (blueprints, profiles, branding) are the customer's
  configuration and the customer's property.

The AGPL obligation concerns **modifications to the platform's code** offered
over a network, not the content that runs on it.

## Outside contributions

Contributions are welcome, subject to a **CLA** (Contributor License Agreement)
granting the project owner the right to relicense the contribution — which is
what makes the dual licensing possible. Please open an issue before a
substantial pull request.

---
Copyright (C) 2026 Davide Carboni
