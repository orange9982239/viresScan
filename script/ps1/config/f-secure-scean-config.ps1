$config = @"
{
    "SMTPPort":"{SMTPPort}",
    "SMTPServer":"{SMTPServer}",
    "SMTPTo":"{SMTPTo}",
    "SMTPProduct":"{ProductName}",
    "credentials":[
        { 
            "account": "{帳號1}", 
            "password": "{密碼1}" 
        },
        { 
            "account": "{帳號2}", 
            "password": "{密碼2}" 
        }
    ],
    "ipRanges":[
        {
            "head":"{ips_Head}",
            "start":"{ips_start}",
            "end":"{ips_end}"
        }
    ]
}
"@ | ConvertFrom-Json

# 建立加密credentials
$encryptedCredentials = (
    $config.credentials | ForEach-Object {
        [PSCustomObject]@{
            account = $_.account
            passwordEncripted = ($_.password | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString )
        }
    }
)
$config.credentials = $encryptedCredentials

# 解析ipRanges成ips
$ips = foreach ($ipRange in $config.ipRanges) {
    (($ipRange.start..$ipRange.end) | ForEach-Object { "$($ipRange.head)$($_)" })
}
$config.ips = $ips

$config | ConvertTo-Json -Depth 100|Out-file "C:\script\ps1\config\f-secure-scean-config.json" -Encoding utf8 