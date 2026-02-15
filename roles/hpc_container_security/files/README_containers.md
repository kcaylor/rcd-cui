# Containers in the CUI Enclave

Use this guide to run Apptainer containers securely on CUI resources.

## Rules

- Container images must be signed by the approved organization key.
- Only approved bind paths are allowed (`/cui/projects`, `/cui/containers`, `/tmp`).
- Outbound networking is disabled by default (`--net --network=none`).
- InfiniBand passthrough is allowed for MPI jobs within CUI nodes.

## Run containers

```bash
apptainer-cui run /cui/containers/my-signed-image.sif
apptainer-cui exec /cui/containers/my-signed-image.sif python analysis.py
```

## Workflow testing examples

Validate these common workflows after image signing:

- Python: package environments, NumPy/SciPy scripts
- R: script execution with package libraries in the image
- GROMACS: MPI-enabled simulation binaries
- VASP: parallel job launch with scheduler integration

If a workflow fails due to policy restrictions, contact HPC operations for review.
