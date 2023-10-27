# dir define
```dir
+---c
    +---script              // 各種語言寫成的腳本 
        +---ps1
            +---config              // credential.json,config.json
            +---function            // 共用功能
            +---xxxjob              // 腳本位置(若為單一工作多個腳本應放同一個資料夾)
        +---bat
            ...
        +---sh
            ...
        +---py
            ...
        +---log                 // 存放結果
            +---xxxjob_log          //與job名稱相同方便尋找
```
# 流程圖
> ![flow](/script/ps1/flow.drawio.svg)
# no-ipc-share版本
1. create scan account
    ScanAccount/!QAZ2wsx
2. 分享smb給特定帳號(ScanAccount)並唯獨
    ```ps1
    # 開分享
    New-SmbShare -Name "D" -Path "D:\" -ReadAccess $account

    # 補開權限
    Grant-SmbShareAccess -Name "D" -AccountName $account -AccessRight Read -Force  
    ```
1. 從其他台聯接測試
    ```ps1
    net use * /delete
    net use \\1.1.1.1\d /user:ScanAccount !QAZ2wsx
    ```
* 自動設定讀取分享
    ```ps1
    $account = "ScanAccount"

    # 取得本機硬碟
    $physicalDisks = [Array](
      Get-Disk | Where-Object {
          $_.BusType -notin "iSCSI"
      } | ForEach-Object {
          $_ | Get-Partition | Where-Object {
              -not $_.DriveLetter -eq ""
          }
      } | Select-Object DriveLetter,Size,@{Name = 'Path'; Expression = {$_.Name}}
    )

    # 開分享目錄及賦予讀取權限
    $physicalDisks | ForEach-Object {
        if ("$($_.DriveLetter):\" -in [Array](Get-SmbShare | Where-Object {$_.Name -notlike "*$*"}).Path) {
            # 路徑已分享
            # 確認分享路徑對指定帳號存在Full/Change/Read權限
            $accountHasAnyAccess = [Array](Get-SmbShareAccess -Name "$($_.DriveLetter)" | Where-Object {$_.AccountName -like "*$($account)*"}).AccountName
            if($accountHasAnyAccess.Count -eq 0){
                # 無權限則補開
                Grant-SmbShareAccess -Name $_.DriveLetter -AccountName $account -AccessRight Read -Force
            }
        }else{
            # 路徑未分享
            # 開分享
            New-SmbShare -Name $_.DriveLetter -Path "$($_.DriveLetter):\" -ReadAccess $account
        }
    }
    ```
# linux版本
1. 準備
  * 安裝sshfs-win
  * 安裝winfsp
  * 引入Renci.SshNet.dll
# Todo
* 多線程版本僅在掃毒時多線程，其他不用。
* 放在git公開儲存庫(注意好資安 公司、產品、帳密、mail)
# change log
* 20230901 git控制
* 20230903 修正硬碟判斷，不要讀取ISCSI、SMB的硬碟
* 20230905 修正避開已安裝防毒的機器
* 20230905 抽離config檔案
* 20230907 更細化流程
  1. `1.pingTest.csv`ping測試
    > 所有ips
     1. 成功
        * ping成功訊息
     2. 失敗
        * ping失敗訊息
  2. `2.loginTest.csv`測試login
    > ping成功者
     1. 成功
        * Login成功訊息,ceenditialIndex
     2. 失敗
        * Login失敗訊息
  3. `3.antiVirusCheck.csv`檢查防毒
    > login成功者
     1. 沒裝防毒
        * 沒裝防毒訊息,ceenditialIndex
     2. 已裝防毒
        * 已裝防毒訊息
  4. `4.diskToBeScan.csv`取得diskToBeScanPath
    > 登入成功
    > 未安裝防毒軟體
    > 不是網路磁碟(過濾ISCSI、SMB的硬碟)
    1. 成功
       * 記錄需掃瞄硬碟,ceenditialIndex
  5. `5.diskIsScaned.csv`掃毒
    > 根據DiskList掃毒
    * 此動作可多線程運作
  6. 產報告
    > 全部磁碟掃描完成後，loop全部HTML報表
    1. `6.1.diskListScanReport.csv`統計每個IP下中幾個毒
    2. `6.2.virusReport.csv`loop報表過程發現的病毒抽出來寫入中毒報告。
* 20230917 報表
  * 掃多少IP、可ping幾台                $pingTestPath
	* 登入測試多少台、多少台可登入          $loginTestPath,
	* 可登入之PC中有多少台未安裝防毒        $antiVirusCheckPath,
	* 可登入之PC中未安裝防毒之電腦硬碟清單  $diskToBeScanPath,
	* 已成功掃瞄硬碟清單                  $diskIsScanedPath,
	* 磁碟中毒數量                        $diskListScanReportPath,
	* 病毒報告                            $virusReportPath
* 20231005 可能是因為net use hold太多Get-SmbConnection所以炸掉，改成掃完斷開連線
* 20231005 將登入失敗清單列在mail報告上
* 20231005 加入no-ipc-share版本
* 20231008 no-ipc-share版本修正
  * 若已開路徑分享且未有完整讀寫權限則補開。
  * 掃毒帳號改完整讀寫權限(Read=>Full)。
* 20231005 加入LINUX初始版本
* 20231009 Linux版本加入判斷OS中尚未安裝防毒軟體。
* 20231012 清晰定義Array，防止計算數量時的錯誤。
* 20231012 處理需掃描機器硬碟為0情況的報表。
* 20231012 加入ignore功能