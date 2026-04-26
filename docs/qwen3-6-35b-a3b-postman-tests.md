# Qwen3.6-35B-A3B Postman Tests

Use these requests after deploying `Qwen/Qwen3.6-35B-A3B` with the chart.

## Common Postman Settings

Method:

```text
POST
```

URL:

```text
https://<your-qwen36-route>/v1/chat/completions
```

Headers:

```text
Content-Type: application/json
Authorization: Bearer <your_vllm_api_key>
```

## Basic Chat Test

Body:

```json
{
  "model": "qwen3.6-35b-a3b",
  "messages": [
    {
      "role": "system",
      "content": "You are a concise enterprise AI assistant."
    },
    {
      "role": "user",
      "content": "Explain in three bullet points why OpenShift is useful for running vLLM workloads."
    }
  ],
  "max_tokens": 512,
  "temperature": 0.2,
  "top_p": 0.95
}
```

Request file:

```text
examples/qwen3-6-35b-a3b-openai-chat-request.json
```

## Reasoning Test

The Qwen3.6 example values include:

```yaml
vllm:
  extraArgs:
    - --reasoning-parser
    - qwen3
```

Body:

```json
{
  "model": "qwen3.6-35b-a3b",
  "messages": [
    {
      "role": "user",
      "content": "A cluster has 4 H200 GPU nodes. Each node can run 2 vLLM pods. How many model-serving pods can run in total? Show the final answer clearly."
    }
  ],
  "max_tokens": 768,
  "temperature": 0.0,
  "top_p": 1.0
}
```

Request file:

```text
examples/qwen3-6-35b-a3b-openai-reasoning-request.json
```

## Common Errors

`model not found`

Check that the request `model` matches the values file:

```yaml
vllm:
  servedModelName: qwen3.6-35b-a3b
```

`401 Unauthorized`

Check that the Postman `Authorization` header matches the `vllm-api-key` Secret.

`404 Not Found`

Make sure you are calling `/v1/chat/completions`, not `/v1/embeddings`.

`Engine Core Initialization failed`

Check the `vllm` container logs in OpenShift. For Qwen3.6, also confirm the deployed image is recent enough:

```yaml
image:
  tag: "v0.19.0"
```
