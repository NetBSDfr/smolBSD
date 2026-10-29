#!/bin/sh


export CHOUPI=y
. ../service/common/funcs
. ../service/common/choupi

chroot . su root -c "cd / && pkgin up && pkgin -y in fluxbox"
chroot . su root -c "cd / && mkdir -p /usr/pkg/etc/fonts &&  cp /usr/pkg/share/examples/fontconfig/fonts.conf  /usr/pkg/etc/fonts/fonts.conf"
chroot . su root -c "cd / && mkdir -p /root/.fluxbox &&  printf 'background: none\n' > /root/.fluxbox/overlay"
chroot . su root -c "cd / && printf '%s\n' 'export DISPLAY=:1'  'export PATH=\$PATH:/usr/X11R7/bin:/usr/pkg/bin' >> /etc/profile"
export LD_LIBRARY_PATH=/usr/X11R7/lib
