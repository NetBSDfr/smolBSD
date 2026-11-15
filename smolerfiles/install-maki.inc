# maki https://github.com/tontinton/maki — Rust TUI coding agent with Lua
# configuration. NetBSD release binaries are published in the repo (local
# fixes applied there — upstream has no NetBSD builds: maki is Rust edition
# 2024, needs rust 1.88+, and the release assets are produced by a NetBSD
# build: C toolchain plus rust-bin, openssl, perl, python (pyo3/monty),
# pkgconfig and git; GNU make on the path for isahc's static-curl build;
# luau force-includes <limits>; libc crate lacks nl_langinfo_l bindings on
# netbsd so clock.rs declares it extern "C"; CARGO_BUILD_JOBS=1 after a
# separate cargo fetch (parallel rustc spawns ENOENT).
#
# config file: init.lua — the project's .maki/init.lua is picked up
# automatically; a global config comes from the -w shared directory or
# -E makiconf=/path/to/init.lua

ARG MAKI_VERSION="0.7.2"

ARG GHARCH=$(uname -p)
# repo with the NetBSD release binaries
ARG GHREPO=https://github.com/tontinton/maki/releases/download

RUN pkgin up && pkgin -y in curl git-base ripgrep fd-find gh bash rsync \
	tmux openssl perl python314 gmake

RUN curl -L -s -o- ${GHREPO}/v${MAKI_VERSION}/maki-v${MAKI_VERSION}-${GHARCH}-unknown-netbsd.tar.gz | \
        tar zxf - -C /usr/pkg/bin maki
