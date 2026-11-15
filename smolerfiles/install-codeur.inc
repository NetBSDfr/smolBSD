# codeur https://codeberg.org/bapt/codeur — tiny AI coding agent in C:
# single binary, OpenAI-compatible APIs (Ollama, vLLM, DeepSeek, OpenAI),
# REPL with streaming markdown, tree-sitter highlighting, tools,
# sub-agents, MCP and persistent memory.
#
# no NetBSD binary release and no usable tag (0.2 is stale: it builds as
# 0.1.0 and fails on NetBSD with struct timeval undeclared in util.h), so
# the source is taken from the main branch archive. It is built with
# ./configure (bbuild) + make + make install, all from the comp set. The
# only required dependency is libcurl, located through pkg-config (pkgsrc
# curl); tree-sitter and the language parsers are vendored in deps/ and
# compiled in. The BSD functions codeur uses (arc4random_buf, strlcpy,
# strlcat, strtonum) are provided by NetBSD libc, so no libbsd is needed.
# universal-ctags speeds up codebase indexing but is not in the pkgsrc 11.0
# repositories (wip only), so codeur uses its regex fallback for symbol
# indexing.
#
# codeur is written against C23 but compiles fine with the base gcc 12.5 of
# the comp set: it already understands [[nodiscard]] and [[maybe_unused]]
# (GCC 10/11), only nullptr, constexpr and the C23 fixed underlying type of
# enums are missing (GCC 13). nullptr and constexpr are shimmed with
# -Dnullptr=NULL -Dconstexpr=const; a sed drops the "enum : int"/
# "enum : unsigned" fixed types and rewrites the file-scope constexpr of
# coordination.h /
# parse_tools.h to static const so they keep their C23 internal linkage
# (plain const would give duplicate definitions). libcurl lives in
# /usr/pkg/lib, outside the runtime linker's default search path, so the
# binary is linked with an rpath on it.
#
# config file: config.ini (see upstream config.ini.sample: url, api_key,
# model in a [provider:...] section) — put it in the -w shared directory,
# pass -E codeurconf=/path/to/config.ini, or run without a config file
# using -e CODEUR_API_URL=...,CODEUR_API_KEY=...,CODEUR_MODEL=...

ARG CODEUR_VERSION="main"
ARG CBREPO=https://codeberg.org/bapt/codeur/archive

RUN pkgin up && pkgin -y in curl pkg-config git-base ripgrep fd-find \
	bash rsync tmux vim

RUN cd /tmp && \
	curl -L -s -o codeur.tgz ${CBREPO}/${CODEUR_VERSION}.tar.gz && \
	tar zxf codeur.tgz && \
	cd codeur && \
	sed -i 's/^constexpr /static const /; s/enum *: *int/enum/g; s/enum *: *unsigned/enum/g' src/*.c src/*.h && \
	./configure --prefix=/usr/pkg && \
	make CFLAGS="-O2 -Dnullptr=NULL -Dconstexpr=const" \
		LDFLAGS="-Wl,-rpath,/usr/pkg/lib" && \
	make install && \
	cd / && rm -rf /tmp/codeur /tmp/codeur.tgz
