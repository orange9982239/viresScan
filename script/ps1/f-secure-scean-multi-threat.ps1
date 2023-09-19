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
$outputFolderPath = "C:\script\log\f-secure-scean_log\$((Get-Date).ToString("yyyyMMdd"))"    # 放csv簡述報告及所有HTML報告dir

# output csv
$pingTestPath = "$($outputFolderPath)\1.pingTest.csv"
$loginTestPath = "$($outputFolderPath)\2.LoginTest.csv"
$antiVirusCheckPath = "$($outputFolderPath)\3.AntiVirusCheck.csv"
$diskToBeScanPath = "$($outputFolderPath)\4.diskToBeScan.csv"
$diskIsScanedPath = "$($outputFolderPath)\5.diskIsScaned.csv"
$diskListScanReportPath = "$($outputFolderPath)\6.1.DiskListScanReport.csv"
$virusReportPath = "$($outputFolderPath)\6.2.VirusReport.csv"

# 1.pingTest
$config.ips | ForEach-Object -Parallel {
    Import-Module C:\script\ps1\functions\saveCsv.ps1
    $pingTestPath = $using:pingTestPath
    $IP = $_
    # time,ip,isPingSuccess 存至 pingTestPath
    if ((Test-Connection $IP -Count 1 -Quiet)) {
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $IP
            isPingSuccess = 1
        }
        saveCsvWithMutex -outputFilePath $pingTestPath -data $data
    }else {
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $IP
            isPingSuccess = 0
        }
        saveCsvWithMutex -outputFilePath $pingTestPath -data $data
    }
} -ThrottleLimit 20

# 2.LoginTest
$pingTest = (Get-Content $pingTestPath | ConvertFrom-Csv)
$pingSuccessIp = $pingTest | Where-Object {$_.isPingSuccess -eq 1}
$pingSuccessIp | ForEach-Object -Parallel {
    Import-Module C:\script\ps1\functions\saveCsv.ps1
    $PC = $_
    $credentials = $using:credentials
    $loginTestPath = $using:loginTestPath

    foreach ($credential in $credentials) {
        try {
            $isLoginSuccess = (
                Invoke-Command -ComputerName $PC.ip -ScriptBlock {
                    return $true
                } -credential $credential -ErrorAction Stop
            )
            if ($isLoginSuccess) {
                Write-Host "$($PC.ip) is login success by credential[$($credentials.IndexOf($credential))]"
            }

            $data = [PSCustomObject]@{
                time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                ip = $PC.ip
                loginResult = 1
                credentialIndex = $credentials.IndexOf($credential)
            }
            saveCsvWithMutex -outputFilePath $loginTestPath -data $data
            # 換下一個IP
            break
        } catch {
            if(($credentials.IndexOf($credential)+1) -eq $credentials.Count){
                $data = [PSCustomObject]@{
                    time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                    ip = $PC.ip
                    loginResult = 0
                    credentialIndex = ""
                }
                # 存csv
                saveCsvWithMutex -outputFilePath $loginTestPath -data $data
            }
        }
    }
} -ThrottleLimit 20

# 3.AntiVirusCheck
$loginTest = (Get-Content $loginTestPath | ConvertFrom-Csv)
$loginSuccessPC = $loginTest | Where-Object {$_.loginResult -eq 1}
$LoginSuccessPC | ForEach-Object -Parallel {
    Import-Module C:\script\ps1\functions\saveCsv.ps1
    $PC = $_
    $credentials = $using:credentials
    $antiVirusCheckPath = $using:antiVirusCheckPath

    # time,ip,hasAntiVirus,credentialIndex 存至 antiVirusCheckPath
    $isInstallAntivirus = (
        Invoke-Command -ComputerName $PC.ip -ScriptBlock {
            Test-Path "C:\Program Files (x86)\F-Secure\Server Security\fsscan.exe" -PathType Leaf
        } -credential $credentials[$PC.credentialIndex] -ErrorAction Stop
    )

    if ($isInstallAntivirus) {
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $PC.ip
            hasAntiVirus = 1
            credentialIndex = $PC.credentialIndex
        }
        saveCsvWithMutex -outputFilePath $antiVirusCheckPath -data $data
    } else {
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $PC.ip
            hasAntiVirus = 0
            credentialIndex = $PC.credentialIndex
        }
        saveCsvWithMutex -outputFilePath $antiVirusCheckPath -data $data
    }
} -ThrottleLimit 5

