---
title: Nano Banana Pro | Runware Docs
url: https://runware.ai/docs/models/google-nano-banana-pro
description: Nano Banana Pro image preview for precise visual control
---
# Nano Banana Pro

Nano Banana Pro (also known as Nano Banana 2) is a Gemini 3 Pro Image Preview model for controlled visual creation. It improves reasoning over lighting and camera angle. It supports high resolution output and multi image blending for production ready design workflows and creative tools.

- **ID**: `google:4@2`
- **Status**: live
- **Creator**: Google
- **Release Date**: November 20, 2025
- **Capabilities**: Text to Image, Image to Image, Edit, Checkpoint

## Pricing

From $0.138/image

- **1K**: `$0.138`
- **2K**: `$0.138`
- **4K**: `$0.244`

## Compatibility & Validation

Either provide `inputs.referenceImages`, or specify `width/height`.

---

`resolution` cannot be used with `width/height`.

---

When `resolution` is provided, `inputs.referenceImages` is required.

---

`width` and `height` must be used together.

---

The following dimension combinations are supported:

| Configuration | Dimensions |
| --- | --- |
| `1K (1:1)` | `1024x1024` |
| `1K (3:2)` | `1264x848` |
| `1K (2:3)` | `848x1264` |
| `1K (4:3)` | `1200x896` |
| `1K (3:4)` | `896x1200` |
| `1K (4:5)` | `928x1152` |
| `1K (5:4)` | `1152x928` |
| `1K (9:16)` | `768x1376` |
| `1K (16:9)` | `1376x768` |
| `1K (21:9)` | `1548x672` |
| `2K (1:1)` | `2048x2048` |
| `2K (3:2)` | `2528x1696` |
| `2K (2:3)` | `1696x2528` |
| `2K (4:3)` | `2400x1792` |
| `2K (3:4)` | `1792x2400` |
| `2K (4:5)` | `1856x2304` |
| `2K (5:4)` | `2304x1856` |
| `2K (9:16)` | `1536x2752` |
| `2K (16:9)` | `2752x1536` |
| `2K (21:9)` | `3168x1344` |
| `4K (1:1)` | `4096x4096` |
| `4K (3:2)` | `5056x3392` |
| `4K (2:3)` | `3392x5056` |
| `4K (4:3)` | `4800x3584` |
| `4K (3:4)` | `3584x4800` |
| `4K (4:5)` | `3712x4608` |
| `4K (5:4)` | `4608x3712` |
| `4K (9:16)` | `3072x5504` |
| `4K (16:9)` | `5504x3072` |
| `4K (21:9)` | `6336x2688` |

## Request Parameters

**API Options**

Platform-level options for task execution and delivery.

### [taskType](https://runware.ai/docs/models/google-nano-banana-pro#request-tasktype)

- **Type**: `string`
- **Required**: true
- **Value**: `imageInference`

Identifier for the type of task being performed

### [taskUUID](https://runware.ai/docs/models/google-nano-banana-pro#request-taskuuid)

- **Type**: `string`
- **Required**: true
- **Format**: `UUID v4`

UUID v4 identifier for tracking tasks and matching async responses. Must be unique per task.

### [outputType](https://runware.ai/docs/models/google-nano-banana-pro#request-outputtype)

- **Type**: `string`
- **Default**: `URL`

Image output type.

**Allowed values**: `URL` `base64Data` `dataURI`

### [outputFormat](https://runware.ai/docs/models/google-nano-banana-pro#request-outputformat)

- **Type**: `string`
- **Default**: `JPG`

Specifies the file format of the generated output. The available values depend on the task type and the specific model's capabilities.

