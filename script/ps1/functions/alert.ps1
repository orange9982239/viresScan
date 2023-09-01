function telegramAlert{
    param(
        [parameter(mandatory=$true)]
        [string]$chat,
        [string]$message
    )
    Add-Type -AssemblyName System.Web
    $encodedMessage = [System.Web.HttpUtility]::UrlEncode($message)
    Invoke-WebRequest -Uri "http://10.10.75.236/sendmsg.php?userid=$($chat)&msg=$($encodedMessage)"
	
	# call function

	# Import-Module C:\script\ps1\functions\alert.ps1

	# $message = @"
	# 在測試一次
	# #防毒告警測試
	# \\10.10.24.232\c$\pagefile.sys
	# \\10.10.24.232\c$\ProgramData\Microsoft\Diagnosis\events00.rbs
	# 多行測試
	# 1
	# 2
	# 3
	# "@
	# telegramAlert -chat "CMN_Alert" -message $message
	# telegramAlert -chat "Mabi-Alert" -message $message
}
