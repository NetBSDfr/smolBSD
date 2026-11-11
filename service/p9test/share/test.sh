#!/bin/sh
# 9p correctness/stress test. Output appended to /tmp/report.txt (fd held
# open on local disk so /mnt can be unmounted during remount stress);
# xtrace goes to console so serial pinpoints a hang.
R=/tmp/report.txt
set -x
exec >>$R 2>/dev/console
echo "===== 9p test: $(date) ====="

echo "--- mount ---"
mount | grep -i '9p' || echo "WARN: no 9p mount in mount table"

echo "--- bigdir ---"
echo "file count: $(ls /mnt/bigdir | wc -l)"
t0=$(date +%s)
ls -l /mnt/bigdir > /dev/null 2>&1
echo "ls -l bigdir: rc=$? time=$(( $(date +%s) - t0 ))s"

echo "--- stat of hostfile (host: uid=1000 gid=1000 mode=0750 size=20) ---"
stat -f '%N uid=%u gid=%g mode=%p size=%z mtime=%m' /mnt/hostfile

echo "--- symlink (host: symlink -> hostfile) ---"
ls -ld /mnt/symlink 2>&1
stat -f 'symlink type=%T' /mnt/symlink 2>&1
readlink /mnt/symlink 2>&1

echo "--- guest symlink create/readlink/remove ---"
rm -f /mnt/newlink
ln -s hostfile /mnt/newlink 2>&1 \
	&& echo "symlink create: ok, readlink=$(readlink /mnt/newlink)" \
	|| echo "symlink create: FAIL"
stat -f 'newlink type=%T mode=%p' /mnt/newlink 2>&1
rm -f /mnt/newlink && echo "newlink removed"

echo "--- guest chown/chmod (expect host to see uid/gid 1000, mode 640) ---"
echo chownme > /mnt/gown.txt
chown 1000:1000 /mnt/gown.txt 2>&1
chmod 0640 /mnt/gown.txt 2>&1
stat -f 'gown.txt uid=%u gid=%g mode=%p' /mnt/gown.txt
rm -f /mnt/gown.txt

echo "--- guest->host write ---"
echo hello-from-guest > /mnt/guestfile.txt
echo "guestfile read-back: $(cat /mnt/guestfile.txt) rc=$?"
stat -f 'guestfile size=%z' /mnt/guestfile.txt
rm -f /mnt/guestfile.txt

echo "--- mkdir/create/rename/rmdir ---"
( mkdir /mnt/gdir && touch /mnt/gdir/f1 && mv /mnt/gdir/f1 /mnt/gdir/f2 \
  && ls /mnt/gdir && rm -f /mnt/gdir/f2 && rmdir /mnt/gdir ) \
  && echo "dir ops: OK" || echo "dir ops: FAIL rc=$?"

echo "--- staleness (sleep 15; host appends to hostfile meanwhile) ---"
echo "stat size before: $(stat -f %z /mnt/hostfile)"
sleep 15
echo "stat size after:  $(stat -f %z /mnt/hostfile)"
echo "read bytes after: $(wc -c < /mnt/hostfile)"

echo "--- 30x ls -l bigdir stress ---"
i=0
while [ $i -lt 30 ]; do
	ls -l /mnt/bigdir > /dev/null 2>&1 || echo "ls failed iter $i rc=$?"
	i=$((i+1))
done
echo "stress done"

echo "--- remount stress (10x umount/mount) ---"
i=0
while [ $i -lt 10 ]; do
	umount /mnt || { echo "umount failed iter $i rc=$?"; break; }
	sleep 1   # let the old server process fully exit (EBUSY window)
	mount_9p -cu /dev/vio9p0 /mnt || { echo "mount failed iter $i rc=$?"; break; }
	sleep 1   # let new server become ready
	ls /mnt/bigdir | wc -l | grep -q 2000 || { echo "remount $i: ls wrong"; break; }
	i=$((i+1))
done
echo "remount stress done: $i/10"

echo "--- bigdir count again ---"
echo "file count: $(ls /mnt/bigdir | wc -l)"

echo "===== done: $(date) ====="
cp $R /mnt/report.txt
