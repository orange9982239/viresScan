# Load the SSH.NET assembly
Add-Type -Path "C:\script\dll\Renci.SshNet.dll"
# add env
$env:Path += ';C:\Program Files (x86)\F-Secure\Server Security\'

# Import-Module
Import-Module C:\script\ps1\functions\saveCsv.ps1
Import-Module C:\script\ps1\functions\alert.ps1
Import-Module C:\script\ps1\functions\virusReportReader.ps1
Import-Module C:\script\ps1\functions\createHtmlReport.ps1

# load config file
$config = (Get-Content -Raw -Path "C:\script\ps1\config\f-secure-scean-config.json" | ConvertFrom-Json)
$credentials = $config.credentials | ForEach-Object {
    New-Object System.Management.Automation.PSCredential (
        $_.account,
        ($_.passwordEncripted | ConvertTo-SecureString)
    )
}
$startDateYYYYMMDDString = (Get-Date).ToString("yyyyMMdd")
$outputFolderPath = "C:\script\log\f-secure-scean_log\$($startDateYYYYMMDDString)"    # 放csv簡述報告及所有HTML報告dir

# output csv
$pingTestPath = "$($outputFolderPath)\1.pingTest.csv"
$loginTestPath = "$($outputFolderPath)\2.LoginTest.csv"
$antiVirusCheckPath = "$($outputFolderPath)\3.AntiVirusCheck.csv"
# $diskToBeScanPath = "$($outputFolderPath)\4.diskToBeScan.csv"
$diskIsScanedPath = "$($outputFolderPath)\5.diskIsScaned.csv"
$diskListScanReportPath = "$($outputFolderPath)\6.1.DiskListScanReport.csv"
$virusReportPath = "$($outputFolderPath)\6.2.VirusReport.csv"

# 1.pingTest
foreach ($IP in $config.ips) {
    # time,ip,isPingSuccess 存至 pingTestPath
    if ((Test-Connection $IP -Count 1 -Quiet)) {
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $IP
            isPingSuccess = 1
        }
        saveCsv -outputFilePath $pingTestPath -data $data
    }else {
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $IP
            isPingSuccess = 0
        }
        saveCsv -outputFilePath $pingTestPath -data $data
    }
}

# 2.LoginTest(LINUX)
$pingTest = (Get-Content $pingTestPath | ConvertFrom-Csv)
$pingSuccessIp = $pingTest | Where-Object {$_.isPingSuccess -eq 1}
foreach ($PC in $pingSuccessIp) {
    # time,ip,loginResult,credentialIndex 存至 loginTestPath
    foreach ($credential in $credentials) {
        # Create an SSH client session
        $sshClient = New-Object Renci.SshNet.SshClient(
            $PC.ip, 
            22, 
            $credential.GetNetworkCredential().username, 
            $credential.GetNetworkCredential().password
        )

        try {
            $sshClient.Connect()
            $sshCommand = $sshClient.RunCommand("ls -l")
            $result = $sshCommand.Result
            Write-Host $result 

            $data = [PSCustomObject]@{
                time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                ip = $PC.ip
                loginResult = 1
                credentialIndex = $credentials.IndexOf($credential)
            }
            saveCsv -outputFilePath $loginTestPath -data $data
            # 換下一個IP
            break
        }
        catch {
            if(($credentials.IndexOf($credential)+1) -eq $credentials.Count){
                $data = [PSCustomObject]@{
                    time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                    ip = $PC.ip
                    loginResult = 0
                    credentialIndex = ""
                }
                # 存csv
                saveCsv -outputFilePath $loginTestPath -data $data
            }
        }
        finally {
            # Disconnect the SSH session
            $sshClient.Disconnect()
            $sshClient.Dispose()
        }
    }
}

# 3.AntiVirusCheck
$loginTest = (Get-Content $loginTestPath | ConvertFrom-Csv)
$loginSuccessPC = $loginTest | Where-Object {$_.loginResult -eq 1}
foreach ($PC in $LoginSuccessPC) {
    # time,ip,hasAntiVirus,credentialIndex 存至 antiVirusCheckPath
    $credential = $credentials[$PC.CredentialIndex]
    $sshClient = New-Object Renci.SshNet.SshClient(
        $PC.ip, 
        22, 
        $credential.GetNetworkCredential().username, 
        $credential.GetNetworkCredential().password
    )
    $sshClient.Connect()
    $sshCommand = $sshClient.RunCommand("
        if [ -e /opt/f-secure/linuxsecurity/bin/fsanalyze ]; then
            echo 1
        else
            echo 0
        fi
    ")
    if ($sshCommand.Result -eq 1) {
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $PC.ip
            hasAntiVirus = 1
            credentialIndex = $PC.credentialIndex
        }
        saveCsv -outputFilePath $antiVirusCheckPath -data $data
    } else {
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $PC.ip
            hasAntiVirus = 0
            credentialIndex = $PC.credentialIndex
        }
        saveCsv -outputFilePath $antiVirusCheckPath -data $data
    }
    $sshClient.Disconnect()
    $sshClient.Dispose()
}

