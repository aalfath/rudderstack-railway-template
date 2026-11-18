# Changelog

Each entry lists breaking changes first. Railway shows deployers an "update available" notice when `main` changes; read the entry before you apply it.

## 2026-11-18: rudder-server 1.93.0, rudder-transformer 1.169.0

- First release of this template.
- `rudderlabs/rudder-server:1.93.0@sha256:35425ca909205c828254d51743e4e67c648ebbe05aea876c73ea24b118105c4a`
- `rudderstack/rudder-transformer:1.169.0@sha256:a0c2d5141174e9653b9266b07bd6f5b3511b76a40d35d83a62b71f00a2c2bec4`
- Railway Postgres as the jobs database, a volume on `/data` for rudder-server's working files.
- Standalone mode (no RudderStack account) with a generated write key, or the hosted control plane with `WORKSPACE_TOKEN`.
