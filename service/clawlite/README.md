# smol'd clawlite

This smolBSD service runs the [clawlite][1] AI agent isolated in a minimal `bash` shell environment.

## Installing

Either

* pull the image

```sh
./smoler.sh pull clawlite-amd64:latest
```

* **or** build it

```sh
./smoler.sh build -y smolerfiles/SMOLerfile.clawlite
```

## Running

Pass environment variables with `-e` to configure `clawlite` backend, example for a local inference server:

```sh
./smoler.sh run clawlite-amd64:latest -e OPENAI_BASE_URL=http://192.168.1.2:8001/v1,OPENAI_API_KEY="-"
```

| Variable | Description |
|---|---|
| `OPENAI_BASE_URL` | Base URL of the OpenAI-compatible API endpoint |
| `OPENAI_API_KEY` | API key for authentication |

You also can configure those variables in `~/.config/clawlite/config` inside the microVM.

For further instructions on how to configure and use `clawlite`, checkout [clawlite repository][1] or its [homepage][2]

[1]: https://github.com/kilian-ai/claw
[2]: https://getclaw.site/
