# lhv-tools

"lhv" stands for "Le Holandais Volant" aka [Timo VAN NEERDEN](https://lehollandaisvolant.net/tout/apropos.php).

Here is a translation from his site:

>These online tools are intended to be useful and are for free use. They are without advertising and without trackers. No information entered in pages is recorded by the site; most scripts that do not transmit information to the site and work autonomously in your browser. Most of the tools are made by myself. Otherwise, the author or scripts used are mentioned on their page.`

Go to the [tools's page](https://lehollandaisvolant.net/tout/tools/) to get more information about it.

This smolBSD service downloads and installs these tools during postinstall stage with bozohttp and php.

## Usage

Building on GNU/Linux or MacOS
```sh
$ bmake SERVICE=lhv-tools BUILDMEM=2048 build
```
Building on NetBSD
```sh
$ make SERVICE=lhv-tools BUILDMEM=2048 base
```
Use `BUILDMEM=2048`, otherwise, the `tar` command could hang during postinstall.

Edit `etc/lhv-tools.conf` file as needed, then, start the service:
```sh
./startnb.sh -f etc/lhv-tools.conf
```

Finally, go to [http://localhost:8180](http://localhost:8180) and enjoy:

![homepage](capture.png)
The number of tools differes between this outdated screenshot and reality. It came from the archive and just stand for illustration.

Press `Ctrl+a x` to quit and close the microvm.

Made with ❤.
