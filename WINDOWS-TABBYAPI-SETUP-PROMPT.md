# Native Windows TabbyAPI setup prompt

Copy the prompt below into your Windows agent. It sets up only TabbyAPI and the specified model. It does not use this repository's Linux or WSL automation.

```text
Set up one local Qwen3.8 inference server on native Windows.

Do not use WSL2, Docker, SearXNG, OpenCode, systemd, monitoring proxies, or the qwen-coder-local repository. I only need TabbyAPI, this model, and the exact configuration below.

Goal:
- Native Windows only.
- Official TabbyAPI.
- Keep the server running after setup.
- Bind only to 127.0.0.1.
- Do not expose or print API keys.
- Do not change any configuration value unless setup is impossible. Report the exact error instead.

Hardware:
- NVIDIA RTX 5090 with 32 GB VRAM.
- Use Python 3.12 x64.
- Use Python from python.org, not the Microsoft Store.
- Use CUDA 13 dependencies with TabbyAPI's --gpu-lib cu13 option.
- Use this simple installation path: C:\AI\tabbyAPI

Model:
- Full name: Qwen3.8-27B, EXL3 5.5 bpw, AWQ-smoothed
- Quantized checkpoint author: TelperionAI
- Base model author: Qwen Team
- Hugging Face model: https://huggingface.co/TelperionAI/Qwen3.8-27B-EXL3-5.5bpw
- Base model: Qwen/Qwen3.8-27B
- Exact Hugging Face revision:
  af0c885473c466f0f9cf89dfb4d43d475635330c
- Local model folder name:
  Qwen3.8-27B-EXL3-5.5bpw

Install steps:
1. Check that git, Python 3.12, and nvidia-smi are available.
2. Clone the official TabbyAPI repository:
   https://github.com/theroyallab/tabbyAPI.git
3. Pin TabbyAPI to this known working commit:
   109629b78bd6a1c04e2a4ba8f7702efa9c99e84a
4. Create the folders:
   models
   sampler_overrides
5. Create config.yml with exactly this content:

BEGIN config.yml
network:
  host: 127.0.0.1
  port: 5000
  disable_auth: false
  disable_fetch_requests: true
  send_tracebacks: false
  api_servers: [OAI]
  sse_ping_interval: 15

logging:
  log_prompt: false
  log_generation_params: false
  log_requests: false
  log_chat_completion_requests: false

model:
  model_dir: models
  inline_model_loading: false
  use_dummy_models: false
  model_name: Qwen3.8-27B-EXL3-5.5bpw
  backend: exllamav3
  max_seq_len: 131072
  cache_size: 131072
  cache_mode: "8,8"
  tensor_parallel: false
  gpu_split_auto: true
  autosplit_reserve: [96]
  chunk_size: 2048
  output_chunking: true
  max_batch_size: 1
  vision: false
  template_vars_default:
    enable_thinking: true
    preserve_thinking: true
    reasoning_effort: medium
  reasoning: true
  reasoning_start_token: "<think>"
  reasoning_end_token: "</think>"
  start_in_reasoning: auto
  tool_calls_in_reasoning: true
  tool_format: qwen3_5

draft_model:
  draft_mode: mtp
  draft_cache_mode: Q8
  draft_num_tokens: 3
  dynamic_draft: false

sampling:
  override_preset: qwen38_agent

memory:
  sysmem_recurrent_cache: 4096
  sysmem_kv_cache: 0
  cuda_malloc_async: true

developer:
  unsafe_launch: false
  disable_request_streaming: false
END config.yml

6. Create sampler_overrides\qwen38_agent.yml with exactly this content:

BEGIN qwen38_agent.yml
temperature:
  override: 1.0
  force: false

top_p:
  override: 0.95
  force: false

top_k:
  override: 20
  force: false

min_p:
  override: 0.0
  force: false

presence_penalty:
  override: 0.0
  force: false

repetition_penalty:
  override: 1.0
  force: false
END qwen38_agent.yml

7. From the TabbyAPI directory, install dependencies without starting the server:

   .\start.bat --gpu-lib cu13 --config config.yml --update-deps

8. Download the exact model revision into the configured models directory:

   .\start.bat --gpu-lib cu13 --config config.yml download TelperionAI/Qwen3.8-27B-EXL3-5.5bpw --folder-name Qwen3.8-27B-EXL3-5.5bpw --revision af0c885473c466f0f9cf89dfb4d43d475635330c

9. Confirm that this directory exists and contains model files:

   C:\AI\tabbyAPI\models\Qwen3.8-27B-EXL3-5.5bpw

10. Start TabbyAPI from its own directory:

   .\start.bat --gpu-lib cu13 --config config.yml

11. Verify:
   - http://127.0.0.1:5000/health succeeds.
   - The loaded model is Qwen3.8-27B-EXL3-5.5bpw.
   - The server uses ExLlamaV3.
   - The API accepts an authenticated POST to /v1/chat/completions.
   - The server remains running.

TabbyAPI should generate api_tokens.yml automatically. Read the API key only in memory for testing. Never print, paste, or log the API key or admin key.

Use this test request after startup:

{
  "model": "Qwen3.8-27B-EXL3-5.5bpw",
  "messages": [
    {
      "role": "user",
      "content": "Reply with exactly: local inference works"
    }
  ],
  "reasoning_effort": "low",
  "max_tokens": 128,
  "temperature": 1.0,
  "top_p": 0.95,
  "top_k": 20,
  "min_p": 0.0,
  "presence_penalty": 0.0,
  "repetition_penalty": 1.0
}

At the end, report only:
- Whether setup succeeded.
- TabbyAPI directory.
- Model directory.
- Endpoint.
- Loaded model name.
- Selected CUDA dependency variant.
- Any error preventing completion.

Do not stop the server after successful setup.
```
