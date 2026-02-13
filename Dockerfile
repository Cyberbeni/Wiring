FROM --platform=$BUILDPLATFORM docker.io/cyberbeni/swift-builder:latest AS swift-build
WORKDIR /workspace
COPY ./Package.swift ./Package.resolved /workspace/
RUN --mount=type=cache,target=/workspace/.spm-cache,id=spm-cache \
	swift package \
		--cache-path /workspace/.spm-cache \
		--only-use-versions-from-resolved-file \
		resolve

COPY ./scripts /workspace/scripts
COPY ./Sources /workspace/Sources
ARG TARGETPLATFORM
RUN --mount=type=cache,target=/workspace/.build,id=build-$TARGETPLATFORM \
	--mount=type=cache,target=/workspace/.spm-cache,id=spm-cache \
	scripts/build-release.sh && \
	mkdir -p dist && \
	cp .build/release/Wiring dist

FROM docker.io/alpine:latest AS release
# https://pkgs.alpinelinux.org/contents
# ping: iputils-ping
# arp: net-tools
RUN apk add --no-cache \
	iputils-ping \
	net-tools \
	tzdata
COPY --from=build /workspace/dist/Wiring /usr/local/bin/wiring
ENTRYPOINT ["/usr/local/bin/wiring"]
