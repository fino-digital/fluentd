# Fluentd

Custom Fluentd image for fino, shipping logs to Sematext. It is the upstream
`fluent/fluentd` image plus the gems needed for our pipeline (Sematext via the
elasticsearch output, OTC S3, kubernetes metadata, anonymizer, etc.).

## Base image

Built `FROM fluent/fluentd:v1.19-debian-2`, pinned by digest (upstream,
maintained). We moved off `bitnamilegacy/fluentd`, which is frozen and no longer
gets CVE fixes. Each build still runs `apt-get upgrade` for Debian CVEs. All
gems are pinned for reproducible builds; the CVE-prone bundled Ruby gems (`erb`,
`rdoc`, `rexml`, `cgi`) are pinned to their current fixed releases, and
`net-imap` is removed (nothing here uses IMAP, and it is a recurring CVE
source). Bump the base digest and the gem pins on a periodic rebuild.

## Pinned elasticsearch gems

`elasticsearch` / `elasticsearch-api` / `elasticsearch-transport` /
`elasticsearch-xpack` are pinned to 7.13.3 and `fluent-plugin-elasticsearch` to
4.3.3. These talk to the Sematext logsene receiver correctly; newer clients
(ES 8.x, fluent-plugin-elasticsearch 5.x) change the bulk-API handshake. Do not
bump without validating ingestion against Sematext first. If a vuln scan flags
them, validate the bump against a throwaway Sematext index before releasing.

## Layout

The image keeps the `/opt/bitnami/fluentd` layout (config at
`/opt/bitnami/fluentd/conf`, buffers under `/opt/bitnami/fluentd/logs/buffers`)
so it is a drop-in for the provisioning manifests that replaced the Bitnami
chart. Switching to a plain `/fluentd` layout requires changing those mounts in
the manifests at the same time.

## Releasing

`.github/workflows/release.yaml` builds and pushes `ghcr.io/fino-digital/fluentd:<tag>`
on any git tag push. To release: tag the commit (e.g. `git tag v1.19.2 && git
push origin v1.19.2`), then bump the image tag in the provisioning repo
(`00_base/infrastructure/fluentd/_manifests/*.yaml`, and the Bitnami HelmRelease
override for any env still on the chart). Roll out dev -> test -> prod.
