#!/bin/sh

exec docker run --privileged --network=host \
	-v /dev/snd:/dev/snd \
	ghcr.io/mgoltzsche/pipewire
