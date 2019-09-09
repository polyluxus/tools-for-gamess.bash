#!/bin/bash

# The following script gives default values to any of the scripts within the package.
# They can (or should) be set in the rc file, too.

# If this script is not sourced, return before executing anything
if (( ${#BASH_SOURCE[*]} == 1 )) ; then
  echo "This script is only meant to be sourced."
  exit 0
fi

#
# Generic details about these tools 
#
softwarename="tools-for-gamess.bash"
version="0.0.2"
versiondate="2019-09-09"

#
# Standard commands for external software:
#
# GAMESS related options
#
# General path to the GAMESS directory (this should work on every system)
gamess_installpath="/path/is/not/set"
# Define where scratch files shall be written to
# This writes an 'mktemp' command to the submission script, 
# hence let's the queuing system determine the scratch.
# (Should be set appropriately in rc.)
gamess_scratch="default"
# Define the overhead you'd like to give GAMESS in MB 
gamess_overhead=2000
# The 2000 might be a very conservative guess, nd should be adjusted as needed.
# Additionally (internally) the requested memory will be scaled up so that the memory value
# given to GAMESS is about 90% of the total memory requested from the queueing system.
#
# If a modular software management is available, use it?
load_modules="true"
# By default it takes the available path (at runtime) as this might include local directories
load_modules_from_path="$MODULEPATH"
# For example: On the RWTH cluster GAMESS can be loaded via a module system,
# an example file is included,
# the names (in correct order) of the modules:
gamess_modules[0]="gamess"

# Options related to use open babel
obabel_cmd="obabel"

#
# Default files, suffixes, options for GAMESS
#
gamess_input_suffix="inp"
gamess_output_suffix="log"

#
# Default options for printing (Not in use)
#
# Delimit values in the printout with "space" (default)/ "comma"/ "semicolon"/ "colon"/ "slash"/ "pipe" 
values_delimiter="space" 
#
# Set the default print level, higher numbers mean more output
output_verbosity=0

#
# Default values for queueing system submission
#
# Select a queueing system slurm-gen, slurm-rwth
request_qsys="slurm-rwth"
# Walltime for remote execution, header line for the queueing system
requested_walltime="24:00:00"
# Specify a default value for the memory (MB)
requested_memory=512
# This corresponds to nthreads/NProcShared (etc)
requested_numCPU=4
# TODO: Limits disk space, not sure if available for GAMESS
requested_maxdisk=10000
# Accounting to 
qsys_project=default
# E-Mail address to send notifications to
user_email=default
# Calculations will be submitted to run (hold/keep)
requested_submit_status="run"

