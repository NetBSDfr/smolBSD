<div align="center" markdown="1">

**Running smolClaw with a local inference server**

<img src="images/smolTelegram.png">

</div>

As of 2026-03 I use [this model](https://huggingface.co/Jackrong/Qwen3.5-9B-Claude-4.6-Opus-Reasoning-Distilled-GGUF) with an RTX 5080 (16GB).

Refer to [this recipe][1] to fix the local model for tooling. I start [llama.cpp with CUDA][2] like this:
```sh
./llama-server -hf Jackrong/Qwen3.5-9B-Claude-4.6-Opus-Reasoning-Distilled-GGUF:Q4_K_M -ngl 99 -c 262144 -np 1 -fa on --cache-type-k q4_0 --cache-type-v q4_0 --chat-templat
e-file qwen3.5_chat_template.jinja --port 8001 --host 0.0.0.0
```

Example [picoclaw][3] `config.json`, modify:

* `YOUR_TELEGRAM_TOKEN`, on Telegram, create a `/newbot` speaking to `@BotFather`
* Ollama's IP address

```json
{
  "agents": {
    "defaults": {
      "workspace": "~/.picoclaw/workspace",
      "restrict_to_workspace": false,
      "model": "qwen3.5",
      "max_tokens": 8192,
      "temperature": 0.7,
      "max_tool_iterations": 20
    }
  },
  "model_list": [
    {
      "model_name": "qwen3.5",
      "model": "ollama/Jackrong/Qwen3.5-9B-Claude-4.6-Opus-Reasoning-Distilled-GGUF:Q8_0",
      "api_base": "http://192.168.1.1:8001/v1",
      "api_key": "-"
    }
  ],
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "YOUR_BOT_TOKEN",
      "allow_from": ["YOUR_USER_ID"]
    }
  },
  "gateway": {
    "host": "0.0.0.0",
    "port": 18790
  },
  "tools": {
    "web": {
      "brave": {
        "enabled": false,
        "api_key": "",
        "max_results": 5
      },
      "duckduckgo": {
        "enabled": true,
        "max_results": 5
      }
    }
  },
  "devices": {
    "enabled": false,
    "monitor_usb": false
  },
  "heartbeat": {
    "enabled": true,
    "interval": 30
  }
}
```

Refs:

* https://x.com/sudoingX/status/2028496331992707373
* https://x.com/sudoingX/status/2030253886649569299

[1]: https://gist.github.com/sudoingX/c2facf7d8f7608c65c1024ef3b22d431
[2]: https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md#cuda
[3]: https://github.com/sipeed/picoclaw
