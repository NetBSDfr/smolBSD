#!/bin/sh

# https://smarden.org/runit/replaceinit
# switch from /sbin/init to runit!

PKGURL="${PKGSITE:-https://pkg.smolbsd.org/pub/pkgsrc/packages/NetBSD/${ARCH}/${PKGVERS}.0/All}"
RUNPKG=$(curl -L -s ${PKGURL}|sed -nE "s/.*(runit-[a-z0-9\.]+).*/\1/p")

mkdir -p usr/pkg
curl -L -o- -s ${PKGURL}/${RUNPKG} | $TAR zxvfp - --exclude='+*' -C usr/pkg

mkdir -p etc/runit
cp -p usr/pkg/share/examples/runit/openbsd/1 etc/runit/
sed 's/local/pkg/g' usr/pkg/share/examples/runit/openbsd/2 > etc/runit/2
sed 's,/command,/command:/usr/pkg/bin:/usr/pkg/sbin,' \
	usr/pkg/share/examples/runit/openbsd/3 > etc/runit/3
chmod +x etc/runit/[123]
install -m 0500 usr/pkg/sbin/runit* sbin/
mkdir -p etc/sv/getty-0
cat >etc/sv/getty-0/run<<EOF
#!/bin/sh
exec /usr/libexec/getty Pc constty
EOF
cat >etc/sv/getty-0/finish<<EOF
#!/bin/sh
exit 0
EOF
for s in run finish
do
	chmod +x etc/sv/getty-0/$s
done
mkdir -p service
ln -s /etc/sv/getty-0 service/
cp -p sbin/init sbin/init.bsd
cp -p sbin/runit-init sbin/init
