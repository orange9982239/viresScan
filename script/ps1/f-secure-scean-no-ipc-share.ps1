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
$diskToBeScanPath = "$($outputFolderPath)\4.diskToBeScan.csv"
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

# 2.LoginTest
$pingTest = [Array](Get-Content $pingTestPath | ConvertFrom-Csv)
$pingSuccessIp = $pingTest | Where-Object {$_.isPingSuccess -eq 1}
foreach ($PC in $pingSuccessIp) {
    # time,ip,loginResult,credentialIndex 存至 loginTestPath
    foreach ($credential in $credentials) {
        try {
            Invoke-Command -ComputerName $PC.ip -ScriptBlock {
                Write-Host "Hi"
            } -credential $credential -ErrorAction Stop

            $data = [PSCustomObject]@{
                time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                ip = $PC.ip
                loginResult = 1
                credentialIndex = [Array]::IndexOf($credentials,$credential)
            }
            saveCsv -outputFilePath $loginTestPath -data $data
            # 換下一個IP
            break
        } catch {
            if(([Array]::IndexOf($credentials,$credential)+1) -eq $credentials.Count){
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
    }
}

# 3.AntiVirusCheck
$loginTest = [Array](Get-Content $loginTestPath | ConvertFrom-Csv)
$loginSuccessPC = $loginTest | Where-Object {$_.loginResult -eq 1}
foreach ($PC in $LoginSuccessPC) {
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
}


# 4.List Disk To Be Scan
$antiVirusCheck = [Array](Get-Content $antiVirusCheckPath | ConvertFrom-Csv)
$pcWithoutAntiVirus = $antiVirusCheck | Where-Object {$_.hasAntiVirus -eq 0}
foreach ($PC in $pcWithoutAntiVirus) {
    # time,ip,credentialIndex,diskunc 存至 diskToBeScanPath
    $credential = $credentials[$PC.credentialIndex]
    $account = $credential.UserName
    $PhysicalDiskUNCs = (
        Invoke-Command -ComputerName $PC.ip -ScriptBlock {
            # 1. 取出所有非網路連線的磁碟
            $physicalDisks = [Array] (
                Get-Disk | Where-Object {
                    $_.BusType -notin "iSCSI"
                } | ForEach-Object {
                    $_ | Get-Partition | Where-Object {
                        -not $_.DriveLetter -eq ""
                    }
                } | Select-Object DriveLetter,Size,@{Name = 'Path'; Expression = {$_.Name}}
            )

            # 2. 檢查磁碟未開分享者開啟，檢查未允許掃毒帳號權限者加入
            (
                $physicalDisks | ForEach-Object {
                    if ("$($_.DriveLetter):\" -in (Get-SmbShare | Where-Object {$_.Name -notlike "*$"}).Path) {
                        # 路徑已分享
                        # 確認分享路徑有Full讀寫權限
                        $fullAccessAccount = (Get-SmbShareAccess -Name C$ | Where-Object {$_.AccessRight -eq "Full"}).AccountName
                        if($fullAccessAccount -notcontains $account){
                            # 無權限則補開
                            Add-SmbShareAccess -Name $_.DriveLetter -AccountName $using:account -AccessRight Full -Force
                        }
                    }else{
                        # 路徑未分享
                        # 開分享
                        New-SmbShare -Name $_.DriveLetter -Path "$($_.DriveLetter):\" -FullAccess $using:account
                    }
                }
            ) | Out-Null

            $physicalDisks
        } -credential $credential
    ) | ForEach-Object {"\\$($PC.ip)\$($_.DriveLetter.ToString().ToLower())"}

    foreach ($PhysicalDiskUNC in $PhysicalDiskUNCs) {
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            ip = $PC.ip
            credentialIndex = $PC.credentialIndex
            diskunc = $PhysicalDiskUNC
        }
        saveCsv -outputFilePath $diskToBeScanPath -data $data
    }
}
if (Test-Path $diskToBeScanPath) {
    # 5.Scan 
    $diskToBeScan = (Get-Content $diskToBeScanPath | ConvertFrom-Csv)
    foreach ($disk in $diskToBeScan) {
        # time,ip,diskunc,isScaned,scanReport 存至 diskIsScaned
        
        # 掃毒smb路徑並存檔到C:\script\log\f-secure-scean_log\yyyymmdd\scan_log_127.0.0.1_c$.html
        try {
            # 連線smb(根據CredentialIndex取出特定Credential)
            $credential = $credentials[$disk.CredentialIndex]
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
            saveCsv -outputFilePath $diskIsScanedPath -data $data
            net use $($disk.diskunc) /delete
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
        $diskScanReport = [Array](virusReportReader $(Get-Content -path $disk.scanReport -raw -Encoding UTF8))
        
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