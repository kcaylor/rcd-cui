# Data Model: Pre-Baked Vagrant Box Workflow

**Feature**: 009-vagrant-prebaked-boxes
**Date**: 2026-03-02

## Entities

### BoxSet

A collection of four Vagrant box files representing a fully provisioned demo cluster at a specific point in time.

| Field | Type | Description |
|-------|------|-------------|
| label | string | Unique identifier, format: `rcd-demo-YYYYMMDD-NN` (e.g., `rcd-demo-20260302-01`) |
| created_at | ISO 8601 datetime | When the box set was created |
| git_commit | string | Short SHA of the Git commit at bake time |
| git_branch | string | Git branch name at bake time |
| provider | string | Vagrant provider used (`virtualbox`, `libvirt`, `qemu`) |
| vagrant_version | string | Vagrant version at bake time |
| boxes | map[string → BoxFile] | Per-VM box file entries keyed by VM name |
| status | enum | `current` or `previous` |

**Identity**: `label` (unique across all sets)
**Retention**: At most 2 sets retained. When a 3rd is created, the `previous` set is deleted, `current` becomes `previous`, and the new set becomes `current`.

### BoxFile

A single Vagrant box file for one VM within a BoxSet.

| Field | Type | Description |
|-------|------|-------------|
| vm_name | string | VM name (`mgmt01`, `login01`, `compute01`, `compute02`) |
| filename | string | Box file name relative to `demo/vagrant/boxes/` |
| size_bytes | integer | File size in bytes |
| vagrant_box_name | string | Name registered with Vagrant (e.g., `rcd-cui-mgmt01`) |

### BoxManifest

The top-level manifest structure stored at `demo/vagrant/boxes/manifest.json`.

| Field | Type | Description |
|-------|------|-------------|
| version | integer | Manifest schema version (currently `1`) |
| staleness_days | integer | Configurable staleness threshold (default: `7`) |
| sets | map[string → BoxSet] | All box sets keyed by label |

## State Transitions

```
[No boxes] ---(demo-bake.sh)---> [1 set: current]
[1 set: current] ---(demo-bake.sh)---> [2 sets: current + previous]
[2 sets: current + previous] ---(demo-bake.sh)---> [2 sets: new current + old current becomes previous, old previous deleted]
[Any state] ---(demo-bake.sh --delete-all)---> [No boxes]
[2 sets] ---(demo-bake.sh --delete <label>)---> [1 set]
[1 set] ---(demo-bake.sh --delete <label>)---> [No boxes]
```

## Manifest JSON Example

```json
{
  "version": 1,
  "staleness_days": 7,
  "sets": {
    "rcd-demo-20260302-01": {
      "created_at": "2026-03-02T14:30:00Z",
      "git_commit": "9903f3c",
      "git_branch": "main",
      "provider": "virtualbox",
      "vagrant_version": "2.4.1",
      "status": "current",
      "boxes": {
        "mgmt01": {
          "vm_name": "mgmt01",
          "filename": "rcd-demo-20260302-01-mgmt01.box",
          "size_bytes": 3221225472,
          "vagrant_box_name": "rcd-cui-mgmt01"
        },
        "login01": {
          "vm_name": "login01",
          "filename": "rcd-demo-20260302-01-login01.box",
          "size_bytes": 2147483648,
          "vagrant_box_name": "rcd-cui-login01"
        },
        "compute01": {
          "vm_name": "compute01",
          "filename": "rcd-demo-20260302-01-compute01.box",
          "size_bytes": 2147483648,
          "vagrant_box_name": "rcd-cui-compute01"
        },
        "compute02": {
          "vm_name": "compute02",
          "filename": "rcd-demo-20260302-01-compute02.box",
          "size_bytes": 2147483648,
          "vagrant_box_name": "rcd-cui-compute02"
        }
      }
    }
  }
}
```

## Relationships

- A **BoxManifest** contains 0-2 **BoxSet** entries
- A **BoxSet** contains exactly 4 **BoxFile** entries (one per VM)
- A **BoxSet** references a Git commit and provider from the bake environment
- The **Vagrantfile** reads `ENV['RCD_PREBAKED']` to select between `generic/rocky9` and baked box names
- The **demo-setup.sh** script reads the **BoxManifest** to detect available boxes and their staleness
