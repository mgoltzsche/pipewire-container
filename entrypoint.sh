#!/bin/sh

id

: ${PIPEWIRE_SOUNDCARD:=0}

set -eux

# See https://madskjeldgaard.dk/posts/raspi-zita-njbridge/
# and https://jackaudio.org/faq/linux_rt_config.html
aplay -l

#jackd -dalsa "-dhw:$PIPEWIRE_SOUNDCARD" -r48000 -p256 -n2
exec pipewire -c /etc/pipewire.conf
