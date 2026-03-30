# Things to Investigate

## X-Scope-OrgID Header in Grafana, Loki, and Tempo

### Current State

The `X-Scope-OrgID` header is used for multi-tenancy across the Grafana LGTM stack. Currently configured with tenant ID `homelab`.

| Component    | Header Set? | Where |
|-------------|-------------|-------|
| Loki        | Yes (server-side) | Loki requires it in multi-tenant mode |
| Alloy       | Yes (producer) | `helmfile/common/values/alloy.yaml.gotmpl:22` — sends `X-Scope-OrgID: homelab` when pushing logs |
| Grafana/Loki| Yes (consumer) | `helmfile/common/values/grafana.yaml.gotmpl:75-76` — datasource sets `httpHeaderName1: X-Scope-OrgID` |
| Grafana/Tempo | **No** | `helmfile/common/values/grafana.yaml.gotmpl:77-84` — Tempo datasource has no `X-Scope-OrgID` |
| Tempo       | **Unknown** | `helmfile/common/values/tempo.yaml.gotmpl` — no explicit tenant config |

### Questions to Investigate

1. **Does Tempo require `X-Scope-OrgID`?**
   - Tempo supports multi-tenancy via `X-Scope-OrgID` when the `multitenancy_enabled` option is set in its config.
   - Check if Tempo is currently running in single-tenant or multi-tenant mode.
   - If multi-tenant, the Grafana Tempo datasource must send the header (same pattern as Loki datasource).

2. **Should the Grafana Tempo datasource include `X-Scope-OrgID`?**
   - If Tempo is or will be multi-tenant, add to the Tempo datasource in `grafana.yaml.gotmpl`:
     ```yaml
     - name: Tempo
       type: tempo
       uid: tempo
       url: http://tempo.prometheus.svc.cluster.local:3200
       access: proxy
       jsonData:
         nodeGraph:
           enabled: true
         httpHeaderName1: X-Scope-OrgID
         httpHeaderValue1: homelab
     ```

3. **Should Alloy also send traces to Tempo with `X-Scope-OrgID`?**
   - Currently Alloy only sends logs to Loki. If Alloy is configured to send traces to Tempo, the same header pattern should be used:
     ```
     headers = { "X-Scope-OrgID" = "homelab" }
     ```

4. **Consistency across the stack**
   - All components producing or consuming data should use the same tenant ID (`homelab`).
   - Verify: Loki gateway, Tempo, Grafana datasources, and any OTEL/trace exporters.

### References

- [Loki multi-tenancy docs](https://grafana.com/docs/loki/latest/operations/multi-tenancy/)
- [Tempo multi-tenancy docs](https://grafana.com/docs/tempo/latest/configuration/multitenancy/)
- [Grafana datasource httpHeaderName](https://grafana.com/docs/grafana/latest/datasources/tempo/configure-tempo-data-source/)
