# Pinned public package-verification keys

These are upstream public verification keys; they contain no secret keys, Apple firmware or device identifiers.

| File | Official source commit/path | SHA-256 |
|---|---|---|
| omarchy.gpg | [omacom/omarchy-pkgs@1cf4b3113947a62c90b80d343dd3455aefdf1478/pkgbuilds/omarchy-keyring/omarchy.gpg](https://github.com/omacom/omarchy-pkgs/blob/1cf4b3113947a62c90b80d343dd3455aefdf1478/pkgbuilds/omarchy-keyring/omarchy.gpg) | `15d6aac44df688165b2ea35fe0b23af239bbc66a6909c10a5c219e8d94b707de` |
| archlinuxarm.gpg | [archlinuxarm/archlinuxarm-keyring@91e6b11698f8df66042d56aaa56fbe9c9263847d/archlinuxarm.gpg](https://github.com/archlinuxarm/archlinuxarm-keyring/blob/91e6b11698f8df66042d56aaa56fbe9c9263847d/archlinuxarm.gpg) | `50a08f82ce3cd524a552da4bfa37f3e04b2c9da468e2fce5783474b58a34c518` |

Accompanying trusted/revoked files come unchanged from those same commits. Both revoked lists are empty. Omarchy trusted primary fingerprint: `40DFB630FF42BCFFB047046CF0134EE680CAC571`.

Arch Linux ARM's trusted master fingerprints are `02922214DE8981D14DC2ACABBC704E86B823CD25`, `9D22B7BB678DC056B1F7723CB55C5315DCD9EE1A` and `69DD6C8FD314223E14362848BF7EEF7A9C6B5765`. Its build-system fingerprint is `68B3537F39A313B3E574D06777193F152BDBE6A6`.

The retrieved original bytes matched Git blob IDs: Omarchy `7c5ea36c3442699958c7120490e62da180d3bdc1`; ALARM `6b352c02e42b64d1867e265558e582f921ca05e8`. GnuPG parsed the keys and confirmed fingerprints. This establishes official-source trust roots, not independent personal verification of maintainers.

Verify all six inputs with `sha256sum -c SHA256SUMS` in this directory.

**Format:** Both pinned .gpg files contain ASCII-armored public key blocks despite their extensions. The builder dearmors both and concatenates the exact public key packets into a new binary verification keyring. It recreates its isolated GnuPG directory and does not need a secret-key agent or retain keys from an earlier pin. gpgv treats supplied keys as trusted and does not evaluate their master-key certification web of trust. Keep explicit pinned trust roots and revoked-key handling visible.

Package signatures stay required. Do not weaken checks to work around an unavailable key/mirror/package. Updating these inputs requires an explicit pin/checksum update and recorded provenance.
