# Things to Investigate

## X-Scope-OrgID Header in Grafana, Loki, and Tempo

### Current State

The `X-Scope-OrgID` header is used for multi-tenancy across the Grafana LGTM stack. Currently configured with tenant ID `homelab`.

| Component    | Header Set? | Where |
|-------------|-------------|-------|
| Loki        | Yes (server-side) | Loki requires it in multi-tenant mode |
| Alloy       | Yes (producer) | `helmfile/common/values/alloy.yaml.gotmpl:22` — sends `X-Scope-OrgID: homelab` when pushing logs |
| Grafana/Loki| Yes (consumer) | `helmfile/common/values/grafana.yaml.gotmpl:75-76` — datasource sets `httpHeaderName1: X-Scope-OrgID` |
| Grafana/Tempo | No (not needed) | Tempo runs in single-tenant mode |
| Tempo       | No (single-tenant) | No `multitenancy_enabled` set — defaults to single-tenant |

### Resolution

**Tempo and Pyroscope remain single-tenant.** Only Loki uses `X-Scope-OrgID` multi-tenancy.

- Tempo has no `multitenancy_enabled` config, so it defaults to single-tenant mode. No `X-Scope-OrgID` header is needed.
- Pyroscope similarly runs single-tenant.
- Only Loki requires the `X-Scope-OrgID` header, which is already configured in both Alloy (producer) and the Grafana datasource (consumer).
- No changes needed for Tempo or Alloy trace pipelines regarding `X-Scope-OrgID`.

### References

- [Loki multi-tenancy docs](https://grafana.com/docs/loki/latest/operations/multi-tenancy/)
- [Tempo multi-tenancy docs](https://grafana.com/docs/tempo/latest/configuration/multitenancy/)
- [Grafana datasource httpHeaderName](https://grafana.com/docs/grafana/latest/datasources/tempo/configure-tempo-data-source/)
