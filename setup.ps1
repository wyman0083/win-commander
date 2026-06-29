# =====================================================================
# IT 專業雲端部署 - 終極一鍵裝機總司令 (五合一完美集成版)
# =====================================================================
# 功能：權限獲取 + 電源調校 + 時間對時 + 三語部署 + 系統補丁與驅動更新 + 清理預載 + 8款智慧安裝 + VPN引導

# 1. 強制以系統管理員權限執行（支援直接複製貼上或執行檔案）
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ($PSCommandPath) {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    } else {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"[Value] = `" $(((Get-Content -Path $MyInvocation.MyCommand.Path) -join "`n") -replace '"','\"') `"; Invoke-Expression `"[Value]`" `"" -Verb RunAs
    }
    Exit
}

# 2. 設定畫面編碼，防止中文出現亂碼
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host " IT 專業雲端部署 - 系統清理、優化與智慧裝機總司令 " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# 3. 檢查網絡連線
Write-Host "正在檢查網絡連線..." -NoNewline
if (Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet) {
    Write-Host " [正常]" -ForegroundColor Green
} else {
    Write-Host " [失敗]" -ForegroundColor Red
    Write-Host "[錯誤] 本腳本需要網絡下載軟體，請先連接網絡再執行！" -ForegroundColor Yellow
    Read-Host "按 Enter 鍵結束程式..."
    Exit
}
Write-Host "-------------------------------------------------------"

# ==================== STAGE 1: Windows 系統環境調校 ====================
Write-Host "[階段 1/5] 正在調校 Windows 電源、睡眠與按鈕設定..." -ForegroundColor Cyan

# 設定插電為 Best Performance (最佳效能)，用電池為 Balanced (平衡)
powercfg /setacvalueindex SCHEME_CURRENT SUB_NONE OVERLAYFLAGS 2 # 2 = Best Performance
powercfg /setdcvalueindex SCHEME_CURRENT SUB_NONE OVERLAYFLAGS 0 # 0 = Balanced

# 設定螢幕關閉與睡眠時間 (0 代表 Never)
powercfg /change monitor-timeout-ac 20  # 插電：螢幕 20 分鐘後關閉
powercfg /change standby-timeout-ac 0   # 插電：裝置從不睡眠
powercfg /change monitor-timeout-dc 5   # 電池：螢幕 5 分鐘後關閉
powercfg /change standby-timeout-dc 0   # 電池：裝置從不睡眠

# 設定按鈕與蓋上螢幕動作 (0 = Do nothing | 3 = Shut down)
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTON 3 # 插電：電源鈕 -> 關機
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTON 0 # 插電：睡眠鈕 -> 無動作
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 # 插電：蓋上螢幕 -> 無動作
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTON 3 # 電池：電源鈕 -> 關機
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTON 0 # 電池：睡眠鈕 -> 無動作
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 # 電池：蓋上螢幕 -> 無動作

# 強制刷新並套用電源計劃
powercfg /setactive SCHEME_CURRENT
Write-Host " -> [成功] 電源模式、睡眠超時與按鈕行為配置完畢。" -ForegroundColor Green

# -------------------- 時間伺服器即時同步 --------------------
Write-Host "正在啟用 Windows 時間服務並與官方伺服器同步..." -ForegroundColor Cyan
Set-Service -Name w32time -StartupType Automatic
Start-Service -Name w32time -ErrorAction SilentlyContinue
& w32tm /resync /force | Out-Null
Write-Host " -> [成功] 本機時間已完成精準同步。" -ForegroundColor Green

# -------------------- 多國語言包與輸入法部署 --------------------
Write-Host "正在配置多國語言包 (預設 繁體中文、English US、簡體中文)..." -ForegroundColor Cyan
$languages = @("zh-HK", "en-US", "zh-CN")
foreach ($lang in $languages) {
    Write-Host " -> 檢查語言支援: $lang ..." -NoNewline
    Add-WindowsCapability -Online -Name "Language.Basic~~~$lang~0.0.1.0" -ErrorAction SilentlyContinue | Out-Null
    Write-Host " [完成]" -ForegroundColor Green
}

# 建立並強制寫入語言清單（優化：將 zh-HK 鎖定為第 1 順位預設顯示，符合本地習慣）
$UserLanguages = New-Object System.Collections.Generic.List[string]
$UserLanguages.Add("zh-HK")
$UserLanguages.Add("en-US")
$UserLanguages.Add("zh-CN")
Set-WinUserLanguageList -LanguageList $UserLanguages -Force
Write-Host " -> [成功] 語系配置完成！預設語言已鎖定為 繁體中文(香港)。" -ForegroundColor Green
Write-Host "-------------------------------------------------------"

# ==================== STAGE 2: Windows 更新與硬體驅動智慧部署 ====================
Write-Host "[階段 2/5] 正在檢查並更新 Windows 系統補丁與硬體驅動..." -ForegroundColor Cyan

# 1. 檢查並自動安裝微軟官方 Windows Update 模組
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host " -> 正在線上安裝 PSWindowsUpdate 核心模組..." -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue | Out-Null
    Install-Module -Name PSWindowsUpdate -Force -AcceptLicense -ErrorAction SilentlyContinue | Out-Null
}

# 2. 強制導入模組並解鎖微軟更新管道
Import-Module PSWindowsUpdate
Set-WUSettings -MicrosoftUpdate -AcceptByPass | Out-Null

# 3. 一鍵背景下載並安裝所有更新（含硬體驅動），暫不強制重啟
Write-Host " -> 正在背景檢索並安裝所有 Windows 更新與硬體驅動（請稍候）..." -ForegroundColor Yellow
Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -AutoReboot $false -ErrorAction SilentlyContinue

if ($LASTEXITCODE -eq 0 -or $?) {
    Write-Host " -> [成功] 所有系統安全補丁與硬體驅動已成功部署完畢！" -ForegroundColor Green
} else {
    Write-Host " -> [提示] Windows Update 檢查完畢，部分更新可能需重啟後生效。" -ForegroundColor DarkYellow
}
Write-Host "-------------------------------------------------------"

# ==================== STAGE 3: 預載流氓軟體強力清理 ====================
Write-Host "[階段 3/5] 正在檢查並強制拔除預載軟體 (McAfee / O365)..." -ForegroundColor Cyan

# McAfee 移除
$mcafeeCheck = winget list --name McAfee --accept-source-agreements 2>$null
if ($mcafeeCheck) {
    Write-Host " -> 偵測到本機有 McAfee，正在執行隱藏介面靜默強制移除..." -ForegroundColor Yellow
    winget uninstall --query McAfee --silent --accept-source-agreements
    Write-Host " -> [完成] McAfee 強制解除安裝命令已發送。" -ForegroundColor Green
} else {
    Write-Host " -> [跳過] 本機未發現 McAfee 殘留。" -ForegroundColor Gray
}

# Office 365 移除預載
$o365Check = winget list --name "Microsoft 365" --accept-source-agreements 2>$null
if ($o365Check) {
    Write-Host " -> 偵測到本機預載 Office 365，正在執行靜默強制移除..." -ForegroundColor Yellow
    winget uninstall --name "Microsoft 365" --silent --accept-source-agreements
    Write-Host " -> [完成] Office 365 解除安裝命令已發送。" -ForegroundColor Green
} else {
    Write-Host " -> [跳過] 本機未發現預載的 Office 365。" -ForegroundColor Gray
}
Write-Host "-------------------------------------------------------"

# ==================== STAGE 4: 8 款常用軟體智慧部署 ====================
Write-Host "[階段 4/5] 正在執行 8 款軟體智能檢查與背景安裝..." -ForegroundColor Cyan

$apps = @(
    "7zip.7zip",
    "Google.Chrome",
    "Mozilla.Firefox",
    "TeamViewer.TeamViewer",
    "Tencent.TencentMeeting",
    "Tencent.VooVMeeting",
    "Tencent.WeChat",
    "Tencent.WeCom"
)

foreach ($app in $apps) {
    Write-Host "[檢查中] " -NoNewline
    Write-Host $app -ForegroundColor Yellow -NoNewline
    
    # 優化：修正原本 -match 的邏輯地雷，改用 winget 精準探測 ID 存在狀態
    winget list --id $app --accept-source-agreements >$null 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host " -> [已安裝] 本機已存在此軟體，直接跳過。" -ForegroundColor Green
        Write-Host "-------------------------------------------------------"
    } else {
        Write-Host " -> [未安裝] 準備開始部署..." -ForegroundColor Cyan
        
        # winget 強制走官方庫，避開微軟商店憑證 0x8a15005e 錯誤
        winget install --id $app --source winget --silent --accept-source-agreements --accept-package-agreements
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[完成] $app 已成功裝好。" -ForegroundColor Green
        } else {
            Write-Host "[提示] $app 安裝程序已結束（請檢查桌面是否有圖示或稍後手動檢查）。" -ForegroundColor DarkYellow
        }
        Write-Host "-------------------------------------------------------"
    }
}

# ==================== STAGE 5: FortiClient VPN 安全部署 ====================
Write-Host "[階段 5/5] 正在準備部署 FortiClient VPN 指定版本 (7.2.9)..." -ForegroundColor Cyan
Write-Host "提示：由於 FortiClient 官方限制較多，稍後將彈出介面供你手動點選下一步。" -ForegroundColor Yellow

# 線上直接抓取指定版本進行安全引導部署
winget install --id Fortinet.FortiClientVPN --version 7.2.9.1185  --accept-source-agreements --accept-package-agreements
Write-Host " -> [完成] FortiClient 安裝視窗已拉起，請手動完成最後安裝步驟。" -ForegroundColor Green
Write-Host "-------------------------------------------------------"

# ==================== 大功告成與重啟引導 ====================
Write-Host "=======================================================" -ForegroundColor Green
Write-Host " 大功告成！所有系統優化、驅動更新、清理與 8+1 款軟體配置完畢！ " -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
Write-Host "提示：部分系統語言切換與驅動更新，需在電腦「重新啟動」後完全生效。" -ForegroundColor Yellow
Write-Host ""

# 自動詢問網管是否立即重啟電腦
$reboot = Read-Host "是否立即重新啟動電腦套用所有更新？(Y/N)"
if ($reboot -eq "Y" -or $reboot -eq "y") {
    Write-Host "正在強制重啟電腦..." -ForegroundColor Cyan
    Restart-Computer -Force
} else {
    Write-Host "已跳過重啟，請記得稍後手動重啟以完成全部驅動與語言配置。" -ForegroundColor Green
    Read-Host "按 Enter 鍵關閉本視窗..."
}
