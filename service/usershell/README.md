# User Shell Service

## About

This microservice starts a minimal user shell (`ksh`).

It comes with all typical _BSD_ shell tools and can also be used as an _SSH_ client.  
Its size is about 50MB and can be loaded as an `initrd` / RAM disk with `startnb.sh` `-I` parameter.

This image is built with `MINIMIZE=y`, [sailor](https://github.com/NetBSDfr/sailor) `git clone` is needed
before building.

## Usage

**Build**

```sh
$ bmake SERVICE=usershell build
```

**Run**

```sh
$ ./startnb.sh -f etc/usershell.conf
```
