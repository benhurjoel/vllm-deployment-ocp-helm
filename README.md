# vLLM Hugging Face Helm Chart for OpenShift

This repository contains a reusable Helm chart for deploying vLLM on OpenShift and downloading Hugging Face models into a persistent volume before the server starts.

The chart is designed for clusters behind corporate proxies:

- proxy environment variables are applied to both the model downloader and vLLM container
- optional trusted CA bundle mounting supports TLS-inspecting proxies
- model files are cached on a PVC under `/models`
- gated/private Hugging Face models can use an existing Secret or a chart-created Secret
- values files can swap model IDs, PVC sizes, GPU requests, and vLLM runtime arguments

## Layout

```text
charts/vllm-hf/                 Helm chart
examples/                       model-specific values examples
```

## Install

Create a namespace/project:

```bash
oc new-project llm-serving
```

For public models:

```bash
helm upgrade --install tinyllama ./charts/vllm-hf \
  --set model.repoId=TinyLlama/TinyLlama-1.1B-Chat-v1.0 \
  --set route.host=tinyllama.apps.example.openshift.com \
  --set proxy.enabled=true \
  --set proxy.httpProxy=http://proxy.example.com:8080 \
  --set proxy.httpsProxy=http://proxy.example.com:8080 \
  --set proxy.noProxy='.svc,.cluster.local,localhost,127.0.0.1,10.0.0.0/8'
```

For gated Hugging Face models, create a token Secret first:

```bash
oc create secret generic hf-token --from-literal=token=hf_your_token_here
```

Then install with an override file:

```bash
helm upgrade --install mistral ./charts/vllm-hf -f examples/mistral-7b-proxy-values.yaml
```

To require an API key for external gateways such as Portkey, create a Secret:

```bash
oc create secret generic vllm-api-key --from-literal=api-key=your_shared_key
```

Then reference it from values:

```yaml
apiKeySecret:
  enabled: true
  name: vllm-api-key
  key: api-key
```

Gateways should send the key with the OpenAI-compatible request, for example `Authorization: Bearer your_shared_key`.

For an embedding model test:

```bash
helm upgrade --install qwen3-embedding ./charts/vllm-hf -f examples/qwen3-embedding-4b-values.yaml
```

If vLLM exits with `unrecognized arguments`, check the `vllm` container logs for the exact flag. For the Qwen embedding example, keep `vllm.task` empty unless your selected vLLM image supports `--task embed`.

Other model examples:

```bash
helm upgrade --install deepseek-ocr-2 ./charts/vllm-hf \
  -n llm-serving \
  -f examples/deepseek-ocr-2-values.yaml \
  -f examples/h200-gpu-node-affinity-values.yaml

helm upgrade --install qwen36-35b ./charts/vllm-hf \
  -n llm-serving \
  -f examples/qwen3-6-35b-a3b-values.yaml \
  -f examples/h200-gpu-node-affinity-values.yaml

helm upgrade --install qwen3-vl-embedding ./charts/vllm-hf \
  -n llm-serving \
  -f examples/qwen3-vl-embedding-8b-values.yaml \
  -f examples/h200-gpu-node-affinity-values.yaml
```

DeepSeek-OCR-2 uses custom Transformers code. If the vLLM image reports an unsupported model architecture, use this chart to cache the model on PVC and serve it with a custom Transformers-based runtime.

DeepSeek-OCR-2 model-specific vLLM parameters included in the example:

```yaml
model:
  trustRemoteCode: true
vllm:
  extraArgs:
    - --logits_processors
    - vllm.model_executor.models.deepseek_ocr:NGramPerReqLogitsProcessor
    - --no-enable-prefix-caching
    - --mm-processor-cache-gb
    - "0"
```

DeepSeek-OCR-2 request requirements:

```json
{
  "model": "deepseek-ai/DeepSeek-OCR-2",
  "max_tokens": 2048,
  "temperature": 0.0,
  "extra_body": {
    "skip_special_tokens": false,
    "vllm_xargs": {
      "ngram_size": 30,
      "window_size": 90,
      "whitelist_token_ids": [128821, 128822]
    }
  }
}
```

A full request body is available at `examples/deepseek-ocr-2-openai-request.json`.

Qwen3.6-35B-A3B model-specific vLLM parameters included in the example:

```yaml
image:
  tag: "v0.19.0"
vllm:
  maxModelLen: "262144"
  extraArgs:
    - --reasoning-parser
    - qwen3
```

Qwen3-VL-Embedding-8B model-specific vLLM parameters included in the example:

```yaml
model:
  trustRemoteCode: true
vllm:
  runner: pooling
  maxModelLen: "32768"
  dtype: bfloat16
```

## Reusing For New Models

Create a new values file with the model-specific fields:

```yaml
model:
  repoId: organization/model-name
  requiresToken: false

modelStorage:
  size: 200Gi

vllm:
  servedModelName: friendly-model-name
  tensorParallelSize: 1
  maxModelLen: "8192"
  extraArgs:
    - --disable-log-requests
  extraEnvs:
    - name: VLLM_LOGGING_LEVEL
      value: INFO

resources:
  requests:
    nvidia.com/gpu: "1"
  limits:
    nvidia.com/gpu: "1"

nodeAffinity:
  enabled: true
  nodeSelectorTerms:
    - matchExpressions:
        - key: nvidia.com/gpu.product
          operator: In
          values:
            - NVIDIA-H200
```

The init container downloads the Hugging Face snapshot into the PVC. On later pod starts, it skips the download when `.complete` exists in the model directory.

