#!/bin/bash

# If this script is not sourced, return before executing anything
if (return 0 2>/dev/null) ; then
  # [How to detect if a script is being sourced](https://stackoverflow.com/a/28776166/3180795)
  : #Everything is fine
else
  echo "This script is only meant to be sourced."
  exit 0
fi

#
# Filename related functions
#

match_output_suffix ()
{
  local   allowed_input_suffix=(com in  inp COM IN  INP )
  local matching_output_suffix=(log out log LOG OUT LOG )
  local choices=${#allowed_input_suffix[*]} count
  local test_suffix="$1" return_suffix
  debug "test_suffix=$test_suffix; choices=$choices"
  
  # Assign matching outputfile
  for (( count=0 ; count < choices ; count++ )) ; do
    debug "count=$count"
    if [[ "$test_suffix" == "${matching_output_suffix[$count]}" ]]; then
      return_suffix="$extract_suffix"
      debug "Recognised output suffix: $return_suffix."
      break
    elif [[ "$test_suffix" == "${allowed_input_suffix[$count]}" ]]; then
      return_suffix="${matching_output_suffix[$count]}"
      debug "Matched output suffix: $return_suffix."
      break
    else
      debug "No match for $test_suffix; $count; ${allowed_input_suffix[$count]}; ${matching_output_suffix[$count]}"
    fi
  done

  [[ -z $return_suffix ]] && return 1

  echo "$return_suffix"
}

match_output_file ()
{
  # Check what was supplied and if it is read/writeable
  # Returns a filename
  local extract_suffix return_suffix basename
  local testfile="$1" return_file
  debug "Validating: $testfile"

  basename="${testfile%.*}"
  extract_suffix="${testfile##*.}"
  debug "basename=$basename; extract_suffix=$extract_suffix"

  if return_suffix=$(match_output_suffix "$extract_suffix") ; then
    return_file="$basename.$return_suffix"
  else
    return 1
  fi

  [[ -r $return_file ]] || return 1

  echo "$return_file"    
}

#
# modified input files
#

extract_jobname_inoutnames ()
{
    # Assigns the global variables inputfile outputfile jobname
    # Checks is locations are read/writeable
    local testfile="$1"
    local input_suffix output_suffix
    local -a test_possible_inputfiles
    debug "Validating: $testfile"

    # Check if supplied inputfile is readable, extract suffix and title
    if inputfile=$(is_readable_file_or_exit "$testfile") ; then
      jobname="${inputfile%.*}"
      input_suffix="${inputfile##*.}"
      debug "Jobname: $jobname; Input suffix: $input_suffix."
      # Assign matching outputfile
      if output_suffix=$(match_output_suffix "$input_suffix") ; then
        debug "Output suffix: $output_suffix."
      else
        # Abort when input-suffix cannot be identified
        fatal "Unrecognised suffix of inputfile '$testfile'."
      fi
    else
      # Assume that only jobname was given
      debug "Assuming that '$testfile' is the jobname."
      jobname="$testfile"
      unset testfile
      mapfile -t test_possible_inputfiles < <( ls ./"$jobname".* 2> /dev/null ) 
      debug "Found possible inputfiles: ${test_possible_inputfiles[*]}"
      (( ${#test_possible_inputfiles[*]} == 0 )) &&  fatal "No input files belonging to '$jobname' found in this directory."
      for testfile in "${test_possible_inputfiles[@]}" ; do
        input_suffix="${testfile##*.}"
        debug "Extracted input suffix '$input_suffix', and will test if allowed."
        if output_suffix=$(match_output_suffix "$input_suffix") ; then
          debug "Will use input suffix '$input_suffix'."
          debug "Will use output suffix '$output_suffix'."
          break
        fi
      done
      debug "Jobname: $jobname; Input suffix: $input_suffix; Output suffix: $output_suffix."
    fi
    outputfile="$jobname.$output_suffix"
}

validate_write_in_out_jobname ()
{
    # Assigns the global variables inputfile outputfile jobname
    # Checks is locations are read/writeable
    local testfile="$1"
    extract_jobname_inoutnames "$testfile"

    # Check special ending of input file
    # it is only necessary to check agains one specific suffix 'gjf' as that is hard coded in main script
    if [[ "${inputfile##*}" == "gjf" ]] ; then
      warning "The chosen inputfile will be overwritten."
      backup_file "$inputfile" "${inputfile}.bak"
      inputfile="${inputfile}.bak"
    fi

    # Check if an outputfile exists and prevent overwriting
    backup_if_exists "$outputfile"

    # Display short logging message
    message "Will process Inputfile '$inputfile'."
    message "Output will be written to '$outputfile'."
}

read_gamess_input_file () 
{
  local readfile="$1"
  local line 
  local pattern_system_start pattern_end pattern_memddi pattern_mwords
  local detected_system detected_memddi used_mwords applied_system
  local requested_memory_mwords
  pattern_end='\$[Ee][Nn][Dd][[:space:]]*$'
  while IFS= read -r line || [[ -n "$line" ]] ; do
    debug "Read line: |$line|"
    if [[ -z $detected_system ]] ; then
      debug "Nothing to append."
      pattern_start='^[[:space:]]+\$[Ss][Yy][Ss][Tt][Ee][Mm]([[:space:]]+|$)'
      if [[ "$line" =~ $pattern_start ]] ; then
        debug "System group detected in '$line'."
        [[ -n $applied_system ]] && warning "Found second SYSTEM group, maybe the input is corrupted."
        detected_system="$line"
        unset line
      else
        debug "System group not yet detected."
      fi
    else
      debug "Appending line"
      detected_system+=" $line"
      debug "Line is now: |$detected_system|"
      unset line
    fi
    if [[ -n $detected_system ]] ; then
      if [[ "$detected_system" =~ $pattern_end ]] ; then
        debug "Found END pattern."
        pattern_memddi='^(.*)[Mm][Ee][Mm][Dd][Dd][Ii]=([1-9][0-9]*)([^[0-9].*)$'
        if [[ "$detected_system" =~ $pattern_memddi ]] ; then
          detected_memddi="${BASH_REMATCH[2]}"
          message "Found MEMDDI statement ($detected_memddi)."
        fi
        requested_memory_mwords=$(( requested_memory / 8 - 1 * requested_numCPU ))
        debug "Requested memory: $requested_memory_mwords"
        (( detected_memddi > requested_memory_mwords )) && fatal "Not enough memory requested. Use at least $(( (detected_memddi + 1) * 8 ))MB!"
        used_mwords="$(( (requested_memory_mwords - detected_memddi) / requested_numCPU ))"
        debug "Will apply MWORDS=${used_mwords}."
        pattern_mwords='^(.*)[Mm][Ww][Oo][Rr][Dd][Ss]=([1-9][0-9]*)([^[0-9].*)$'
        if [[ "$detected_system" =~ $pattern_mwords ]] ; then
          debug "|$detected_system|"
          # Message resets BASH_REMATCH, so it needs to be stored now.
          detected_system="${BASH_REMATCH[1]}MWORDS=${used_mwords}${BASH_REMATCH[3]}"
          message "Found MWORDS statement (${BASH_REMATCH[2]}), but will replace it by script settings."
          debug "|$detected_system|"
        else
          message "Inserting default MWORDS statement."
          if [[ "$detected_system" =~ ^(.*)($pattern_end) ]] ; then
            detected_system="${BASH_REMATCH[1]}MWORDS=${used_mwords} ${BASH_REMATCH[2]}"
          else
            fatal "Something went wrong reading the input file. Please file a bug report."
          fi
        fi
        debug "Assembled: $detected_system"
        line="$detected_system"
        applied_system=true
        unset detected_system
      fi
    fi
    [[ -n $line ]] && stored_gamess_input+=( "$line" )
  done < "$readfile"
  if [[ -z $applied_system ]] ; then
    message "No system group detected; inserting default."
    local default_system_group requested_memory_mwords
    requested_memory_mwords=$(( requested_memory / 8 ))
    default_system_group=" \$SYSTEM MWORDS=$(( requested_memory_mwords / requested_numCPU )) \$END"
    stored_gamess_input+=( "$default_system_group" )
    debug "Added: ${stored_gamess_input[-1]}"
  else
    debug "System already inserted."
  fi
}

write_gamess_input_file ()
{
  printf '%s\n' "${stored_gamess_input[@]}"
  echo "! Assembled with $softwarename"
}

