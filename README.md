# tools-for-gamess.bash

The intention of this repository is to provide some scripts
which should help with the execution and submission of GAMESS.

Currently only a submission script is available,
and it is pretty much tailored to the RWTH Cluster (CLAIX18).

To view a short description, issue:
```
gamess.submit.sh -h
```

Configuration of the script with the files
`gamess.tools.rc` or `.gamess.toolsrc` (has precedence) 
in one of the directories:
installation directory, `HOME`, `HOME/.config`, `PWD`.
The last found file will be applied.
