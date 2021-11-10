#!/bin/sh

#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
#######################################################################

#######################################################################
# Global variables
export ZWECLI_PARAMETERS_LIST=
export ZWECLI_COMMANDS_LIST=
export ZWECLI_LOGLEVEL=
export ZWECLI_PARAMETERS_DEFINITIONS=

zwecli_load_parameters_definition() {
  command_path=${ZOWE_RUNTIME_DIRECTORY}/bin/commands
  ZWECLI_PARAMETERS_DEFINITIONS="${ZWECLI_PARAMETERS_DEFINITIONS}\n$(cat "${command_path}/.parameters")"
  last_command=
  for command in ${ZWECLI_COMMANDS_LIST}; do
    if [ -d "${command_path}/${command}" ]; then
      command_path="${command_path}/${command}"
      last_command=$(trim "${last_command} ${command}")
      if [ -f "${command_path}/.parameters" ]; then
        ZWECLI_PARAMETERS_DEFINITIONS="${ZWECLI_PARAMETERS_DEFINITIONS}\n$(cat "${command_path}/.parameters")"
      fi
    else
      if [ -z "${last_command}" ]; then
        print_error "Error: invalid command \"${command}\""
      else
        print_error "Error: invalid sub-command \"${command}\" of command \"${last_command}\""
      fi
      print_error_and_exit "Try --help to get information about what command(s) are available."
    fi
  done
}

zwecli_locate_parameter_definition() {
  param=$1

  match=
  while read -r line; do
    line=$(trim "${line}")
    if [ -n "${line}" ]; then
      line_params_full=$(echo "${line}" | awk -F"|" '{print $1};' | tr "," " ")
      if [ -n "${line_params_full}" ]; then
        for one in ${line_params_full}; do
          if [ "${param}" = "--${one}" ]; then
            match=${line}
            break
          fi
        done
      fi
      if [ -z "${match}" ]; then
        line_params_alias=$(echo "${line}" | awk -F"|" '{print $2};')
        if [ "${param}" = "-${line_params_alias}" ]; then
          match=${line}
        fi
      fi
      if [ -n "${match}" ]; then
        break
      fi
    fi
  done <<EOF
$(echo "${ZWECLI_PARAMETERS_DEFINITIONS}")
EOF

  if [ -n "${match}" ]; then
    echo "${match}"
    return 0
  else
    return 1
  fi
}

zwecli_get_parameter_value() {
  param_id=$1

  param_var=$(echo "ZWECLI_PARAMETER_${param_id}" | upper_case | sanitize_alphanum)
  eval "echo \"\$${param_var}\""
}

zwecli_process_loglevel() {
  if [ "${ZWECLI_PARAMETER_DEBUG}" = "true" -o "${ZWECLI_PARAMETER_VERBOSE}" = "true" ]; then
    ZWECLI_LOGLEVEL=debug
  fi
  if [ "${ZWECLI_PARAMETER_TRACE}" = "true" ]; then
    ZWECLI_LOGLEVEL=trace
  fi
}

zwecli_process_logfile() {
  if [ -n "${ZWECLI_PARAMETER_LOG}" ]; then
    log_prefix=zwe
    if [ -n "${ZWECLI_COMMANDS_LIST}" ]; then
      log_prefix=zwe-$(echo "${ZWECLI_COMMANDS_LIST}" | trim | sed 's/ /-/g')
    fi
    prepare_log_file "${ZWECLI_PARAMETER_LOG}" "${log_prefix}"

    # write initial information
    print_message "Zowe Server CLI: zwe ${ZWECLI_COMMANDS_LIST}" "log"
    print_message "- timestamp: $(date +"%Y-%m-%d %H:%M:%S")" "log"
    print_message "- parameters:" "log"
    for param in ${ZWECLI_PARAMETERS_LIST}; do
      print_message "  * ${param}: $(zwecli_get_parameter_value "${param}")" "log"
    done
    print_message "" "log"
echo

  fi
}

