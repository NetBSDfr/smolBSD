# smol'd [ttyd][1]: secure HTTP shell

[ttyd][1] is a neat piece of software that allows you to spawn a remote shell on a simple web browser.

The `ttyd` _smolBSD_ service isolates this shell in a _microVM_.

# Installation

Fetch it

Linux:

```sh
$ ./smoler.sh pull ttyd-amd64:latest
```

Mac:

```sh
$ ./smoler.sh pull ttyd-evbarm-aarch64:latest
```

**Or** build it

```sh
$ ./smoler.sh build -y smolerfiles/SMOLerfile.ttyd
```

# Usage

```sh
$ ./smoler.sh run ttyd-amd64:latest # or ttyd-evbarm-aarch64:latest on Mac 
```

By default `ttyd` listens on port `7681`, you can change this by editing `etc/ttyd.conf`

[1]: https://github.com/tsl0922/ttyd
