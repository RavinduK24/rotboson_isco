# Upstream Provenance

This repository packages a modified ROTBOSON workflow for rotating boson-star
ISCO studies.

The base solver comes from:

```text
https://github.com/sontanon/ROTBOSON
```

The local work started from upstream commit:

```text
f156eea Add working instructions for l=1 data.
```

This repository adds self-interaction potentials, potential-aware output
metadata, ISCO postprocessing, Python/C regression tests, and PolyU-oriented HPC
SLURM templates. It does not claim new authorship of the original ROTBOSON
solver.

No separate license is added here because the upstream checkout did not include
a license file in this working tree. Confirm licensing with the original
ROTBOSON authors before redistributing beyond research collaboration.
