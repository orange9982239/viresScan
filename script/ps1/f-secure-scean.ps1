# add env
$env:Path += ';C:\Program Files (x86)\F-Secure\Server Security\'

# Import-Module
Import-Module C:\script\ps1\functions\saveCsv.ps1
Import-Module C:\script\ps1\functions\alert.ps1
Import-Module C:\script\ps1\functions\virusReportReader.ps1
Import-Module C:\script\ps1\functions\createHtmlReport.ps1

# load config file
$config = (Get-Content -Raw -Path "C:\script\ps1\config\f-secure-scean-config.json" | ConvertFrom-Json)
$credentials = $config.$credentials | ForEach-Object {
    New-Object System.Management.Automation.PSCredential (
        $_.account,
        ($_.passwordEncripted | ConvertTo-SecureString)
    )
}
$outputFolderPath = "C:\script\log\f-secure-scean_log\$((Get-Date).ToString("yyyyMMdd"))"    # 放csv簡述報告及所有HTML報告dir
$IPRangeArray = $config.ips

# 全網段掃描結果 networkScanReport.csv
# 硬碟清單 diskScanReport.csv
$networkScanReportPath = "$($outputFolderPath)\networkScanReport.csv"
$diskScanReportPath = "$($outputFolderPath)\diskScanReport.csv"
foreach ($IP in $IPRangeArray) {
    Write-Host "================$($IP) strat =================="
    # test ping 
    if ((Test-Connection $IP -Count 1 -Quiet) -eq $false) {
        # 產報告
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            Ip = $IP
            message = "ping不通"
        }
        saveCsv -outputFilePath $networkScanReportPath -data $data

        # ping不通就換下一個IP
        continue    
    }
    
    # test windows login
    foreach ($credential in $credentials) {
        try {
            # 避開已安裝防毒的機器
            $isInstallAntivirus = (
                Invoke-Command -ComputerName $IP -ScriptBlock {
                    Test-Path "C:\Program Files (x86)\F-Secure\Server Security\fsscan.exe" -PathType Leaf
                } -credential $credential -ErrorAction Stop
            )
            if ($isInstallAntivirus) {
                # 已安裝防毒軟體  
                $data = [PSCustomObject]@{
                    time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                    Ip = $IP
                    message = "已安裝防毒，無須遠端掃描"
                }
                saveCsv -outputFilePath $networkScanReportPath -data $data
            } else {
                # 未已安裝防毒軟體
                $data = [PSCustomObject]@{
                    time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                    Ip = $IP
                    message = "WinRM登入成功"
                }
                saveCsv -outputFilePath $networkScanReportPath -data $data                  
                
                # 記錄將掃描之硬碟
                $PhysicalDiskUNCs = (
                    Invoke-Command -ComputerName $IP -ScriptBlock {
                        Get-Disk | Where-Object {
                            $_.BusType -notin "iSCSI"
                        }| ForEach-Object {
                        $_ | Get-Partition | Where-Object {
                                -not $_.DriveLetter -eq ""
                            }
                        } | Select-Object DriveLetter,Size
                    } -credential $credential -ErrorAction Stop
                ) | ForEach-Object {"\\$($IP)\$($_.DriveLetter.ToLower())$"}
    
                foreach ($DiskUnc in $PhysicalDiskUNCs) {
                    $data = [PSCustomObject]@{
                        time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                        Ip = $IP
                        ScanType = "smb"
                        CredentialIndex = $credentials.IndexOf($credential)
                        DiskUnc = $DiskUnc
                    }
                    # 存csv
                    saveCsv -outputFilePath $diskScanReportPath -data $data
                }
            }
            # 換下一個IP
            break
        } catch {
            if(($credentials.IndexOf($credential)+1) -eq $credentials.Count){
                $data = [PSCustomObject]@{
                    time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                    Ip = $IP
                    message = "嘗試了所有的credential仍無法登入WinRM"
                }
                # 存csv
                saveCsv -outputFilePath $networkScanReportPath -data $data
            }
        }
    }
    # linux test login
    # foreach ($credential in $credentials) {
    #     try {
    #         # 用sshfs直接mount?
    #         $data = [PSCustomObject]@{
    #             time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
    #             Ip = $IP
    #             ScanType = "sftp"
    #             CredentialIndex = $credentials.IndexOf($credential)
    #             DiskUnc = "====linuxSFTPDiskUNC====="
    #         }
    #         # 存csv
    #         saveCsv -outputFilePath $diskScanReportPath -data $data

    #         $data = [PSCustomObject]@{
    #             time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
    #             Ip = $IP
    #             message = "SSH登入成功"
    #         }
    #         saveCsv -outputFilePath $networkScanReportPath -data $data
    #         # 登入成功並完成掃描就換下一個IP
    #         break
    #     } catch {
    #         if(($credentials.IndexOf($credential)+1) -eq $credentials.Count){
    #             # 產報告
    #             $data = [PSCustomObject]@{
    #                 time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
    #                 Ip = $IP
    #                 message = "嘗試了所有的credential仍無法登入ssh"
    #             }
    #             # 存csv
    #             saveCsv -outputFilePath $networkScanReportPath -data $data
    #         }
    #     }
    # }
}

