# crush https://github.com/charmbracelet/crush — Go TUI coding agent from
# charmbracelet. Upstream publishes NetBSD release binaries; the tarball is
# extracted straight into /usr/pkg/bin.
#
# config file: crush.json — put it in the -w shared directory, or pass
# -E crush=/path/to/crush.json

ARG CRUSH_VERSION="0.102.0"
ARG CRUSH_ARCH=$(uname -p|sed 's/aarch64/arm64/')

RUN pkgin up && pkgin -y in curl git-base ripgrep fd-find gh bash rsync python314

RUN mkdir -p /usr/pkg/bin && \
	curl -L -s -o- \
		https://github.com/charmbracelet/crush/releases/download/v${CRUSH_VERSION}/crush_${CRUSH_VERSION}_Netbsd_${CRUSH_ARCH}.tar.gz | \
		tar zxf - -C /usr/pkg/bin --strip-components=1 crush_${CRUSH_VERSION}_Netbsd_${CRUSH_ARCH}/crush
