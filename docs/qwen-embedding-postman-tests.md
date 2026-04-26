# Qwen Embedding Postman Tests

Use these requests after deploying the Qwen embedding models with the chart.

## Common Postman Settings

Method:

```text
POST
```

Headers:

```text
Content-Type: application/json
Authorization: Bearer <your_vllm_api_key>
```

## Qwen3-Embedding-4B Text Embeddings

URL:

```text
https://<your-qwen3-embedding-route>/v1/embeddings
```

Body:

```json
{
  "model": "qwen3-embedding-4b",
  "input": [
    "OpenShift runs containerized workloads on Kubernetes.",
    "vLLM serves OpenAI-compatible model APIs."
  ]
}
```

Request file:

```text
examples/qwen3-embedding-4b-openai-request.json
```

Expected response shape:

```json
{
  "object": "list",
  "data": [
    {
      "object": "embedding",
      "embedding": [0.01, -0.02],
      "index": 0
    }
  ],
  "model": "qwen3-embedding-4b"
}
```

The real embedding vector will be much longer than the shortened example above.

## Qwen3-VL-Embedding-8B Text Embeddings

URL:

```text
https://<your-qwen3-vl-embedding-route>/v1/embeddings
```

Body:

```json
{
  "model": "qwen3-vl-embedding-8b",
  "input": [
    "A sample document page with invoice number 12345 and total amount 42.50.",
    "A product photo showing a red backpack on a white background."
  ]
}
```

Request file:

```text
examples/qwen3-vl-embedding-8b-openai-text-request.json
```

## Qwen3-VL-Embedding-8B Image Embedding

Use this when testing from an air-gapped Windows jump host. Convert a local image to base64 first.

PowerShell:

```powershell
$bytes = [System.IO.File]::ReadAllBytes("C:\Temp\receipt.png")
$base64 = [Convert]::ToBase64String($bytes)
Set-Content -Path "C:\Temp\receipt.b64" -Value $base64 -NoNewline
```

Copy the single line from `C:\Temp\receipt.b64`.

URL:

```text
https://<your-qwen3-vl-embedding-route>/v1/embeddings
```

Body:

```json
{
  "model": "qwen3-vl-embedding-8b",
  "input": [
    {
      "type": "image_url",
      "image_url": {
        "url": "data:image/png;base64,PASTE_BASE64_HERE"
      }
    }
  ]
}
```

Request file:

```text
examples/qwen3-vl-embedding-8b-openai-image-base64-template.json
```

Replace only `PASTE_BASE64_HERE`. Keep the prefix:

```text
data:image/png;base64,
```

For JPG/JPEG images, use:

```text
data:image/jpeg;base64,
```

## Common Errors

`model not found`

Check that the request `model` matches `vllm.servedModelName` in the values file.

`401 Unauthorized`

Check that the Postman `Authorization` header matches the `vllm-api-key` Secret.

`non-base64 digit found`

The image payload is not valid base64. Do not paste a filename, path, placeholder, spaces, or line breaks.

`404 Not Found`

Make sure you are calling `/v1/embeddings`, not `/v1/chat/completions`.

## Request Files Summary

```text
examples/qwen3-embedding-4b-openai-request.json
examples/qwen3-vl-embedding-8b-openai-text-request.json
examples/qwen3-vl-embedding-8b-openai-image-base64-template.json
```
