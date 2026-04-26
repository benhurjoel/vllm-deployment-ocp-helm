{{/*
Expand the chart name.
*/}}
{{- define "vllm-hf.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "vllm-hf.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "vllm-hf.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "vllm-hf.labels" -}}
helm.sh/chart: {{ include "vllm-hf.chart" . }}
app.kubernetes.io/name: {{ include "vllm-hf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "vllm-hf.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vllm-hf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "vllm-hf.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "vllm-hf.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "vllm-hf.modelDirName" -}}
{{- if .Values.model.localDirName -}}
{{- .Values.model.localDirName -}}
{{- else -}}
{{- .Values.model.repoId | replace "/" "--" | replace "_" "-" | lower -}}
{{- end -}}
{{- end -}}

{{- define "vllm-hf.modelPath" -}}
{{- printf "%s/%s" (.Values.modelStorage.mountPath | trimSuffix "/") (include "vllm-hf.modelDirName" .) -}}
{{- end -}}

{{- define "vllm-hf.claimName" -}}
{{- if .Values.modelStorage.existingClaim -}}
{{- .Values.modelStorage.existingClaim -}}
{{- else -}}
{{- include "vllm-hf.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "vllm-hf.hfTokenSecretName" -}}
{{- if .Values.hfTokenSecret.name -}}
{{- .Values.hfTokenSecret.name -}}
{{- else -}}
{{- printf "%s-hf-token" (include "vllm-hf.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "vllm-hf.apiKeySecretName" -}}
{{- if .Values.apiKeySecret.name -}}
{{- .Values.apiKeySecret.name -}}
{{- else -}}
{{- printf "%s-api-key" (include "vllm-hf.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "vllm-hf.proxyEnv" -}}
{{- if .Values.proxy.enabled }}
- name: HTTP_PROXY
  value: {{ .Values.proxy.httpProxy | quote }}
- name: HTTPS_PROXY
  value: {{ .Values.proxy.httpsProxy | quote }}
- name: NO_PROXY
  value: {{ .Values.proxy.noProxy | quote }}
- name: http_proxy
  value: {{ .Values.proxy.httpProxy | quote }}
- name: https_proxy
  value: {{ .Values.proxy.httpsProxy | quote }}
- name: no_proxy
  value: {{ .Values.proxy.noProxy | quote }}
{{- if .Values.proxy.nodeUseEnvProxy }}
- name: NODE_USE_ENV_PROXY
  value: "1"
{{- end }}
{{- end }}
{{- end -}}

{{- define "vllm-hf.trustedCAEnv" -}}
{{- if .Values.trustedCA.enabled }}
- name: REQUESTS_CA_BUNDLE
  value: {{ .Values.trustedCA.mountPath | quote }}
- name: SSL_CERT_FILE
  value: {{ .Values.trustedCA.mountPath | quote }}
- name: PIP_CERT
  value: {{ .Values.trustedCA.mountPath | quote }}
{{- end }}
{{- end -}}