- \`JPG\`: Best for photorealistic images with smaller file sizes (no transparency).
- \`PNG\`: Lossless compression, supports high quality and transparency (alpha channel).
- \`WEBP\`: Modern format providing superior compression and transparency support.

> [!NOTE]
> \*\*Transparency\*\*: If you are using features like background removal or LayerDiffuse that require transparency, you must select a format that supports an alpha channel (e.g., \`PNG\`, \`WEBP\`, \`TIFF\`). \`JPG\` does not support transparency.

**Allowed values**: `JPG` `PNG` `WEBP`

### [outputQuality](https://runware.ai/docs/models/google-nano-banana-pro#request-outputquality)

- **Type**: `integer`
- **Min**: `20`
- **Max**: `99`
- **Default**: `95`

Compression quality of the output. Higher values preserve quality but increase file size.

### [webhookURL](https://runware.ai/docs/models/google-nano-banana-pro#request-webhookurl)

- **Type**: `string`
- **Format**: `uri`

Specifies a webhook URL where JSON responses will be sent via HTTP POST when generation tasks complete. For batch requests with multiple results, each completed item triggers a separate webhook call as it becomes available.

**Learn more** (1 resource):

- [Webhooks](https://runware.ai/docs/platform/webhooks) (platform)

### [deliveryMethod](https://runware.ai/docs/models/google-nano-banana-pro#request-deliverymethod)

- **Type**: `string`
- **Default**: `sync`

Determines how the API delivers task results.

**Allowed values**:

- `sync` Returns complete results directly in the API response.
- `async` Returns an immediate acknowledgment with the task UUID. Poll for results using getResponse.

**Learn more** (1 resource):

- [Task Polling](https://runware.ai/docs/platform/task-polling) (platform)

### [uploadEndpoint](https://runware.ai/docs/models/google-nano-banana-pro#request-uploadendpoint)

- **Type**: `string`
- **Format**: `uri`

Specifies a URL where the generated content will be automatically uploaded using the HTTP PUT method. The raw binary data of the media file is sent directly as the request body. For secure uploads to cloud storage, use presigned URLs that include temporary authentication credentials.

**Common use cases:**

- **Cloud storage**: Upload directly to S3 buckets, Google Cloud Storage, or Azure Blob Storage using presigned URLs.
- **CDN integration**: Upload to content delivery networks for immediate distribution.

```text
// S3 presigned URL for secure upload
https://your-bucket.s3.amazonaws.com/generated/content.mp4?X-Amz-Signature=abc123&X-Amz-Expires=3600

// Google Cloud Storage presigned URL
https://storage.googleapis.com/your-bucket/content.jpg?X-Goog-Signature=xyz789

