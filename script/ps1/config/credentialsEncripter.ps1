$credentials = @"
[
    { 
        "account": "帳號1", 
        "password": "密碼1" 
    },
    { 
        "account": "帳號2", 
        "password": "密碼2" 
    }
]
"@ | ConvertFrom-Json

# 建立加密credentials
$credentials | Select account,@{l="passwordEncripted";e={($_.password | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString )}}|
ConvertTo-Json -Depth 100|Out-file "C:\script\ps1\config\credentialsEncripted.json" -Encoding utf8 