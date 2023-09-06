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

# todo
* 更細化流程
  1. `1.pingTest.csv`ping測試
    > 所有ips
     1. 成功
        * ping成功訊息
     2. 失敗
        * ping失敗訊息
  2. `2.LoginTest.csv`測試login
    > ping成功者
     1. 成功
        * Login成功訊息,ceenditialIndex
     2. 失敗
        * Login失敗訊息
  3. `3.AntiVirusTest.csv`檢查防毒
    > login成功者
     1. 沒裝防毒
        * 沒裝防毒訊息,ceenditialIndex
     2. 已裝防毒
        * 已裝防毒訊息
  4. `4.DiskList.csv`取得DiskList
    > 登入成功
    > 未安裝防毒軟體
    > 不是網路磁碟(過濾ISCSI、SMB的硬碟)
    1. 成功
       * 記錄需掃瞄硬碟,ceenditialIndex
  5. 掃毒
    > 根據DiskList掃毒
    * 此動作可多線程運作
  6. 產報告
    > 全部磁碟掃描完成後，loop全部HTML報表
    1. `5.1.DiskListScanReport.csv`統計每個IP下中幾個毒
    2. `5.2.VirusReport.csv`loop報表過程發現的病毒抽出來寫入中毒報告。
* 多線程版本僅在掃毒時多線程，其他不用。
* 放在git公開儲存庫(注意好資安 公司、產品、帳密、mail)
# wade
* 加入linux掃毒
* open source軟體怎麼說服老闆?
# change log
* 20230901 git控制
* 20230903 修正硬碟判斷，不要讀取ISCSI、SMB的硬碟
* 20230905 修正避開已安裝防毒的機器
* 20230905 抽離config檔案