// Custom storage endpoint
https://storage.example.com/uploads/generated-image.jpg
```

The content data will be sent as the request body to the specified URL when generation is complete.

### [safety](https://runware.ai/docs/models/google-nano-banana-pro#request-safety)

- **Path**: `safety.checkContent`
- **Type**: `object (1 property)`

Content safety checking configuration for image generation.

#### [checkContent](https://runware.ai/docs/models/google-nano-banana-pro#request-safety-checkcontent)

- **Path**: `safety.checkContent`
- **Type**: `boolean`

Enable or disable content safety checking.

### [ttl](https://runware.ai/docs/models/google-nano-banana-pro#request-ttl)

- **Type**: `integer`
- **Min**: `60`

Time-to-live (TTL) in seconds for generated content. Only applies when `outputType` is `URL`.

### [includeCost](https://runware.ai/docs/models/google-nano-banana-pro#request-includecost)

- **Type**: `boolean`

Include task cost in the response.

### [numberResults](https://runware.ai/docs/models/google-nano-banana-pro#request-numberresults)

- **Type**: `integer`
- **Min**: `1`
- **Max**: `20`
- **Default**: `1`

Number of results to generate. Each result uses a different seed, producing variations of the same parameters.

**Inputs**

Input resources for the task (images, audio, etc). These must be nested inside the \`inputs\` object.

### [referenceImages](https://runware.ai/docs/models/google-nano-banana-pro#request-inputs-referenceimages)

- **Path**: `inputs.referenceImages`
- **Type**: `array of strings`

List of reference images (UUID, URL, Data URI, or Base64).

**Core Parameters**

Primary parameters that define the task output.

### [model](https://runware.ai/docs/models/google-nano-banana-pro#request-model)

- **Type**: `string`
- **Required**: true
- **Value**: `google:4@2`

Identifier of the model to use for generation.

**Learn more** (3 resources):

- [Text To Image: Model Selection](https://runware.ai/docs/learn/text-to-image#model-selection) (learn)
- [Image Inpainting: Model Specialized Inpainting Models](https://runware.ai/docs/learn/image-inpainting#model-specialized-inpainting-models) (learn)
- [Image Outpainting: Other Critical Parameters](https://runware.ai/docs/learn/image-outpainting#other-critical-parameters) (learn)

### [positivePrompt](https://runware.ai/docs/models/google-nano-banana-pro#request-positiveprompt)

- **Type**: `string`
- **Required**: true
- **Min**: `3`
- **Max**: `45000`

Text prompt describing elements to include in the generated output.

**Learn more** (1 resource):

- [Prompts](https://runware.ai/docs/learn/prompts) (learn)

### [width](https://runware.ai/docs/models/google-nano-banana-pro#request-width)

- **Type**: `integer`
- **Required**: true
- **Paired with**: height

Width of the generated media in pixels.

**Learn more** (2 resources):

- [Dimensions](https://runware.ai/docs/learn/dimensions) (learn)
- [Image Outpainting: Dimensions Critical For Outpainting](https://runware.ai/docs/learn/image-outpainting#dimensions-critical-for-outpainting) (learn)

### [height](https://runware.ai/docs/models/google-nano-banana-pro#request-height)

- **Type**: `integer`
- **Required**: true
- **Paired with**: width

Height of the generated media in pixels.

**Learn more** (2 resources):

- [Dimensions](https://runware.ai/docs/learn/dimensions) (learn)
- [Image Outpainting: Dimensions Critical For Outpainting](https://runware.ai/docs/learn/image-outpainting#dimensions-critical-for-outpainting) (learn)

### [resolution](https://runware.ai/docs/models/google-nano-banana-pro#request-resolution)

- **Type**: `string`

Resolution preset for the output. When used with input media, automatically matches the aspect ratio from the input.

**Allowed values**: `1K` `2K` `4K`

### [seed](https://runware.ai/docs/models/google-nano-banana-pro#request-seed)

- **Type**: `integer`
- **Min**: `0`
- **Max**: `2147483647`

Random seed for reproducible generation. When not provided, a random seed is generated in the unsigned 32-bit range.

**Settings**

Technical parameters to fine-tune the inference process. These must be nested inside the \`settings\` object.

### [systemPrompt](https://runware.ai/docs/models/google-nano-banana-pro#request-settings-systemprompt)

- **Path**: `settings.systemPrompt`
- **Type**: `string`
- **Min**: `1`
- **Max**: `50000`

System-level instruction that guides the model's behavior and output style across the entire generation.

### [temperature](https://runware.ai/docs/models/google-nano-banana-pro#request-settings-temperature)

- **Path**: `settings.temperature`
- **Type**: `float`
- **Min**: `0`
- **Max**: `2`
- **Step**: `0.01`

Controls randomness in generation. Lower values produce more deterministic outputs, higher values increase variation and creativity.

### [topP](https://runware.ai/docs/models/google-nano-banana-pro#request-settings-topp)

- **Path**: `settings.topP`
- **Type**: `float`
- **Min**: `0`
- **Max**: `1`
- **Step**: `0.01`

Nucleus sampling parameter that controls diversity by limiting the probability mass. Lower values make outputs more focused, higher values increase diversity.

**Features**

Standalone addons and post-processing features.

### [watermark](https://runware.ai/docs/models/google-nano-banana-pro#request-watermark)

- **Path**: `watermark.text`
- **Type**: `object (7 properties)`

Configuration object for adding watermarks to generated videos. Watermarks can be applied using either text or image content with customizable positioning and appearance. You must provide either `text` or `image` content for the watermark, but not both.

**Text watermark**:

```json
"advancedFeatures": {
  "watermark": {
    "text": "© 2025 Company",
    "displayPosition": "bottom-right",
    "opacity": 0.6,
    "fontColor": "#ffffff",
    "bgColor": "#000000"
  }
}
```

**Image watermark**:

```json
"advancedFeatures": {
  "watermark": {
    "image": "c64351d5-4c59-42f7-95e1-eace013eddab",
    "displayPosition": "top-left",
    "opacity": 0.6
  }
}
```

**Tiled watermark**:

```json
"advancedFeatures": {
  "watermark": {
    "text": "PREVIEW",
    "tiled": true,
    "opacity": 0.4,
    "fontColor": "#cccccc"
  }
}
```

#### [text](https://runware.ai/docs/models/google-nano-banana-pro#request-watermark-text)

- **Path**: `watermark.text`
- **Type**: `string`
- **Min**: `2`
- **Max**: `32`

Watermark text.

#### [image](https://runware.ai/docs/models/google-nano-banana-pro#request-watermark-image)

- **Path**: `watermark.image`
- **Type**: `string`

Watermark image (UUID, URL, Data URI, or Base64).

#### [displayPosition](https://runware.ai/docs/models/google-nano-banana-pro#request-watermark-displayposition)

- **Path**: `watermark.displayPosition`
- **Type**: `string`

Watermark position.

**Allowed values**: `top-left` `top-center` `top-right` `center-left` `center-center` `center-right` `bottom-left` `bottom-center` `bottom-right`

#### [tiled](https://runware.ai/docs/models/google-nano-banana-pro#request-watermark-tiled)

- **Path**: `watermark.tiled`
- **Type**: `boolean`

Enable tiled watermark.

#### [opacity](https://runware.ai/docs/models/google-nano-banana-pro#request-watermark-opacity)

- **Path**: `watermark.opacity`
- **Type**: `float`
- **Min**: `0.1`
- **Max**: `1`
- **Step**: `0.01`

Watermark opacity.

#### [fontColor](https://runware.ai/docs/models/google-nano-banana-pro#request-watermark-fontcolor)

- **Path**: `watermark.fontColor`
- **Type**: `string`

Text color in hex format.

#### [bgColor](https://runware.ai/docs/models/google-nano-banana-pro#request-watermark-bgcolor)

- **Path**: `watermark.bgColor`
- **Type**: `string`

Background color in hex format.

**Provider Settings**

Parameters specific to this model provider. These must be nested inside the \`providerSettings.google\` object.

### [safetyTolerance](https://runware.ai/docs/models/google-nano-banana-pro#request-providersettings-google-safetytolerance)

- **Path**: `providerSettings.google.safetyTolerance`
- **Type**: `string`
- **Default**: `none`

Safety filter tolerance level. Use `off` to use Google's defaults.

**Allowed values**: `high` `medium` `low` `none` `off`

### [webSearch](https://runware.ai/docs/models/google-nano-banana-pro#request-providersettings-google-websearch)

- **Path**: `providerSettings.google.webSearch`
- **Type**: `boolean`

Enable live web search grounding to incorporate real-world, up-to-date information into image generation.

## Response Parameters

### [taskType](https://runware.ai/docs/models/google-nano-banana-pro#response-tasktype)

- **Type**: `string`
- **Required**: true
- **Value**: `imageInference`

Identifier for the type of task this response belongs to.

### [taskUUID](https://runware.ai/docs/models/google-nano-banana-pro#response-taskuuid)

- **Type**: `string`
- **Required**: true
- **Format**: `UUID v4`

UUID v4 identifier echoed from the original request, used to match async responses to their tasks.

### [imageUUID](https://runware.ai/docs/models/google-nano-banana-pro#response-imageuuid)

- **Type**: `string`
- **Required**: true
- **Format**: `UUID v4`

UUID of the output image.

### [imageURL](https://runware.ai/docs/models/google-nano-banana-pro#response-imageurl)

- **Type**: `string`
- **Format**: `uri`

URL of the output image.

### [imageBase64Data](https://runware.ai/docs/models/google-nano-banana-pro#response-imagebase64data)

- **Type**: `string`

Base64-encoded image data.

### [imageDataURI](https://runware.ai/docs/models/google-nano-banana-pro#response-imagedatauri)

- **Type**: `string`
- **Format**: `uri`

Data URI of the output image.

### [seed](https://runware.ai/docs/models/google-nano-banana-pro#response-seed)

- **Type**: `integer`

The seed used for generation. If none was provided, shows the randomly generated seed.

### [NSFWContent](https://runware.ai/docs/models/google-nano-banana-pro#response-nsfwcontent)

- **Type**: `boolean`

Flag indicating if NSFW content was detected.

### [cost](https://runware.ai/docs/models/google-nano-banana-pro#response-cost)

- **Type**: `float`

Task cost in USD. Present when `includeCost` is set to `true` in the request.

## Examples

### Bioluminescent Desert Observatory Interior (Text to Image)

![Bioluminescent Desert Observatory Interior]()

---

### Aurora Research Outpost Panorama (Text to Image)

![Aurora Research Outpost Panorama]()

---

### Surreal Four-Source Fashion Collage (Image to Image)

![Surreal Four-Source Fashion Collage]()

---

### Bioluminescent Library Observatory Interior (Text to Image)

![Bioluminescent Library Observatory Interior]()