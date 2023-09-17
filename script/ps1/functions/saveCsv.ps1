# 將單一PSCustomObject寫入Csv的函數

# EX:
# $data1 = [PSCustomObject]@{
#     testcol1="testcal1val1"
#     testcol2="testcal2val1"
# }
# saveCsv -outputFilePath "C:\powershell\test$((Get-Date).ToString("yyyyMMdd")).csv" -data $data1

function saveCsv($outputFilePath,[PSCustomObject]$data,$isPrint=$false) {
    # 印出結果
    if($isPrint -eq $true){
        $data | Format-Table 
    }
    
    # 存csv
    if (Test-Path $outputFilePath) {
        Export-Csv -InputObject $data -Path $outputFilePath -NoTypeInformation -Encoding UTF8 -Append -Force
        # $data | Export-Csv $outputFilePath -NoTypeInformation -Encoding UTF8 -Append -Force
    } else {
        New-Item -Path $outputFilePath -ItemType File -Force
        Export-Csv -InputObject $data -Path $outputFilePath -NoTypeInformation -Encoding UTF8
        # $data | Export-Csv $outputFilePath -NoTypeInformation -Encoding UTF8 
    }
}

# 將單一PSCustomObject寫入Csv的函數，為了處裡多線程IO不足導致漏資料問題，採用線程鎖Mutex在寫入前先獨占檔案使用權。

# EX:
# $data1 = [PSCustomObject]@{
#     testcol1="testcal1val1"
#     testcol2="testcal2val1"
# }
# saveCsvWithMutex -outputFilePath "C:\powershell\test$((Get-Date).ToString("yyyyMMdd")).csv" -data $data1
function saveCsvWithMutex($outputFilePath,[PSCustomObject]$data,$isPrint=$false) {
    # 印出結果
    if($isPrint -eq $true){
        $data | Format-Table 
    }
    
    # 建立互斥鎖
    $mtx = New-Object System.Threading.Mutex($false,(Split-Path $outputFilePath -leaf))
    
    # 等待其他互斥鎖解除後存csv
    try {
        if ($mtx.WaitOne()) {
            if (Test-Path $outputFilePath) {	
                Export-Csv -InputObject $data -Path $outputFilePath -NoTypeInformation -Encoding UTF8 -Append -Force
            } else {
                New-Item -Path $outputFilePath -ItemType File -Force
                Export-Csv -InputObject $data -Path $outputFilePath -NoTypeInformation -Encoding UTF8
            }
        }
    } catch [System.Threading.AbandonedMutexException]{
        [void]$mtx.ReleaseMutex()
        Write-Warning "CAUGHT EXCEPTION"
    }
    
    # 釋放互斥鎖
    $mtx.ReleaseMutex()
}

# 將 PSCustomObject"陣列"寫入Csv的函數

# EX:
# $datas = @(
#     [PSCustomObject]@{
#         testcol1="testcal1val1"
#         testcol2="testcal2val1"
#     },
#     [PSCustomObject]@{
#         testcol1="testcal1val2"
#         testcol2="testcal2val2"
#     },
#     [PSCustomObject]@{
#         testcol1="testcal1val3"
#         testcol2="testcal2val3"
#     }
# )
# saveArrayToCsv -outputFilePath "C:\test$((Get-Date).ToString("yyyyMMdd")).csv" -data $datas
function saveArrayToCsv($outputFilePath,[PSCustomObject[]]$datas,$isPrint=$false) {
    # 印出結果
    foreach ($data in $datas) {
        if($isPrint -eq $true){
            $data | Format-Table 
        }
        
        # 存csv
        if (Test-Path $outputFilePath) {
            Export-Csv -InputObject $data -Path $outputFilePath -NoTypeInformation -Encoding UTF8 -Append -Force
            # $data | Export-Csv $outputFilePath -NoTypeInformation -Encoding UTF8 -Append -Force
        } else {
            New-Item -Path $outputFilePath -ItemType File -Force
            Export-Csv -InputObject $data -Path $outputFilePath -NoTypeInformation -Encoding UTF8
            # $data | Export-Csv $outputFilePath -NoTypeInformation -Encoding UTF8 
        }
    }
}

# 將 PSCustomObject"陣列"寫入Csv的函數，採用線程鎖Mutex在寫入前先獨占檔案使用權。

# EX:
# $datas = @(
#     [PSCustomObject]@{
#         testcol1="testcal1val1"
#         testcol2="testcal2val1"
#     },
#     [PSCustomObject]@{
#         testcol1="testcal1val2"
#         testcol2="testcal2val2"
#     },
#     [PSCustomObject]@{
#         testcol1="testcal1val3"
#         testcol2="testcal2val3"
#     }
# )
# saveArrayToCsvWithMutex -outputFilePath "C:\test$((Get-Date).ToString("yyyyMMdd")).csv" -data $datas
function saveArrayToCsvWithMutex($outputFilePath,[PSCustomObject[]]$datas,$isPrint=$false) {
    # 印出結果
    foreach ($data in $datas) {
        if($isPrint -eq $true){
            $data | Format-Table 
        }
        
        # 建立互斥鎖
        $mtx = New-Object System.Threading.Mutex($false,(Split-Path $outputFilePath -leaf))
        
        # 等待其他互斥鎖解除後存csv
        try {
            if ($mtx.WaitOne()) {
                if (Test-Path $outputFilePath) {	
                    Export-Csv -InputObject $data -Path $outputFilePath -NoTypeInformation -Encoding UTF8 -Append -Force
                } else {
                    New-Item -Path $outputFilePath -ItemType File -Force
                    Export-Csv -InputObject $data -Path $outputFilePath -NoTypeInformation -Encoding UTF8
                }
            }
        } catch [System.Threading.AbandonedMutexException]{
            [void]$mtx.ReleaseMutex()
            Write-Warning "CAUGHT EXCEPTION"
        }
        
        # 釋放互斥鎖
        $mtx.ReleaseMutex()
    }
}