# Important Notes

## Longhorn Destruction Warning

When trying to destroy or uninstall the environment that uses Longhorn, you may encounter an issue where Longhorn volumes prevent proper cleanup. This is a safety feature to prevent data loss.

### The Error

```
kubectl -n longhorn-system get volumes
# Shows volumes in "terminating" state that won't delete
```

### The Fix

To force delete Longhorn volumes during environment teardown:

1. **Edit the Deletion Confirmation Setting:**
   ```bash
   kubectl -n longhorn-system edit settings.longhorn.io deleting-confirmation-flag
   ```

2. **Change the value from `true` to `false`:**

   Find this line:
   ```yaml
   value: "true"
   ```
   
   And change it to:
   ```yaml
   value: "false"
   ```

3. **Delete PersistentVolumes (PVs):**
   ```bash
   kubectl delete pv --all
   ```

4. **Uninstall Longhorn:**
   ```bash
   helmfile destroy
   # Or manually:
   helm uninstall longhorn -n longhorn-system
   kubectl delete namespace longhorn-system
   ```

### Why This Happens

Longhorn has a built-in safety mechanism that requires explicit confirmation before deleting volumes. This prevents accidental data loss. The `deleting-confirmation-flag` setting must be disabled to allow volume cleanup during environment teardown.

### Alternative: Disable During Installation

To avoid this issue in the future, you can configure Longhorn to not require confirmation by default:

```yaml
# In longhorn values
deleteConfirmationFlag: false
```

However, this is not recommended for production as it reduces data protection.
