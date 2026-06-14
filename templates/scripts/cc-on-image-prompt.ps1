$inputRaw = [Console]::In.ReadToEnd()
if (-not $inputRaw) { exit 0 }
$lower = $inputRaw.ToLowerInvariant()
$hasImage = $lower -match 'unsupported image|image\.png|image_url|\.png|\.jpg|\.jpeg|\.webp'
if (-not $hasImage) { exit 0 }
Write-Output ""
Write-Output "## Vision auto-hint (UserPromptSubmit)"
Write-Output "User sent image(s). DeepSeek cannot see pixels."
Write-Output "REQUIRED now:"
Write-Output "1. sync_chat_attachments (multi-paste from IDE)"
Write-Output "2. describe_paste_batch if 2+ images else describe_paste"
Write-Output "3. Show image preview markdown from tool result to user"
