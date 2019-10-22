# backup-tablo.sh
Backup all recorded shows from a Tablo DVR without downtime.

This script will make a backup of your Tablo DVR's recorded shows.  It can optionally keep a copy of deleted shows for a configurable number of days; by default, it will keep 14 days of deleted shows.

It uses the exposed Tablo webserver directory /pvr/ via port 18080 \
See: https://community.tablotv.com/t/where-is-the-guide-and-scheduled-recording-data-saved/17824/6

To view your Tablo recordings, navigate to http://tablo.lan.ip.address:18080/pvr/ \
_(replace tablo.lan.ip.address with your Tablo's ip address)_

This script is not perfect.  I have not found a way to access the show log/ folders (I get Error 404 - access forbidden), but the missing log folders does not seem to affect playback after a restore.  I also can not figure out how to remotely access the Tablo database.  Please let me know if there is a way to download the Tablo.db file in realtime or even a way to re-create it (without pressing reset and disconnecting the drive to copy it :-)

&nbsp;

## Requirements to use this script:
* a Linux OS with bash 4.4 or greater
* needed utilities: ts, find, rm, tail, kill, ps, lftp, awk, ls, mkdir, mv

_Most of these are probably included by default with your OS (find, rm, tail, kill, ps, awk, ls, mkdir, mv), some will need to be installed (probably lftp, ts)_

install lftp and ts on Ubuntu:
<pre>apt update && apt install lftp moreutils</pre>

&nbsp;

### Usage:
<pre>
backup-tablo.sh [-l | --log]
</pre>

Simply copy this script anywhere you have write access and give it execute permissions or run it via the bash command.
<pre>
(clone or copy the script to) /usr/local/bin/backups/backup-tablo.sh
chmod +x /usr/local/bin/backups/backup-tablo.sh
/usr/local/bin/backups/backup-tablo.sh
</pre>

### Edit global variables before running:
<pre>
tablo_ip_or_host="192.168.0.32"                 #ip address (or hostname) of tablo device
path_backups="/mnt/backups/tablo/rec"           #where to store your tablo shows
path_deleted="/mnt/backups/tablo/deleted"       #where to store your deleted tablo shows 
</pre>

### Example cron entry:
<pre>
# 2am every day -- backup tablo recordings
0      2       *       *       *       /usr/local/bin/backups/backup-tablo.sh --log
</pre>

### Manual show recovery:
Unfortunately, I do not know a way to restore the shows directly to a Tablo without downtime.  However, I have successfully restored all of my Tablo shows to a replacement drive and it seems to work just fine.

* Turn off the Tablo
* Install a new (or freshly erased) hard drive into the Tablo device
* Use a client (Roku, phone, etc.) to format the newly installed drive \
  _This will create a Tablo file structure on the new drive; necessarily the /rec/ directory_
* Turn off the Tablo and attach the new drive to your Linux computer \
  _use dmesg, blkid, lsblk, etc. to find the new drive (replace sdX1 below with the proper drive letter)_
<pre>
mkdir /tmp/sdX1
mount /dev/sdX1 /tmp/sdX1
</pre>
* Copy the shows to the new drive's /rec/ folder (cp, rsync, etc.)
<pre>
rsync -a --info=progress2 --no-inc-recursive /mnt/backups/tablo/rec/ /tmp/sdX1/rec/
</pre>

### NOTES:
* Tablo seems to store the recording schedules on internal storage (not the attached hard drive). \
As an example, if you replace the hard drive, your recording schedules are still intact and *should* record normally.

* Tablo seems to store the list of available shows to watch on internal storage (not the attached drive). \
As an example, if you replace the hard drive, the tablo still thinks your shows are available.  When you try to play one, it will give an error message saying the show is not found/available and offers to delete it for you.

* You can get a copy of the internal database by having a drive attached while pressing the reset button on the tablo. \
When you remove the drive, the file system contains a new folder named /db/ with several files inside, notably "Tablo.db".  I have not studied this database in detail, but it appears to be a SQLite version 3 database file.
