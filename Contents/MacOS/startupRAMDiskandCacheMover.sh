#!/usr/bin/env bash

set -x

#
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

MSG_MOVE_CACHE="Do you wish to move it's cache? It will kill the app process"

#
# Checks for the user response.
#
user_response()
{
   echo -ne "$@" "[Y/n]  "
   read -r response

   case ${response} in
      [yY][eE][sS]|[yY]|"")
         true
         ;;
      [nN][oO]|[nN])
         false
         ;;
      *)
         user_response "$@"
         ;;
   esac
}

#
# Closes passed as arg app by name
#
close_app()
{
   osascript -e "quit app \"${1}\""
}

#
# Creates RAM Disk.
#
mk_ram_disk()
{
   # unmount if exists and mounts if doesn't
   umount -f "${MOUNT_POINT}"
   newfs_hfs -v 'RAMDISK' "${RAMDISK_DEVICE}"
   mkdir -p "${MOUNT_POINT}"
   mount -o noatime -t hfs "${RAMDISK_DEVICE}" "${MOUNT_POINT}"

   echo "Created RAM Disk"
   # Hide RAM disk - we don't really need it to be annoiyng in finder.
   # comment out should you need it.
   hide_ramdisk
   echo "RAM Disk hidden"
}

# Hide RamDisk directory
hide_ramdisk()
{
   /usr/bin/chflags hidden "${MOUNT_POINT}"
}

# Checks that we have
# all required utils before proceeding
check_requirements()
{
   hash newfs_hfs 2>/dev/null || { echo >&2 "No newfs_hfs has been found.  Aborting."; exit 1; }
}

# ------------------------------------------------------
# Applications, which needs the cache to be moved to RAM
# Add yours at the end.
# -------------------------------------------------------

#
# Intellij Idea
#
move_idea_cache()
{
   echo
   if user_response 'IntelliJ IDEA: '"${MSG_MOVE_CACHE}" ; then
      echo 'Target User: '
      read -r user_name

      if [ -n "${user_name}" ]; then
         close_app "IntelliJ Idea"
         # create Idea config
         [ -d "${MOUNT_POINT}"/Idea ] || {
            mkdir -p "${MOUNT_POINT}"/Idea
            chown -R "${user_name}":admin "${MOUNT_POINT}"/Idea
         }
         # make a backup of config - will need it when uninstalling
         cp -f "${HOME}/idea.properties" "${HOME}/idea.properties.back" &>/dev/null
         # Idea will create those dirs
         echo "idea.system.path=${MOUNT_POINT}/Idea" >> "${HOME}/idea.properties"
         echo "idea.log.path=${MOUNT_POINT}/Idea/logs" >> "${HOME}/idea.properties"
         echo "Moved IntelliJ IDEA cache"

         # Creates intelliJ intermediate output folder
         # to be used by java/scala projects
         [ -d "${MOUNT_POINT}"/compileroutput ] || {
            mkdir -p "${MOUNT_POINT}"/compileroutput
            chown -R "${user_name}":admin "${MOUNT_POINT}"/compileroutput
         }
         echo "Use \"${MOUNT_POINT}/compileroutput\" as IntelliJ IDEA compiler output directory"
      fi
   fi
}

# -----------------------------------------------------------------------------------
# The entry point
# -----------------------------------------------------------------------------------
main() {
   check_requirements
   mk_ram_disk
   move_idea_cache

   echo
   echo "All done. Your apps should fly now"
}

main "$@"
# -----------------------------------------------------------------------------------
