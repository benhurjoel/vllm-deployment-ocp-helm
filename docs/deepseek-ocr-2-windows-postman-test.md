# DeepSeek-OCR-2 Windows Jump Host Postman Test

Use this guide when the OpenShift cluster is air-gapped and the vLLM pod cannot fetch an external image URL. The idea is to create or use an image on the Windows jump host, convert it to base64, and send it inline through Postman.

## 1. Create A Test Image

Open PowerShell on the Windows jump host.

```powershell
New-Item -ItemType Directory -Force -Path "C:\Temp" | Out-Null

Add-Type -AssemblyName System.Drawing

$bmp = New-Object System.Drawing.Bitmap 900, 300
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.Clear([System.Drawing.Color]::White)

$font = New-Object System.Drawing.Font "Arial", 28
$brush = [System.Drawing.Brushes]::Black

$graphics.DrawString("Invoice #12345", $font, $brush, 40, 40)
$graphics.DrawString("Item: Test Widget", $font, $brush, 40, 100)
$graphics.DrawString("Total: $42.50", $font, $brush, 40, 160)

$bmp.Save("C:\Temp\receipt.png", [System.Drawing.Imaging.ImageFormat]::Png)

$graphics.Dispose()
$bmp.Dispose()
```

If you already have a PNG or JPG image on the jump host, you can use that file instead.

## 2. Convert The Image To Base64

For the generated PNG:

```powershell
$bytes = [System.IO.File]::ReadAllBytes("C:\Temp\receipt.png")
$base64 = [Convert]::ToBase64String($bytes)
Set-Content -Path "C:\Temp\receipt.b64" -Value $base64 -NoNewline
```

Open `C:\Temp\receipt.b64` and copy the entire single line.

## 3. Send Request From Postman

Method:

```text
POST
```

URL:

```text
https://<your-deepseek-route>/v1/chat/completions
```

Headers:

```text
Content-Type: application/json
Authorization: Bearer <your_vllm_api_key>
```

Body type:

```text
raw JSON
```

Body:

```json
{
  "model": "deepseek-ai/DeepSeek-OCR-2",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/png;base64,PASTE_BASE64_HERE"
          }
        },
        {
          "type": "text",
          "text": "Free OCR."
        }
      ]
    }
  ],
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

Replace only `PASTE_BASE64_HERE`.

Keep this prefix:

```text
data:image/png;base64,
```

If your image is JPG or JPEG, use:

```text
data:image/jpeg;base64,
```

## 4. Common Errors

`non-base64 digit found`

The base64 value is invalid. Make sure you did not paste a filename, path, placeholder, spaces, or line breaks.

Bad:

```json
"url": "data:image/png;base64,C:\Temp\receipt.png"
```

Bad:

```json
"url": "data:image/png;base64,REPLACE_WITH_BASE64_ENCODED_IMAGE"
```

Good:

```json
"url": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
```

`403 Forbidden` followed by `500 Internal Engine Error`

The pod may be trying to fetch an external image URL that is blocked by the air-gapped network or proxy. Use the base64 inline image format in this guide.

`model not found`

Make sure the request model matches the chart value:

```yaml
vllm:
  servedModelName: deepseek-ai/DeepSeek-OCR-2
```

The JSON request should use:

```json
"model": "deepseek-ai/DeepSeek-OCR-2"
```
