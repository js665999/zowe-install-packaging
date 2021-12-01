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

###############################
# Constants
tmp_ext_dir=tmp_ext_dir
# Variables
target_dir=$(remove_trailing_slash "${ZWE_CLI_PARAMETER_TARGET_DIR}")
module_file_short=$(basename "${ZWE_CLI_PARAMETER_MODULE_FILE}")

###############################
# node is required to read module manifest
require_node

###############################
# clean up
cd "${ZWE_PWD}" && cd "${target_dir}"
if [ "$(pwd)" = "/" ]; then
  print_error_and_exit "Error ZWEL0153E: Cannot install Zowe module to system root directory." "" 153
fi
if [ -z "${tmp_ext_dir}" ]; then
  print_error_and_exit "Error ZWEL0154E: Temporary directory is empty." "" 154
fi
rm -fr "${tmp_ext_dir}"

print_message "Install ${module_file_short}"

if [ -d "${ZWE_CLI_PARAMETER_MODULE_FILE}" ]; then
  print_debug "- Module ${ZWE_CLI_PARAMETER_MODULE_FILE} is a directory, will create symbolic link into target directory."
  ln -s "${ZWE_CLI_PARAMETER_MODULE_FILE}" "${tmp_ext_dir}"
else
  # create temporary directory to lay down extension files in
  mkdir -p "${tmp_ext_dir}" && cd "${tmp_ext_dir}"

  print_debug "- Extract file ${module_file_short} to temporary directory."

  if [[ "${ZWE_CLI_PARAMETER_MODULE_FILE}" = *.pax ]]; then
    pax -ppx -rf "${ZWE_CLI_PARAMETER_MODULE_FILE}"
  elif [[ "${ZWE_CLI_PARAMETER_MODULE_FILE}" = *.zip ]]; then
    require_java
    jar xf "${ZWE_CLI_PARAMETER_MODULE_FILE}"
  elif [[ "${ZWE_CLI_PARAMETER_MODULE_FILE}" = *.tar ]]; then
    _CEE_RUNOPTS="FILETAG() POSIX(ON)" pax -x tar -rf "${ZWE_CLI_PARAMETER_MODULE_FILE}"
  fi

  print_trace "  * List extracted files:"
  print_trace "$(padding_left "$(ls -la)" "    ")"
fi

# automatically tag files
if [ "${ZWE_RUN_ON_ZOS}" = "true" ]; then
  cd "${ZWE_PWD}" && cd "${target_dir}"
  manifest_encoding=$(detect_component_manifest_encoding "${tmp_ext_dir}")
  print_debug "- Requested auto_encoding=${ZWE_CLI_PARAMETER_AUTO_ENCODING}, component manifest encoding is ${manifest_encoding}."
  #the autotag script we have is for tagging when files are ascii, so we assume tagging cant be done unless ascii
  autotag="no"

  if [ "${manifest_encoding}" = "ISO8859-1" ]; then
    is_tagged=$(detect_if_component_tagged "${tmp_ext_dir}")
    # unless explicitly asked to tag, if component is already tagged, retag could produce errors
    if [ "${is_tagged}" = "true" ]; then
      print_debug "  * Component tagged, so turning auto-encoding off"
      autotag="no"
    else
      print_debug "  * ASCII Component not tagged, so turning auto-encoding ON"
      autotag="yes"
    fi
  fi
  if [ "${ZWE_CLI_PARAMETER_AUTO_ENCODING}" != "no" -a "${autotag}" = "yes" ]; then
    # automatically tag files
    print_debug "- Automatically tag files"
    print_trace "$("${ZWE_zowe_runtimeDirectory}/bin/utils/tag-files.sh" "${tmp_ext_dir}" 1>&2)"

    cd "${tmp_ext_dir}"
    print_trace "  * List tagged files:"
    print_trace "$(padding_left "$(ls -TREal)" "    ")"
  fi
fi

cd "${ZWE_PWD}" && cd "${target_dir}"
component_name=$(read_component_manifest "${tmp_ext_dir}" ".name" 2>/dev/null)
if [ -z "${component_name}" -o "${component_name}" = "null" ]; then
  rm -fr "${tmp_ext_dir}"
  print_error "Error: Cannot find component name from package manifest."
fi
print_debug "- Component name found as ${component_name}"
# export for next step
export ZWE_MODULES_INSTALL_EXTRACT_COMPONENT_NAME="${component_name}"
if [ -e "${component_name}" ]; then
  rm -fr "${tmp_ext_dir}"
  print_error_and_exit "Error ZWEL0155E: Component ${component_name} already exists in ${target_dir}." "" 155
fi

print_debug "- Rename temporary directory to ${component_name}."
mv "${tmp_ext_dir}" "${component_name}"
