# smolset carries the patched mount_9p client: the stock NetBSD 11
# mount_9p asserts in puffs9p_node_reclaim (dir_openlist) under build
# load, corrupting /mnt reads (truncated scripts, vanishing dirs)
SETS=base.${SETSEXT} etc.${SETSEXT} comp.${SETSEXT}:/usr/bin/strip smolset.tar.xz
MOUNTRO=y
ADDPKGS=pkgin pkg_tarup pkg_install sqlite3
