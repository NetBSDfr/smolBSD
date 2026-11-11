#!/bin/sh
# 9p small-file benchmark.  Run inside the guest with the 9p mount at $1.
# One line per test on stdout: "BENCH <label> files=<n> real=<s> rc=<rc>"
# Parse on the host; per-file costs are computed there, not on the guest.

M=${1:-/mnt}
S=$M/bench
O=$M/bench_out
TIME=/usr/bin/time

run() {
	label=$1; n=$2; shift 2
	t0=$(date +%s)
	if [ -x $TIME ]; then
		$TIME -p sh -c "$*" 2>/tmp/bench.time >/dev/null
		rc=$?
		real=$(grep '^real' /tmp/bench.time | head -1 \
		    | tr -s ' \t' ' ' | cut -d' ' -f2 | tr -cd '0-9.')
	else
		sh -c "$*" >/dev/null 2>&1
		rc=$?
		real=
	fi
	[ -n "$real" ] || real=NA
	t1=$(date +%s)
	echo "BENCH $label files=$n real=$real secs=$((t1 - t0)) rc=$rc"
}

[ -d "$S/f" ] || { echo "BENCH abort: no $S"; exit 1; }

# 1. pure metadata: one stat process, 2000 lookups + gets
run stat_glob 2000 "stat -f %z $S/f/f* >/dev/null"

# 2. data path small files: one cat process, 2000 open/read/close
run cat_small 2000 "cat $S/f/f* >/dev/null"

# 3. directory listing, cold vs warm (name cache roundtrip test)
run ls_cold 2000 "ls -l $M/bigdir >/dev/null"
run ls_warm 2000 "ls -l $M/bigdir >/dev/null"

# 4. create+write+close x500 (shell builtins: one process, 500 file ops)
rm -rf $O 2>/dev/null; mkdir -p $O
run write500 500 'i=1; while [ $i -le 500 ]; do echo hello-$i > '$O'/o$i; i=$((i+1)); done'

# 5. unlink x500 (one rm process, 500 removes)
run unlink500 500 "rm -f $O/o*"

# 6. mid-size reads: 200 x 8K in one cat
run cat_8k 200 "cat $S/med/m* >/dev/null"

# 7. sequential big read: 1 MB (shows msize chunking cost)
run dd_1m 1 "dd if=$S/big1m of=/dev/null bs=65536"

echo "BENCH done"