# 5.Scan 
$PCToBeScan = (Get-Content $antiVirusCheckPath | Where-Object {$_.hasAntiVirus -eq 0} | ConvertFrom-Csv)
foreach ($PC in $PCToBeScan) {
    # time,ip,diskunc,isScaned,scanReport 存至 diskIsScaned
    
    # 掃毒smb路徑並存檔到C:\script\log\f-secure-scean_log\yyyymmdd\scan_log_127.0.0.1_c$.html
    try {
        # 連線smb(根據CredentialIndex取出特定Credential)
        $credential = $credentials[$PC.CredentialIndex]

        $sshString = "$($credential.GetNetworkCredential().username)@$($PC.ip)"
        $sshUncPath = "\\sshfs.r\$($sshString)"

        if (-Not (Test-Path $sshUncPath)){
            # net use \\sshfs.r\account@1.1.1.1 /persistent:yes PASSWORD
            net use $sshUncPath /persistent:yes "$($credential.GetNetworkCredential().password)"
        }

        $reportFilePath = "$($outputFolderPath)\scan_log_$($sshUncPath)).html"
        fsscan $($PC.diskunc) /report=$reportFilePath
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $PC.ip
            diskunc = $sshUncPath
            isScaned =  1
            scanReport = $reportFilePath
            message = "掃毒完成"
        }
        saveCsv -outputFilePath $diskIsScanedPath -data $data

        # net use \\sshfs.r\account@1.1.1.1 /del
        net use $sshUncPath /del
    }
    catch {
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $disk.ip
            diskunc = ""
            isScaned =  0
            scanReport = ""
            message = "連接網路磁碟$($disk.diskunc)出錯，錯誤訊息: $($_.Exception.Message)"
        }
        saveCsv -outputFilePath $diskIsScanedPath -data $data
    }
}

# 6.Report
$diskIsScaned = (Get-Content $diskIsScanedPath | ConvertFrom-Csv)
foreach ($disk in $diskIsScaned) {
    ## 6.1.diskListScanReport
    ### time,diskunc,virusCount 存至 diskListScanReportPath
    ## 6.2.virusReport
    ### time,virusName,virusPath 存至 virusReportPath
    $diskScanReport = (virusReportReader $(Get-Content -path $disk.scanReport -raw -Encoding UTF8))
    
    $data = [PSCustomObject]@{
        time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
        ip = $disk.ip
        diskunc = $disk.diskunc
        virusCount = $diskScanReport.Count
    }
    saveCsv -outputFilePath $diskListScanReportPath -data $data

    if ($diskScanReport.Count -gt 0) {
        $diskScanReport | ForEach-Object {
            $data = [PSCustomObject]@{
                time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                ip = $disk.ip
                diskunc = $disk.diskunc
                virusName = $_.type
                virusPath = $_.path
            }
            saveCsv -outputFilePath $virusReportPath -data $data
        }
    }
}

# 壓縮資料夾成zip檔案
$outputFolderZipFilePath = "$($outputFolderPath).zip"
Compress-Archive -Path $outputFolderPath -DestinationPath $outputFolderZipFilePath -Force

$HtmlBodyString = (createHtmlReport $pingTestPath $loginTestPath $antiVirusCheckPath $diskToBeScanPath $diskIsScanedPath $diskListScanReportPath $virusReportPath)

# 寄信+zip
$EmailParams = @{
    To          = $config.SMTPTo
    # Cc          = $Cc
    From        = $config.SMTPFrom
    Subject     = "$($config.SMTPSubject)_$($startDateYYYYMMDDString)"
    Body        = $HtmlBodyString
    BodyAsHtml  = $true
    Priority    = "High"
    SMTPServer  = $config.SMTPServer
    Port        = $config.SMTPPort
    Encoding    = "UTF8"
    Attachments = $outputFolderZipFilePath
}
Send-MailMessage @EmailParams

# 刪除zip檔案
Remove-Item -Path $outputFolderZipFilePath