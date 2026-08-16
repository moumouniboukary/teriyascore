$ErrorActionPreference = "Stop"
$api = "https://teriyascore-api.onrender.com"
$phone = "+22670" + (Get-Random -Minimum 100000 -Maximum 999999)

function PostJson($url, $body) {
  Invoke-RestMethod -Method Post -Uri $url -ContentType "application/json" -Body ($body | ConvertTo-Json)
}

Write-Host "OTP $phone"
$otp = PostJson "$api/auth/otp/request" @{ phone = $phone; purpose = "register" }
$code = $otp.devCode
if (-not $code) { throw "pas de devCode (SMS mode?)" }
$verify = PostJson "$api/auth/otp/verify" @{ phone = $phone; code = $code; purpose = "register" }
$reg = PostJson "$api/auth/register" @{
  phone = $phone; pin = "8362"; displayName = "Test ML Render"; language = "fr"; otpToken = $verify.otpToken
}
$token = $reg.accessToken
if (-not $token) { $token = $reg.tokens.accessToken }
$h = @{ Authorization = "Bearer $token" }
$score = Invoke-RestMethod -Method Post -Uri "$api/score/recalculate" -Headers $h -ContentType "application/json" -Body "{}"
Write-Host ("score={0} engine={1} modelVersion={2}" -f $score.score, $score.engine, $score.modelVersion)
if ($score.engine -eq "ml") { Write-Host "ML_OK" } else { Write-Host "HEURISTIC_ONLY" }