# 列出各個DiskUnc掃毒結果(只顯示中毒數量) diskVirusScanReport_yyyymmdd.csv
# 列出所有中毒檔案路徑 VirusReport_yyyymmdd.csv

$diskVirusScanReportPath = "$($outputFolderPath)\diskVirusScanReport.csv"
$virusReportPath = "$($outputFolderPath)\VirusReport.csv"
$diskScanReport = (Get-Content $diskScanReportPath | ConvertFrom-Csv)

foreach ($disk in $diskScanReport) {
    # 連線smb(根據CredentialIndex取出特定Credential)
    $credential = $credentials[$disk.CredentialIndex]
    if (-Not (Test-Path $disk.DiskUnc)){
        net use $($disk.DiskUnc) /user:$($credential.GetNetworkCredential().username) $($credential.GetNetworkCredential().password)
    }
    
    # 掃毒smb路徑並存檔到C:\script\log\f-secure-scean_log\yyyymmdd\scan_log_127.0.0.1_c$.html
    $reportFilePath = "$($outputFolderPath)\scan_log_$($disk.Ip)_$($disk.DiskUnc.substring($disk.DiskUnc.Length -2)).html"
    fsscan $($disk.DiskUnc) /report=$reportFilePath
    
    # 中毒報告取回資料
    $VirusInReport = (virusReportReader $(Get-Content -path $reportFilePath -raw -Encoding UTF8))

    # 列出各個DiskUnc掃毒結果(只顯示中毒數量)
    if ($VirusInReport.Count -eq 0) {
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            Ip = $disk.Ip
            DiskUnc = $disk.DiskUnc
            message = "沒有中毒"
        }
        saveCsv -outputFilePath $diskVirusScanReportPath -data $data
    } else {
        # 補個mail告警

        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            Ip = $disk.Ip
            DiskUnc = $disk.DiskUnc
            message = "中了$($VirusInReport.Count)個毒"
        }
        saveCsv -outputFilePath $diskVirusScanReportPath -data $data

        # 列出所有中毒檔案路徑
        $VirusInReport | ForEach-Object {
            $data = [PSCustomObject]@{
                time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                Ip = $disk.Ip
                DiskUnc = $disk.DiskUnc
                VirusType = $_.type
                VirusPath = $_.path
            }
            saveCsv -outputFilePath $virusReportPath -data $data
        }
    }
}

# 壓縮資料夾成zip檔案
$outputFolderZipFilePath = "$($outputFolderPath).zip"
Compress-Archive -Path $outputFolderPath -DestinationPath $outputFolderZipFilePath -Force

# 寄信+zip
$EmailParams = @{
    To          = $config.SMTPTo
    # Cc          = $Cc
    From        = "fsecureScan@gamania.com"
    Subject     = "[ITGT] $($config.SMTPProduct)_掃毒報告_$((Get-Date).ToString("yyyyMMdd"))"
    Body        = createHtmlReport($networkScanReportPath,$diskVirusScanReportPath,$virusReportPath)
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