Use one Helm release per served model. If you increase `replicaCount`, use storage that supports the access mode your replicas need, usually `ReadWriteMany`, or pre-populate separate PVCs per replica outside this chart.

## Important Values

| Value | Purpose |
| --- | --- |
| `model.repoId` | Hugging Face model repository ID. |
| `model.revision` | Optional branch, tag, or commit SHA. |
| `model.requiresToken` | Adds `HF_TOKEN` from the configured Secret. |
| `model.trustRemoteCode` | Adds vLLM `--trust-remote-code`. Use only for trusted repos. |
| `apiKeySecret.*` | Optional vLLM API key Secret for external gateways. |
| `proxy.*` | HTTP(S)/NO proxy settings for restricted clusters. |
| `proxy.nodeUseEnvProxy` | Adds `NODE_USE_ENV_PROXY=1` when proxy support is enabled. |
| `trustedCA.*` | Optional ConfigMap-mounted CA bundle for TLS-inspecting proxies. |
| `modelStorage.*` | PVC creation or existing PVC wiring. |
| `downloader.*` | Hugging Face download init container settings. |
| `vllm.extraArgs` | Additional vLLM CLI arguments appended to the container args. |
| `vllm.extraEnv` / `vllm.extraEnvs` | Additional environment variables for vLLM. |
| `vllm.*` | vLLM OpenAI-compatible server arguments, including `vllm.task=embed` for embedding models. |
| `resources.*` | CPU, memory, and GPU requests/limits for the vLLM container. |
| `nodeAffinity.nodeSelectorTerms` | Optional Kubernetes node selector terms for GPU-only or H200-only scheduling. |
| `route.host` | Optional external hostname for the OpenShift Route. |
| `route.*` | OpenShift Route exposure and TLS settings. |
| `openshift.scc.anyuid.enabled` | Creates a RoleBinding that grants the service account the OpenShift `anyuid` SCC. |

## OpenShift Notes

The chart avoids fixed UIDs so it can run under OpenShift restricted SCCs. It sets `allowPrivilegeEscalation: false`, drops Linux capabilities, and uses `seccompProfile: RuntimeDefault`.

If your selected vLLM image needs to run with its image-defined UID, enable the OpenShift `anyuid` SCC binding:

```yaml
openshift:
  scc:
    anyuid:
      enabled: true
```

If the pod fails before the init command runs with a `runAsNonRoot` or image-user validation error while `anyuid` is enabled, set an explicit non-root UID:

```yaml
downloader:
  securityContext:
    runAsUser: 1001
securityContext:
  runAsUser: 1001
```

By default, the downloader uses the vLLM image and its already-installed `huggingface_hub` package, so the init container does not need PyPI access. If you override the downloader image with a minimal Python image, either include `huggingface_hub` in that image or set `downloader.installDependencies=true` only when PyPI access is available through your proxy.

For restricted/proxied clusters, `downloader.enableHfTransfer=false` and `downloader.disableXet=true` are the safer defaults. Some Hugging Face models use alternate transfer backends that can return 403s when a corporate proxy blocks or rewrites the signed storage URLs.

The vLLM container also sets writable cache paths under `/tmp`:

```yaml
cacheVolume:
  enabled: true
  mountPath: /tmp/.cache
  rootCacheMountPath: /.cache
vllm:
  home: /tmp/home
  xdgCacheHome: /tmp/.cache
  hfHubCache: /tmp/.cache/huggingface/hub
  transformersCache: /tmp/.cache/huggingface/transformers
  torchHome: /tmp/.cache/torch
  sentenceTransformersHome: /tmp/.cache/sentence_transformers
  matplotlibConfigDir: /tmp/.cache/matplotlib
```

`cacheVolume.rootCacheMountPath` exists for model code that ignores cache env vars and tries to write directly to `/.cache`.

GPU scheduling still requires the OpenShift NVIDIA GPU Operator or equivalent device plugin. Adjust `nodeAffinity.nodeSelectorTerms`, `nodeSelector`, and tolerations in values if your GPU nodes are labeled or tainted. The exact GPU product label can vary by NVIDIA device plugin configuration, so verify it with `oc get nodes --show-labels`.

Container proxy variables help the Hugging Face download and any runtime outbound traffic. Image pull proxying is controlled by the OpenShift cluster proxy and node/container runtime configuration.

If your proxy intercepts TLS, create or copy the trusted CA bundle ConfigMap into the model-serving namespace and set `trustedCA.enabled=true` plus `trustedCA.configMapName`.

## Verify

```bash
helm lint ./charts/vllm-hf
helm template tinyllama ./charts/vllm-hf
```

## Troubleshooting

If the init container exits with code `0` and the pod then shows `CreateContainerConfigError`, the init step completed and Kubernetes is failing to create the next container. Check pod events:

```bash
oc describe pod <pod-name> -n llm-serving
```

Common causes with this chart:

- `secret "vllm-api-key" not found`: create the Portkey/vLLM API-key Secret or disable `apiKeySecret.enabled`.
- `secret "hf-token" not found`: create the Hugging Face token Secret or set `model.requiresToken=false`.
- `configmap "trusted-ca-bundle" not found`: create the trusted CA ConfigMap or set `trustedCA.enabled=false`.
- Startup probe failures with API-key mode: use the default TCP probes on port `8000`. HTTP probes to `/health` may fail when vLLM is started with `--api-key`.

For Portkey API key mode:

```bash
oc create secret generic vllm-api-key -n llm-serving --from-literal=api-key=your_shared_key
```
