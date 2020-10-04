#!/usr/bin/env bash

# set -x

# Copyright Zafar Khaydarov
#
# This is about to create a RAM disk in OS X and move the apps caches into it
# to increase performance of those apps. Performance gain is very significant,
# particularly for browsers and especially for IDEs like IntelliJ Idea.
#
# Drawbacks and risks are that if RAM disk becomes full - performance will degrade
# significantly - huge amount of paging will happen.
#
# USE AT YOUR OWN RISK. PLEASE NOTE IT WILL NOT CHECK FOR CORRUPTED FILES
# IF YOUR RAM IS BROKEN - DO NOT USE IT.
#

# The RAM amount you want to allocate for RAM disk. One of
# 1024 2048 3072 4096 5120 6144 7168 8192
# By default will use 1/4 of your RAM
RAM_SIZE_MB=$(sysctl hw.memsize | awk '{print $2;}')
RAMFS_SIZE_MB=$((RAM_SIZE_MB/1024/1024/4))

MOUNT_POINT=${HOME}/RAMDISK
RAMFS_SIZE_SECTORS=$((RAMFS_SIZE_MB*1024*1024/512))
RAMDISK_DEVICE=$(hdid -nomount ram://${RAMFS_SIZE_SECTORS} | xargs)


# Closes passed as arg app by name
close_app() {
   osascript -e "quit app \"${1}\""
}

# Creates RAM Disk.
mk_ram_disk() {
   # Unmount if already exists
   umount -f "${MOUNT_POINT}"
   newfs_hfs -v 'RAMDISK' "${RAMDISK_DEVICE}"
   mkdir -p "${MOUNT_POINT}"
   mount -o noatime -t hfs "${RAMDISK_DEVICE}" "${MOUNT_POINT}"
   echo "Created RAM Disk"

   # Hide RAM disk from finder
   /usr/bin/chflags hidden "${MOUNT_POINT}"
   echo "RAM Disk hidden"
}

# Checks prerequisite of having all the required utils before proceeding
check_prereq() {
   # Check if running as sudo
   [ -z "${SUDO_USER}" ] && {
      echo "Not running as admin. Aborting!"
      exit 1
   }

   # check for binary newfs_hfs
   hash newfs_hfs 2>/dev/null || { 
      echo >&2 "The binary 'newfs_hfs' has not been found. Aborting!"
      exit 1 
   }
}

# ------------------------------------------------------
# Applications, which needs the cache to be moved to RAM
# Add yours at the end.
# -------------------------------------------------------

# Add all IntelliJ Products
move_intellij_products() {
   # Close all the running apps
   echo "Closing all Intellij apps in 3 seconds..."
   sleep 3

   close_app "IntelliJ Idea Ultimate"
   close_app "WebStorm"
   close_app "PyCharm Professional"
   close_app "DataGrip"

   # Create the base caches directory
   INTELLIJ_BASE_CACHE_DIR="${MOUNT_POINT}/IntelliJ"
   [ -d "${INTELLIJ_BASE_CACHE_DIR}" ] || {
      echo "Creating the cache directory @ ${INTELLIJ_BASE_CACHE_DIR}"
      mkdir -p "${INTELLIJ_BASE_CACHE_DIR}"
      chown -R "${SUDO_USER}:admin" "${INTELLIJ_BASE_CACHE_DIR}"
   }

   # Create the base config directory
   INTELLIJ_BASE_CONF_DIR="/Users/${SUDO_USER}/.intellij-conf"
   [ -d "${INTELLIJ_BASE_CONF_DIR}" ] || {
      echo "Create the config directory @ ${INTELLIJ_BASE_CONF_DIR}"
      mkdir -p "${INTELLIJ_BASE_CONF_DIR}"
      chown -R "${SUDO_USER}:admin" "${INTELLIJ_BASE_CONF_DIR}"
   }

   # Process IDE specific changes
   declare -a INTELLIJ_APPS=("IDEA" "WEBIDE" "PYCHARM" "DATAGRIP")
   for IDE in "${INTELLIJ_APPS[@]}"
   do
      echo
      echo "Processing ${IDE}"
      # Create IDE specific cache directory
      mkdir -p "${INTELLIJ_BASE_CACHE_DIR}/${IDE}"
      mkdir -p "${INTELLIJ_BASE_CACHE_DIR}/${IDE}/compileroutput"
      chown -R "${SUDO_USER}:admin" "${INTELLIJ_BASE_CACHE_DIR}/${IDE}"

      # Create IDE specific config directory
      mkdir -p "${INTELLIJ_BASE_CONF_DIR}/${IDE}"
      chown -R "${SUDO_USER}:admin" "${INTELLIJ_BASE_CONF_DIR}/${IDE}"

      # Create IDE specific config entries
      echo "idea.system.path=${INTELLIJ_BASE_CACHE_DIR}/${IDE}/system" > "${INTELLIJ_BASE_CONF_DIR}/${IDE}/idea.properties"
      echo "idea.log.path=${INTELLIJ_BASE_CACHE_DIR}/${IDE}/logs" >> "${INTELLIJ_BASE_CONF_DIR}/${IDE}/idea.properties"

      # User message
      echo "Successfully processed ${IDE}. Please add the following to your path"
      echo "export ${IDE}_PROPERTIES=${INTELLIJ_BASE_CONF_DIR}/${IDE}/idea.properties"
   done

   echo
   echo "Successfully processed all Intellij apps"
}

# -----------------------------------------------------------------------------------
# The entry point
# -----------------------------------------------------------------------------------
main() {
   check_prereq
   mk_ram_disk
   
   move_intellij_products

   echo
   echo "All done. Your apps should fly now"
}

main "$@"
# -----------------------------------------------------------------------------------
