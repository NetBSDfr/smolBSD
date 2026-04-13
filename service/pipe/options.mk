.if defined(MINIMIZE) && ${MINIMIZE} == y
ADDPKGS=pkgin pkg_tarup pkg_install sqlite3 rsync curl
.endif
