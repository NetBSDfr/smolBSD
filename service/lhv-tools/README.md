<div align="center" markdown="1">
<img src="logo.svg" height="150px">
</div>

# lhv-tools

## Introduction

"lhv" stands for "Le Holandais Volant" aka [Timo VAN NEERDEN](https://lehollandaisvolant.net/tout/apropos.php) an IT guy.

Here is a free translation from his site:

>These online tools are intended to be useful and are for free use. They are without advertising and without trackers. No information entered in pages is recorded by the site; most scripts that do not transmit information to the site and work autonomously in your browser. Most of the tools are made by myself. Otherwise, the author or scripts used are mentioned on their page.`


You can find tools to:
- create QR-codes,
- convert dates into several formats,
- convert temperatures units,
- generate passwords,
- calculate checksums,
- play 2048, Tetris, mahjong, etc...,
- learn kanas,
- see spectrum of an audio file,
- find the RSS link of a youtube channel,
- edit images,
- etc... in your browser.

More than 150 tools for multiple activities. 

Go to the [tools's page](https://lehollandaisvolant.net/tout/tools/) to get more information.

This smolBSD service downloads and installs these tools during postinstall stage with bozohttp and php.

## Prerequisites

Many tools from Le Hollandais Volant work with php. Essential/minimal packages to run them correctly are listed in the `options.mk` file. smolBSD downloads packages from [http://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/x86_64/11.0/All/](http://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/x86_64/11.0/All/). Check this page to know the version-named package of php you need. There is no meta-package to installing the latest version like `pkgin install php`.

For now, it's `php84`, `php84-curl`, etc...

Also, feel free to edit `etc/lhv-tools.conf` file as needed.

## Usage

Building on GNU/Linux or MacOS
```sh
$ bmake SERVICE=lhv-tools BUILDMEM=2048 build
```
Building on NetBSD
```sh
$ make SERVICE=lhv-tools BUILDMEM=2048 base
```
Use `BUILDMEM=2048` at least, otherwise, the `tar` command could hang during postinstall.

Start the service:
```sh
./startnb.sh -f etc/lhv-tools.conf
```

Finally, go to [http://localhost:8180](http://localhost:8180) and enjoy:

![homepage](capture.png)
*The number of tools differes between this outdated screenshot and reality. It came from the archive and just stand for illustration.*

Press `Ctrl+a x` to quit and close the microvm.

Service made with ❤.
