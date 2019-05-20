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

ramfs_size_mb=$(sysctl hw.memsize | awk '{print $2;}')
ramfs_size_mb=$((ramfs_size_mb/1024/1024/4))

mount_point=/Users/${USER}/ramdisk
ramfs_size_sectors=$((ramfs_size_mb*1024*1024/512))
ramdisk_device=$(hdid -nomount ram://${ramfs_size_sectors} | xargs)
USERRAMDISK="${mount_point}"

MSG_MOVE_CACHE=". Do you want me to move its cache? Note: It will close the app."
MSG_PROMPT_FOUND="I found "

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
   umount -f "${mount_point}"
   newfs_hfs -v 'ramdisk' "${ramdisk_device}"
   mkdir -p "${mount_point}"
   mount -o noatime -t hfs "${ramdisk_device}" "${mount_point}"

   echo "created RAM disk."
   # Hide RAM disk - we don't really need it to be annoiyng in finder.
   # comment out should you need it.
   hide_ramdisk
   echo "RAM disk hidden"
}

# adds rsync to be executed each 5 min for current user
add_rsync_to_cron()
{
   #todo fixme
   crontab -l | { cat; echo "5 * * * * rsync"; } | crontab -
}

# Open an application
open_app()
{
   osascript -e "tell app \"${1}\" to activate"
}

# Hide RamDisk directory
hide_ramdisk()
{
   /usr/bin/chflags hidden "${mount_point}"
}

# Checks that we have
# all required utils before proceeding
check_requirements()
{
   hash rsync 2>/dev/null || { echo >&2 "No rsync has been found.  Aborting. If you use brew install using: 'brew install rsync'"; exit 1; }
   hash newfs_hfs 2>/dev/null || { echo >&2 "No newfs_hfs has been found.  Aborting."; exit 1; }
}

#
# Check existence of the string in a file.
#
check_string_in_file()
{
   if  grep "${1}" "${2}" == 0; then
      return 0;
   else
      return 1;
   fi
}

#
# Check for the flag
#
check_for_flag()
{
   if [ -e "${1}" ] ; then
      return 0;
   else
      return 1;
   fi
}

#
# Creates flag indicating the apps cache has been moved.
#
make_flag()
{
   echo "" > /Applications/OSX-RAMDisk.app/"${1}"
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
   idea_path=""
   # check default Applications folder
   if [ -d "/Applications/IntelliJ IDEA.app" ]; then
      idea_path="/Applications/IntelliJ IDEA.app"
   fi

   # For jetbrains toolbox a different logic
   if [ -d "${HOME}/Library/Application Support/JetBrains/Toolbox/apps/IDEA-U" ];then
      jetbrains_idea_path="${HOME}/Library/Application Support/JetBrains/Toolbox/apps/IDEA-U"
      idea_channel=$(ls -1 "${jetbrains_idea_path}" | head -1)
      idea_version=$(ls -1 "${jetbrains_idea_path}/${idea_channel}" | sort -r | head -1)
      idea_path="${jetbrains_idea_path}/${idea_channel}/${idea_version}/IntelliJ IDEA.app"
   fi

   if [ -d "${idea_path}" ]; then
      if user_response "${MSG_PROMPT_FOUND}" 'IntelliJ IDEA'"${MSG_MOVE_CACHE}" ; then
         close_app "IntelliJ Idea"
         # make a backup of config - will need it when uninstalling
         cp -f "${idea_path}/Contents/bin/idea.properties" "${idea_path}/Contents/bin/idea.properties.back"
         # Idea will create those dirs
         echo "idea.system.path=${USERRAMDISK}/Idea" >> "${idea_path}/Contents/bin/idea.properties"
         echo "idea.log.path=${USERRAMDISK}/Idea/logs" >> "${idea_path}/Contents/bin/idea.properties"
         echo "Moved IntelliJ cache."
      fi
   fi
}

#
# Creates intelliJ intermediate output folder
# to be used by java/scala projects.
#
create_intermediate_folder_for_intellij_projects()
{
   [ -d "${USERRAMDISK}"/compileroutput ] || mkdir -p "${USERRAMDISK}"/compileroutput
}

# -----------------------------------------------------------------------------------
# The entry point
# -----------------------------------------------------------------------------------
main() {
   check_requirements
   # and create our RAM disk
   mk_ram_disk
   # move the caches
   # move_chrome_cache
   # move_chromium_cache
   # move_safari_cache
   move_idea_cache
   # move_ideace_cache
   # create intermediate folder for intellij projects output
   create_intermediate_folder_for_intellij_projects
   # move_itunes_cache
   # move_android_studio_cache
   # move_clion_cache
   # move_appcode_cache
   # move_xcode_cache
   # move_phpstorm_cache
   echo "echo use \"${mount_point}/compileroutput\" for intelliJ project output directory."
   echo "All good - I have done my job. Your apps should fly."
}

main "$@"
# -----------------------------------------------------------------------------------
