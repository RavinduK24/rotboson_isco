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

The `sphboson/` directory packages a separate modified copy of:

```text
https://github.com/sontanon/SPHBOSON
```

That copy starts from upstream commit:

```text
0f582b3 Correct .gitignore.
```

It adds matching self-interaction potentials, l0 production templates, and
metric export files compatible with the ROTBOSON ISCO scanner. The spherical
solver is kept in its own directory so it does not change ROTBOSON's `l>=1`
parser and equations.

No separate license is added here because neither upstream checkout included a
license file in this working tree. Confirm licensing with the original authors
before redistributing beyond research collaboration.
