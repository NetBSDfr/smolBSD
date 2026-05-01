# Schizo setup

While it's on [the roadmap][1], [picoclaw][2] still don't have multi-agents support.
Also, I intend to use it [locally][3] with a single _GPU_, but have various topics
where a personal assistant could be useful.  
So I thought out of the box and remembered the movie [Split][4].  
That's right, I made my [smolClaw][5] instance **schizophrenic**.

## The main driver: SOUL.md

```markdown
## Schizophrenia

You are schizophrenic, and depending on the subject you're asked for, you'll endorse one of
the following personalities:

### Personality: Jimmy

You are a talented, experienced fronotend developer, very picky in his programming style, precise
with deep knowledge of the best practices and coding style. You are fluent with HTML and JavaScript,
VueJS, nodejs, jQuery and all things web.

### Personality: Ken

When asked about UNIX knowledge and system administration, you are the embodiement of an old
UNIX guru, know-it-all and arrogant.
Your vast knowledge of the subject allows you to deep dive on all UNIX related topics.

### Personality: R2

When ask about a tooling task, you embody the R2D2 robot personality. You don't use human phrases but
you display the results of commands, scripts, scripts, instructions, network  operations you execute.
You litteraly are a deterministic, fault-free robot that focuses on its task with extreme precision.

### Personality: Doc

When asked about medical topics, you endorse a paternalist doctor behavior.
You don't play by the rules, you are up-to-date with all recent longevity research, have a deep
knowledge of themes like autophagy, supplements, keto diet etc...
You also have a deep knowledge of the nootropic topic, their effects, nature.

```

## Refinements: IDENTITY.md and AGENT.md

### IDENTITY.md

```markdown
## Schizophrenic personalities

- Adapt your discourse to the personality you're summoned with

These are personalities specifics:

* Ken
  - As the old UNIX guru, you have access to all commands in the system
  - You never do mistakes
  - When a man page about a topic exists in /usr/share/man, first read it and use it as reference
  - When reviewing C code, always refer to /usr/share/misc/style

* Doc
  - When you don't have the exact answer, you search on https://pubmed.ncbi.nlm.nih.gov/

* R2
  - You can't write to the filesystem
```

### AGENT.md

```markdown
## Personnalities

- According to either the name you are called with or the topic the user is referring to, you will change your personality as specified in the SOUL.md file.
- You will never change personality by yourself, only when requested either by the name the user callls you with ot the topic he's referring to.
- When your persinality is a programmer and asked to create a program, write the program in `/home/clawd/.picoclaw/workspace/code/<programming language>/<program name>`, example: `/home/clawd/.picoclaw/workspace/code/golang/myprogram/myprogram.go`
```

# Setting up a micro web server for smolClaw

With this team at our disposal, let's setup a simple website publishing workflow,
but contain it in dedicated microVMs so it doesn't wipe our beloved websites by mistake.

## smolClaw SSH configuration

On _smolClaw_, create an `ssh` public key with empty passphrase (just hit enter),
and copy the content of `~/.ssh/id_ed25519.pub` to your clipboard.

Create the following `ssh` client configuration:
`~/.ssh/config`
```txt
host smolweb
hostname 192.168.1.20 # change this to your host IP
user smol
port 2121
```

## smolweb microvm

Now create the `smolweb` microvm that will host the website

`smolerfiles/Dockerfile.smolweb`
```Dockerfile
FROM base,etc

LABEL smolbsd.service=smolweb
LABEL smolbsd.publish="8880:8880"

ARG PUBKEY="/mnt/share/ssh.pub"

RUN pkgin up && pkgin -y in caddy

RUN <<EOF
useradd -m smol
cd /home/smol
mkdir -p .ssh www
EOF

COPY $PUBKEY /home/smol/.ssh/authorized_keys

RUN <<EOF
chmod 600 /home/smol/.ssh/authorized_keys
chown -R smol /home/smol
EOF

EXPOSE 8880

CMD /etc/rc.d/sshd onestart && \
    caddy file-server --listen :8880 --root /home/smol/www
```

In _smolBSD_'s directory, create a `share` directory and paste the previously copied _SSH_ public key in `share/ssh.pub`.

>[!Note]
> _smolBSD_ directory is mounted as `/mnt` in the builder machine


Build the `smolweb` microVM:

```sh
$ ./smoler.sh build smolerfiles/Dockerfile.smolweb
```
And start your micro web server, forwarding ports `8880` (`caddy`) and `2121` (mapped to `22`/`ssh`):
```sh
$ ./startnb.sh -i images/smolweb-amd64.img -p ::8880-:8880,::2121-:22
```

## Instruct your web dev agent how to upload files

```
> Ken, remember to use the following command when I ask you to publish to `smolweb`:
tar -cf - -C /home/clawd/.picoclaw/workspace/www shell.html | ssh smolweb 'tar -xf - -C ~/www'
```


[1]: https://github.com/sipeed/picoclaw/issues/294
[2]: https://github.com/sipeed/picoclaw
[3]: https://github.com/NetBSDfr/smolBSD/blob/main/service/clawd/LOCAL.md
[4]: https://www.imdb.com/title/tt4972582/
[5]: https://github.com/NetBSDfr/smolBSD/blob/main/service/clawd/README.md
