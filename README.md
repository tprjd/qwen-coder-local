# Local Qwen3.8 coding server

This repository runs `TelperionAI/Qwen3.8-27B-EXL3-5.5bpw` through TabbyAPI and ExLlamaV3. The API listens on localhost and requires an API key.

The included configuration targets one NVIDIA RTX 5090 with 32 GB of VRAM. A GPU with less VRAM needs a smaller cache or a different model.

## Install the server

Install these tools first:

- Linux or WSL2 with systemd user services
- An NVIDIA driver that supports CUDA 13
- Git
- Python 3
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- Docker
- `curl`

Clone the repository with its TabbyAPI submodule. Use a path that does not contain spaces.

```bash
git clone --recurse-submodules <repository-url>
cd qwen-coder-local
./setup.sh
```

`setup.sh` performs these actions:

1. It checks out the pinned TabbyAPI revision and applies `patches/tabbyapi-local.patch`.
2. It installs the locked Python 3.12 and CUDA 13 dependencies with uv.
3. It generates local API keys and a SearXNG secret.
4. It downloads the pinned model revision into the Hugging Face cache.
5. It links the model into `models/`.
6. It installs the `qwen-tabbyapi.service` user service.

The model download uses about 20 GB of disk space. The Python environment uses about 6 GB. The setup command does not start the server.

## Run the server

Run these commands from the repository directory:

```bash
./start.sh
./status.sh
./test-api.sh
./stop.sh
```

`start.sh` starts SearXNG and TabbyAPI. The first SearXNG start downloads its Docker image. TabbyAPI can take several minutes to load the model.

The services use these local addresses:

- TabbyAPI: `http://127.0.0.1:5000/v1`
- SearXNG: `http://127.0.0.1:8888`

`start.sh` pins SearXNG to image version `2026.8.22-9fea41204` by its image digest.

Run the longer API checks after the server starts:

```bash
./validate.py
./benchmark.sh 3
```

## Configure OpenCode

Open `run/opencode-provider.json` after setup. Merge its `provider.tabby-local` object into your OpenCode configuration.

Use these OpenCode commands after you merge the configuration:

```bash
opencode run --model tabby-local/qwen3.8-27b-exl3 --variant fast "Explain this repository"
opencode run --model tabby-local/qwen3.8-27b-exl3 --variant normal "Explain this repository"
opencode run --model tabby-local/qwen3.8-27b-exl3 --variant deep "Explain this repository"
```

The OpenCode example connects directly to TabbyAPI on port 5000. It does not require a monitoring proxy.

The original computer has a separate monitoring proxy on port 5100. This repository does not include that proxy. The proxy source has no Git remote, and its directory contains a local metrics database. Publish the proxy as a separate repository before you add it to this setup.

## Change the memory configuration

Stop the service before you edit `config.yml`.

To reduce the context size, change both cache values to the same size:

```yaml
model:
  max_seq_len: 98304
  cache_size: 98304
```

To reduce the KV cache precision, change both cache modes:

```yaml
model:
  cache_mode: "6,6"
draft_model:
  draft_cache_mode: Q6
```

To disable multi-token prediction, set this value:

```yaml
draft_model:
  draft_mode: disabled
```

Restart the service after a configuration change:

```bash
./stop.sh
./start.sh
```

## Keep local data out of Git

The `.gitignore` file excludes API keys, generated SearXNG settings, the Python environment, downloaded models, logs, and runtime files. Do not force-add these files.

The setup pins these source revisions:

- TabbyAPI commit `109629b78bd6a1c04e2a4ba8f7702efa9c99e84a`
- Model revision `af0c885473c466f0f9cf89dfb4d43d475635330c`

Run the repository safety check before each push:

```bash
./scripts/check-repository.sh
```

## Recreate an older SearXNG container

Old installations can expose SearXNG port 8888 on all network interfaces. `status.sh` reports this condition.

Recreate the container once to restrict the port to localhost:

```bash
./stop.sh
docker rm searxng
./start.sh
```

## License

This repository does not include a license. Add a license before you publish the repository as open source.
