ARG ZITA_RESAMPLER_VERSION=1.6.2

FROM alpine:3.14 AS zita-njbridge-build
RUN apk add --update --no-cache tar make gcc g++ musl-dev libstdc++ jack-dev
ARG ZITA_RESAMPLER_VERSION
RUN set -eux; \
	mkdir -p /zita-resampler; \
	cd /zita-resampler; \
	wget -O - https://kokkinizita.linuxaudio.org/linuxaudio/downloads/zita-resampler-${ZITA_RESAMPLER_VERSION}.tar.bz2 | tar -xjf -
WORKDIR /zita-resampler
RUN set -eux; \
	cd zita-resampler-$ZITA_RESAMPLER_VERSION/source; \
	make; \
	printf '#!/bin/sh\ntrue' >/usr/local/bin/ldconfig; \
	chmod +x /usr/local/bin/ldconfig; \
	make install LIBDIR=/usr/local/lib; \
	ln -s /usr/local/lib/libzita-resampler.so.$ZITA_RESAMPLER_VERSION /usr/local/lib/libzita-resampler.so.1
ARG ZITA_NJBRIDGE_VERSION=0.4.8
RUN set -eux; \
	mkdir -p /zita-njbridge; \
	cd /zita-njbridge; \
	wget -O - https://kokkinizita.linuxaudio.org/linuxaudio/downloads/zita-njbridge-${ZITA_NJBRIDGE_VERSION}.tar.bz2 | tar -xjf -
WORKDIR /zita-njbridge
RUN set -eux; \
	cd zita-njbridge-$ZITA_NJBRIDGE_VERSION/source; \
	make; \
	make install

FROM alpine:3.14
RUN apk add --update --no-cache pipewire pipewire-media-session pipewire-jack pipewire-pulse alsa-utils
ARG ZITA_RESAMPLER_VERSION
RUN set -ex; \
	delgroup audio; \
	addgroup -g 29 audio; \
	adduser -D -u 4242 pipewire audio; \
	cp /usr/lib/pipewire-0.3/jack/* /usr/lib/
#COPY audio.conf /etc/security/limits.d/
COPY --from=zita-njbridge-build /usr/local /usr/local
COPY pipewire.conf /etc/pipewire.conf
COPY entrypoint.sh /
# See https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-JACK
ENV PIPEWIRE_LATENCY="256/48000 jack_lsp" \
    PIPEWIRE_PROPS="media.class=Audio/Sink"
#USER pipewire:audio
ENTRYPOINT [ "/entrypoint.sh" ]

# run: docker run --rm --privileged --device /dev/snd:/dev/snd -v /dev/shm:/dev/shm -e JACK_SOUNDCARD=0 mgoltzsche/pipewire
# client (mopidy) may need to be run with --ipc=host in order to be able to share memory with jack