zwecli_display_parameters_help() {
  file=$1

  while read -r line; do
    line=$(trim "${line}")
    if [ -n "${line}" ]; then
      display_param=
      line_params_full=$(echo "${line}" | awk -F"|" '{print $1};' | tr "," " ")
      for one in ${line_params_full}; do
        if [ -z "${display_param}" ]; then
          display_param="--${one}"
        else
          display_param="${display_param}|--${one}"
        fi
      done

      line_params_alias=$(echo "${line}" | awk -F"|" '{print $2};')
      if [ -n "${line_params_alias}" ]; then
        if [ -z "${display_param}" ]; then
          display_param="-${line_params_alias}"
        else
          display_param="${display_param}|-${line_params_alias}"
        fi
      fi

      line_params_type=$(echo "${line}" | awk -F"|" '{print $3};' | lower_case)
      if [ "${line_params_type}" = "b" -o "${line_params_type}" = "bool" ]; then
        line_params_type=boolean
      elif [ "${line_params_type}" = "s" -o "${line_params_type}" = "str" ]; then
        line_params_type=string
      fi

      line_params_requirement=$(echo "${line}" | awk -F"|" '{print $4};' | lower_case)

      line_params_help=$(echo "${line}" | sed -e 's#^[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|##')
      echo "  ${display_param}: ${line_params_type}, ${line_params_requirement:-optional}"
      padding_left "${line_params_help}" "    "
    fi
  done <<EOF
$(cat ${file})
EOF
}

zwecli_calculate_command_path() {
  if [ $# -eq 0 ]; then
    commands="${ZWECLI_COMMANDS_LIST}"
  else
    commands="${1}"
  fi

  if [ -z "${commands}" ]; then
    echo "${ZOWE_RUNTIME_DIRECTORY}/bin/commands"
  else
    echo "${ZOWE_RUNTIME_DIRECTORY}/bin/commands/$(echo "${commands}" | sed -e 's# #/#')"
  fi
}

zwecli_process_help() {
  if [ "${ZWECLI_PARAMETER_HELP}" = "true" ]; then
    >&2 echo "Zowe Server CLI: zwe ${ZWECLI_COMMANDS_LIST}"
    >&2 echo

    # display help message if exists
    command_path=$(zwecli_calculate_command_path)
    if [ -f "${command_path}/.help" ]; then
      >&2 cat "${command_path}/.help"
      >&2 echo
    fi

    # display global parameters
    if [ -f "${ZOWE_RUNTIME_DIRECTORY}/bin/commands/.parameters" ]; then
      >&2 echo "------------------"
      >&2 echo "Global parameters:"
      >&2 zwecli_display_parameters_help "${ZOWE_RUNTIME_DIRECTORY}/bin/commands/.parameters"
      >&2 echo
    fi

    # display command parameters
    command_tree=
    command_path="${ZOWE_RUNTIME_DIRECTORY}/bin/commands"
    for command in ${ZWECLI_COMMANDS_LIST}; do
      command_tree=$(echo "${command_tree} ${command}" | trim)
      command_path="${command_path}/${command}"
      if [ -f "${command_path}/.experimental" ]; then
        >&2 echo "WARNING: command \"${command_tree}\" is for experimental purpose."
        >&2 echo
      fi
      if [ -f "${command_path}/.parameters" ]; then
        >&2 echo "------------------"
        >&2 echo "Parameters for command \"${command_tree}\":"
        >&2 zwecli_display_parameters_help "${command_path}/.parameters"
        >&2 echo
      fi
    done

    # find sub-commands
    command_path=$(zwecli_calculate_command_path)
    subdirs=$(find_sub_directories "${command_path}")
    if [ -n "${subdirs}" ]; then
      >&2 echo "------------------"
      >&2 echo "Available sub-command(s):"
      while read -r line; do
        echo "  - $(basename "${line}")"
      done <<EOF
$(echo "${subdirs}")
EOF
      echo
    fi

    exit 99
  fi
}

zwecli_validate_parameters() {
  required_params=
  while read -r line; do
    line=$(trim "${line}")
    if [ -n "${line}" ]; then
      param_id=$(echo "${line}" | awk -F"|" '{print $1}' | awk -F, '{print $1}')
      param_requirement=$(echo "${line}" | awk -F"|" '{print $4}' | lower_case)
      if [ "${param_requirement}" = "required" ]; then
        required_params=$(echo "${required_params} ${param_id}" | trim)
      fi
    fi
  done <<EOF
$(echo "${ZWECLI_PARAMETERS_DEFINITIONS}")
EOF

  for param in ${required_params}; do
    val=$(zwecli_get_parameter_value "${param}")
    if [ -z "${val}" ]; then
      print_error "Error: ${param} parameter is required"
      print_error_and_exit "Try --help to get information about how to use this command."
    fi
  done
}

zwecli_process_command() {
  command_path=$(zwecli_calculate_command_path)
  if [ -f "${command_path}/index.sh" ]; then
    . "${command_path}/index.sh"
  else
    if [ -n "${ZWECLI_COMMANDS_LIST}" ]; then
      print_error "Error: no handler defined for command \"${ZWECLI_COMMANDS_LIST}\"."
    fi
    print_error_and_exit "Try --help to get information about how to use this command." 2
  fi
}
