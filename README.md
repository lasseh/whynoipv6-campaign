<br/>
<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/lasseh/whynoipv6/master/.github/images/Github-logo-white.png">
    <img alt="Shame!" src="https://raw.githubusercontent.com/lasseh/whynoipv6/master/.github/images/Github-logo-black.png" width="70%">
  </picture>
</div>
<br>
<div align="center">

[![Website](https://img.shields.io/website?url=https%3A%2F%2Fwhynoipv6.com)](https://whynoipv6.com/)
[![Campaigns](https://img.shields.io/badge/campaigns-whynoipv6.com-blue)](https://whynoipv6.com/campaigns)
[![Backend](https://img.shields.io/badge/backend-lasseh%2Fwhynoipv6-lightgrey?logo=github)](https://github.com/lasseh/whynoipv6)

</div>
<h1 align="center">Campaign lists</h1>
<div align="center">
The domains WhyNoIPv6.com tracks beyond the Tranco top 1M.
</div>

---

[whynoipv6.com](https://whynoipv6.com) crawls the Tranco top 1 million on its own.
This repo is everything else it watches, and it is open to pull requests.

| Path | What it is |
|---|---|
| `<Campaign_Name>.yml` (repo root) | A campaign — a named group of domains with its own page, stats and changelog |
| `subdomains/<apex>.yml` | Extra hosts to check under a domain that is already tracked |

Merged changes reach production on the next daily sync, and the domains in them
are crawled every 24 hours from there on.

## Add a campaign

One file at the repo root. Name it after the campaign, use `.yml`, and give it
these keys:

```yaml
title: Norwegian Political Parties
description: Official websites of Norway's political parties
domains:
  - arbeiderpartiet.no
  - frp.no
  - hoyre.no
```

That is the whole format. The full key list:

| Key | Required | Notes |
|---|---|---|
| `title` | yes | The campaign name on the site |
| `description` | yes | One line, shown under the title |
| `domains` | yes | Bare hostnames, up to 5000 per file |
| `tags` | no | Lowercase kebab-case, up to 16. The tag `mandate` is the only one with behaviour attached — it lists the campaign under [/mandates](https://whynoipv6.com/mandates) |
| `uuid` | no | Leave it out. UUIDs are assigned by the import bot; a hand-written one forks your campaign into a second entry |

What the importer rejects:

- Anything that is not a bare hostname. Write `example.com`, not
  `https://example.com/` or `example.com/login`. Non-ASCII names are fine and
  get converted to punycode.
- The same host twice in one file.
- More than 5000 entries.
- Unknown top-level keys.

One bad entry rejects the whole file, so a merged campaign is either fully
imported or not imported at all.

Two things that look like problems and are not: subdomains in a campaign list
(`api.example.com` is fine — its parent gets tracked automatically), and the
same host appearing in several campaigns. One domain can belong to many
campaigns and is still crawled once a day.

## Add a subdomain list

An apex and its `www` passing does not mean the service works over IPv6. Login
portals, APIs and checkout hosts live on subdomains that can be IPv4-only while
the homepage scores green. A subdomain list names those hosts so the crawler
checks them too.

```yaml
# subdomains/nrk.no.yml
subdomains:
  - tv
  - radio
  - secure.login
```

- The filename is the parent domain, lowercase, and must be a registrable apex —
  `nrk.no.yml`, not `www.nrk.no.yml` and not `no.yml`.
- Entries are labels **relative to that apex**, so write `tv`, not `tv.nrk.no`.
  Multi-level labels like `secure.login` work.
- `www` is rejected — the apex's own `www` check already covers it.
- Up to 20 entries, no duplicates, one file per domain.
- The apex has to be tracked already, through Tranco or a campaign. A list for an
  unknown domain is skipped, not an error.

These hosts show up under the parent domain on the site and are checked like any
other domain. They are deliberately **informational**: they never change the
parent's grade. Coverage here is uneven by construction, and a domain should not
score worse just because someone bothered to list its API host.

## Removing things

Delete the entry, or the file. Nothing is deleted from the database on merge —
hosts that stop being listed enter a 30-day grace period and are delisted after
it, so re-adding something within the month costs nothing. Deleting a campaign
file retires the campaign and keeps its history.

## Checking your file before you open a PR

The importer's rules are enforced by `v6ctl campaign validate`, which runs
offline against a checkout:

```sh
git clone https://github.com/lasseh/whynoipv6
cd whynoipv6/backend && go build -o bin/v6ctl ./cmd/v6ctl
./bin/v6ctl campaign validate --repo /path/to/whynoipv6-campaign
```

It never touches the network or a database, and exit 0 means every blocking
check passed. Skipping it is fine; I run the same checks before merging.

## Not comfortable with a pull request?

[Open an issue](https://github.com/lasseh/whynoipv6-campaign/issues/new?template=new-campaign.md)
with the title, a one-line description and the list of domains, and I will add it.

## The rest of the project

- [lasseh/whynoipv6](https://github.com/lasseh/whynoipv6) — crawler, API and web frontend
- [whynoipv6.com](https://whynoipv6.com) — the site
- [api.whynoipv6.com/docs](https://api.whynoipv6.com/docs) — the public API
