#!/bin/bash

# Copyright (C) 2019 Robert Chavers
#
# Distributed under the MIT License.
# (See accompanying LICENSE file or http://opensource.org/licenses/MIT)

## requirements to use this script:
##   bash 4.4 or greater
## external utilities:
##   ts, find, rm, tail, kill, ps, lftp, awk, ls, mkdir, mv

## restore command example:
## mkdir /tmp/sdX1
## mount /dev/sdX1 /tmp/sdX1
## rsync -a --info=progress2 --no-inc-recursive /mnt/backups/tablo/rec/ /tmp/sdX1/rec/
## umount /tmp/sdX1

##
## variables you will most likely need to change
##
tablo_ip_or_host="192.168.0.32"			#ip address (or hostname) of tablo device
path_backups="/mnt/backups/tablo/rec"		#where to store your tablo shows
path_deleted="/mnt/backups/tablo/deleted"	#where to store your deleted tablo shows
path_logfile="/mnt/backups/tablo/log/backup-tablo.log"		#the location of the log file

path_pidfile="/tmp/backup-tablo.pid"			#the temporary pid file while the program is running
max_log_lines=1000				#number of old lines to keep in path_logfile before the program runs
log_to_file=0					#set to 1 to always log to path_logfile (or call program with --log argument)
days_to_keep_deleted="14"			#use 0 for unlimited days


## example cron entry
##
#2am every day -- backup tablo recordings
#0	2	*	*	*	/usr/local/bin/backups/backup-tablo.sh --log


##
## global variables (no need to change these)
##
files_tablo=()
files_backup=()
files_deleted=()
need_to_delete=()


##
## startup checks
##

# process program arguments
#
while [ "$1" != "" ]; do
  case $1 in
    -l | --log )
      # log output to $path_logfile
      log_to_file=1
      ;;
  esac
  shift
done

# check if we are already running
# first time running this program can take days since tablo only has 10/100 ethernet
# subsequent running is much quicker.  you can safely stop and restart this program
#
if [ -e $path_pidfile ]; then
  pid="$(<${path_pidfile})"
  # kill -0 just checks if we *can* kill, it does not send a kill signal
  # basically, this is just testing to see if the process is really running
  if /bin/kill -0 &>1 > /dev/null ${pid}; then
    #get runtime in seconds of pid
    runtime=$(( $(/bin/ps -o etimes= -p "${pid}") ))
    echo "WARNING: $0 (PID ${pid}) was started ${runtime} seconds ago; will not continue."
    exit 0
  else
    #not already running, so remove orphan path_pidfile
    /bin/rm ${path_pidfile}
  fi
fi
trap "/bin/rm ${path_pidfile}; exit" INT TERM EXIT
echo $$ >${path_pidfile}

# prune the path_logfile to a max size of $max_log_lines
#
if (( ${log_to_file} )); then
  echo "$(/usr/bin/tail -n $max_log_lines $path_logfile)" > $path_logfile
fi



##
## function definitions
##

mylog () {
  # simple log funtion to capture date and time in output
  tstamp=$(echo|/usr/bin/ts '[%Y-%m-%d %H:%M:%S]')
  if (( ${log_to_file} )); then
    echo "${tstamp}${1}" >> $path_logfile
  else
    echo "${tstamp}${1}"
  fi
}

get_tablo_shows () {
  # get list of shows on the tablo
  files_tablo=($(/usr/bin/lftp -c "open http://$tablo_ip_or_host:18080; ls /pvr/" | /usr/bin/awk '{print $4}'))
  mylog "number of current shows on your tablo: ${#files_tablo[@]}"
  #mylog "list of current shows on your tablo:"
  #mylog "${files_tablo[*]}"
}

get_backup_shows () {
  # get list of shows already backed up
  files_backup=($(/bin/ls $path_backups))
  mylog "number of backed up shows on this computer: ${#files_backup[@]}"
  #mylog "list of backed up shows on this computer:"
  #mylog "${files_backup[*]}"
}

get_deleted_shows () {
  # get list of shows that have been deleted from
  # the tablo but have already been backed up here
  files_deleted=()
  for i in ${files_backup[@]}; do
    skip=
    for j in ${files_tablo[@]}; do
      [[ $i == $j ]] && { skip=1; break; }
    done
    [[ -n $skip ]] || files_deleted+=("$i")
  done
  mylog "number of shows deleted from your tablo since the last backup: ${#files_deleted[*]}"
  #mylog "list of shows deleted from your tablo since the last backup:"
  #mylog "${files_deleted[*]}"
}

process_deleted_shows () {
  # 1)move deleted tablo shows to the deleted folder
  # 2)erase shows older than $days_to_keep_deleted

  # create path_deleted if it does not already exist
  /bin/mkdir -p $path_deleted

  # move the newly deleted shows to $path_deleted
  for i in ${files_deleted[@]}; do
    mylog "moving $path_backups/$i to $path_deleted/$i"
    /bin/mv $path_backups/$i $path_deleted/$i
  done

  # really erase shows that were moved to deleted after the days_to_keep_deleted has passed
  if [ "$days_to_keep_deleted" != "0" ]; then
    # you *must* have bash 4.4 or greater to use 'mapfile -d'
    mapfile -d '' need_to_delete < <(/usr/bin/find ${path_deleted}/* -maxdepth 0 -type d -ctime +${days_to_keep_deleted})
    for i in ${need_to_delete[@]}; do
      mylog "deleting show that was deleted from tablo more than $days_to_keep_deleted days: $i"
      /bin/rm -rf $i
    done
  fi
}

backup_tablo () {
  # mirror the /pvr/ directory from the tablo webserver to our local directory
  lftp_cmd="open http://${tablo_ip_or_host}:18080; mirror --verbose=1 --exclude [^/]+/log/$ --exclude [^/]+/tmp/$ --delete /pvr/ ${path_backups}"
  if (( $log_to_file )); then
    /usr/bin/lftp -c "${lftp_cmd}" 2>&1 | /usr/bin/ts '[%Y-%m-%d %H:%M:%S]' >> $path_logfile
  else
    /usr/bin/lftp -c "${lftp_cmd}" 2>&1 | /usr/bin/ts '[%Y-%m-%d %H:%M:%S]'
  fi
}



##
## main program code
##

mylog "----------started----------"

# get the list of shows currently on the tablo device
get_tablo_shows

# get the list of shows that have already been backed up here
get_backup_shows

# get the list of shows that were deleted from the tablo, but are still backed up here
get_deleted_shows

# keep a copy of newly deleted shows and erase shows older than $days_to_keep_deleted
process_deleted_shows

# mirror the current shows on the tablo device to this computer
backup_tablo

mylog "---------completed---------"
