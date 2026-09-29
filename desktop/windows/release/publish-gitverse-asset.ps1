param(
  [Parameter(Mandatory = $true)][string]$Tag,
  [Parameter(Mandatory = $true)][string]$Archive
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($env:RELEASE_API_KEY)) {
  throw 'RELEASE_API_KEY is missing.'
}
if (-not (Test-Path -LiteralPath $Archive -PathType Leaf)) {
  throw "Windows archive is missing: $Archive"
}
$file = Get-Item -LiteralPath $Archive
$api = 'https://api.gitverse.ru/repos/egkurilov/BOOHTACORD/releases'
$headers = @{
  Authorization = "Bearer $env:RELEASE_API_KEY"
  Accept = 'application/vnd.gitverse.object+json;version=1'
}

try {
  $release = Invoke-RestMethod -Method Get -Uri "$api/tags/$Tag" -Headers $headers
} catch {
  if ([int]$_.Exception.Response.StatusCode -ne 404) { throw }
  $description = @'
Сборка приложения BOOHTACORD для Windows x64.

Скачайте ZIP, распакуйте его целиком и запустите boohtacord_desktop.exe.
Оставьте DLL-файлы и папку data рядом с исполняемым файлом.

Сборка проходит Flutter-тесты, анализатор и Windows Release compilation.
Голос и демонстрацию экрана необходимо проверить с сервером и вторым клиентом.
'@
  $payload = @{
    tag_name = $Tag
    name = "BOOHTACORD $Tag (Windows x64)"
    body = $description
    draft = $false
    prerelease = $false
  } | ConvertTo-Json -Compress
  $release = Invoke-RestMethod -Method Post -Uri $api -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $payload
}

$existing = @($release.assets | Where-Object { $_.name -eq $file.Name })
if ($existing.Count -gt 0) {
  if ([long]$existing[0].size -ne $file.Length) {
    throw "Release already has an asset named $($file.Name) with a different size."
  }
  Write-Host "Windows asset already published: $($file.Name)"
  exit 0
}

Add-Type -AssemblyName System.Net.Http
$client = New-Object System.Net.Http.HttpClient
$client.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $env:RELEASE_API_KEY)
$client.DefaultRequestHeaders.Accept.ParseAdd('application/vnd.gitverse.object+json;version=1')
$client.Timeout = [TimeSpan]::FromMinutes(5)
$stream = [System.IO.File]::OpenRead($file.FullName)
$part = [System.Net.Http.StreamContent]::new($stream)
$part.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::new('application/zip')
$form = New-Object System.Net.Http.MultipartFormDataContent
$form.Add($part, 'attachment', $file.Name)
try {
  $assetName = [Uri]::EscapeDataString($file.Name)
  $url = "$api/$($release.id)/assets?name=$assetName"
  $response = $client.PostAsync($url, $form).GetAwaiter().GetResult()
  $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
  if (-not $response.IsSuccessStatusCode) {
    throw "GitVerse asset upload returned HTTP $([int]$response.StatusCode): $($responseBody.Substring(0, [Math]::Min(300, $responseBody.Length)))"
  }
  $asset = $responseBody | ConvertFrom-Json
  if ($asset.name -ne $file.Name -or [long]$asset.size -ne $file.Length) {
    throw 'GitVerse returned an asset with an unexpected name or size.'
  }
  Write-Host "Published Windows asset $($asset.name) ($($asset.size) bytes)."
} finally {
  $form.Dispose()
  $client.Dispose()
}
exit 0