# 4.List Disk To Be Scan
$antiVirusCheck = (Get-Content $antiVirusCheckPath | ConvertFrom-Csv)
$pcWithoutAntiVirus = $antiVirusCheck | Where-Object {$_.hasAntiVirus -eq 0}
$pcWithoutAntiVirus | ForEach-Object -Parallel {
    Import-Module C:\script\ps1\functions\saveCsv.ps1
    $PC = $_
    $credentials = $using:credentials
    $diskToBeScanPath = $using:diskToBeScanPath
    # time,ip,credentialIndex,diskunc 存至 diskToBeScanPath
    $PhysicalDiskUNCs = (
        Invoke-Command -ComputerName $PC.ip -ScriptBlock {
            Get-Disk | Where-Object {
                $_.BusType -notin "iSCSI"
            } | ForEach-Object {
                $_ | Get-Partition | Where-Object {
                    -not $_.DriveLetter -eq ""
                }
            } | Select-Object DriveLetter,Size
        } -credential $credentials[$PC.credentialIndex]
    ) | ForEach-Object {"\\$($PC.ip)\$($_.DriveLetter.ToString().ToLower())$"}

    foreach ($PhysicalDiskUNC in $PhysicalDiskUNCs) {
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $PC.ip
            credentialIndex = $PC.credentialIndex
            diskunc = $PhysicalDiskUNC
        }
        saveCsvWithMutex -outputFilePath $diskToBeScanPath -data $data
    }
} -ThrottleLimit 5

# 5.Scan 
$diskToBeScan = (Get-Content $diskToBeScanPath | ConvertFrom-Csv)
$diskToBeScan | ForEach-Object -Parallel {
    # add env
    $env:Path += ';C:\Program Files (x86)\F-Secure\Server Security\'
    # Import-Module
    Import-Module C:\script\ps1\functions\saveCsv.ps1
    # 外部variable引入
    $disk = $_
    $credentials = $using:credentials
    $diskIsScanedPath = $using:diskIsScanedPath
    $outputFolderPath = $using:outputFolderPath
    # time,ip,diskunc,isScaned,scanReport 存至 diskIsScaned
        
    # 掃毒smb路徑並存檔到C:\script\log\f-secure-scean_log\yyyymmdd\scan_log_127.0.0.1_c$.html
    try {
        # 連線smb(根據credentialIndex取出特定Credential)
        $credential = $credentials[$disk.credentialIndex]
        if (-Not (Test-Path $disk.diskunc)){
            net use $($disk.diskunc) /user:$($credential.GetNetworkCredential().username) $($credential.GetNetworkCredential().password)
        }
        $reportFilePath = "$($outputFolderPath)\scan_log_$($disk.ip)_$($disk.diskunc.substring($disk.diskunc.Length -2)).html"
        fsscan $($disk.diskunc) /report=$reportFilePath
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $disk.ip
            diskunc = $disk.diskunc
            isScaned =  1
            scanReport = $reportFilePath
            message = "掃毒完成"
        }
        saveCsvWithMutex -outputFilePath $diskIsScanedPath -data $data
    }
    catch {
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $disk.ip
            diskunc = $disk.diskunc
            isScaned =  0
            scanReport = ""
            message = "連接網路磁碟$($disk.diskunc)出錯，錯誤訊息: $($_.Exception.Message)"
        }
        saveCsvWithMutex -outputFilePath $diskIsScanedPath -data $data
    }
} -ThrottleLimit 5

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
    saveCsvWithMutex -outputFilePath $diskListScanReportPath -data $data

    if ($diskScanReport.Count -gt 0) {
        $diskScanReport | ForEach-Object {
            $data = [PSCustomObject]@{
                time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                ip = $disk.ip
                diskunc = $disk.diskunc
                virusName = $_.type
                virusPath = $_.path
            }
            saveCsvWithMutex -outputFilePath $virusReportPath -data $data
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
    Subject     = "$($config.SMTPSubject)_$((Get-Date).ToString("yyyyMMdd"))"
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