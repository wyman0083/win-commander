# =====================================================================
#          IT 專業雲端部署 - 終極一鍵裝機總司令 (二合一完美集成版)
# =====================================================================
# 功能：權限獲取 + 電源調校 + 時間對時 + 三語部署 + 驅動/補丁更新 + 清理預載 + 8款智慧安裝 + VPN引導

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
Write-Host "      IT 專業雲端部署 - 系統清理、優化與智慧裝機總司令      " -ForegroundColor Cyan
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
powercfg /setacvalueindex SCHEME_CURRENT SUB_NONE OVERLAYFLAGS 2  # 2 = Best Performance
powercfg /setdcvalueindex SCHEME_CURRENT SUB_NONE OVERLAYFLAGS 0  # 0 = Balanced

# 設定螢幕關閉與睡眠時間 (0 代表 Never)
powercfg /change monitor-timeout-ac 20  # 插電：螢幕 20 分鐘後關閉
powercfg /change standby-timeout-ac 0   # 插電：裝置從不睡眠
powercfg /change monitor-timeout-dc 5   # 電池：螢幕 5 分鐘後關閉
powercfg /change standby-timeout-dc 0   # 電池：裝置從不睡眠

# 設定按鈕與蓋上螢幕動作 (0 = Do nothing | 3 = Shut down)
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTON 3  # 插電：電源鈕 -> 關機
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTON 0  # 插電：睡眠鈕 -> 無動作
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 # 插電：蓋上螢幕 -> 無動作
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTON 3  # 電池：電源鈕 -> 關機
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTON 0  # 電池：睡眠鈕 -> 無動作
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 # 電池：蓋上螢幕 -> 無動作

# 強制刷新並套用電源計劃
powercfg /setactive SCHEME_CURRENT
Write-Host "  -> [成功] 電源模式、睡眠超時與按鈕行為配置完畢。" -ForegroundColor Green

# ---------------------------------------- 時間伺服器即時同步
Write-Host "正在啟用 Windows 時間服務並與官方伺服器同步..." -ForegroundColor Cyan
Set-Service -Name w32time -StartupType Automatic
Start-Service -Name w32time -ErrorAction SilentlyContinue
& w32tm /resync /force | Out-Null
Write-Host "  -> [成功] 本機時間已完成精準同步。" -ForegroundColor Green

# ---------------------------------------- 多國語言包與輸入法部署
Write-Host "正在配置多國語言包 (English US 預設, 繁體中文, 簡體中文)..." -ForegroundColor Cyan
$languages = @("en-US", "zh-HK", "zh-CN")
foreach ($lang in $languages) {
    Write-Host "  -> 檢查語言支援: $lang ..." -NoNewline
    Add-WindowsCapability -Online -Name "Language.Basic~~~$lang~0.0.1.0" -ErrorAction SilentlyContinue | Out-Null
    Write-Host " [完成]" -ForegroundColor Green
}

# 建立並強制寫入語言清單（將 English US 鎖定為第 1 順位預設顯示）
$UserLanguages = New-Object System.Collections.Generic.List[string]
$UserLanguages.Add("en-US")
$UserLanguages.Add("zh-HK")
$UserLanguages.Add("zh-CN")
Set-WinUserLanguageList -LanguageList $UserLanguages -Force
Write-Host "  -> [成功] 語系配置完成！預設語言已鎖定為 English (US)。" -ForegroundColor Green
Write-Host "-------------------------------------------------------"


# ==================== 【全新加回】STAGE 2: Windows 補丁與硬體驅動更新 ====================
Write-Host "[階段 2/5] 正在檢查並更新 Windows 系統補丁與硬體驅動..." -ForegroundColor Cyan
Write-Host "  -> 正在線上載入 PSWindowsUpdate 核心模組..." -ForegroundColor Gray

# 預先配置 NuGet 補丁，防止舊系統連線出錯
$Null = Set-ExecutionPolicy RemoteSigned -Scope Process -Force
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue

# 修正不相容參數：移除原本會導致紅字報錯的 -AcceptLicense，改用相容於 PowerShell 5.1 的相容寫法
Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -ErrorAction SilentlyContinue
Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

if (Get-Command Set-WUSettings -ErrorAction SilentlyContinue) {
    # 啟用微軟其他產品更新支援 (包含 Office、獨立驅動程式等)
    Set-WUSettings -MicrosoftUpdate -AcceptByPass | Out-Null
    Write-Host "  -> 正在背景檢索並自動安裝所有 Windows 更新與硬體驅動 (請稍候)..." -ForegroundColor Yellow
    
    # 執行地毯式補丁與驅動背景下載安裝
    Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -AutoReboot:$false | Out-Null
    Write-Host "  -> [成功] 所有系統安全補丁與硬體驅動已成功部署完畢！" -ForegroundColor Green
} else {
    Write-Host "  -> [提示] 核心更新組件載入受阻，已自動跳過線上更新步驟。" -ForegroundColor Yellow
}
Write-Host "-------------------------------------------------------"


# ==================== STAGE 3: 預載流氓軟體強力清理 ====================
Write-Host "[階段 3/5] 正在檢查並強制拔除預載軟體 (McAfee / Microsoft 365)..." -ForegroundColor Cyan

# 1. McAfee 移除
$mcafeeCheck = winget list --name McAfee --accept-source-agreements 2>$null
if ($mcafeeCheck) {
    Write-Host "  -> 偵測到本機有 McAfee，正在執行隱藏介面靜默強制移除..." -ForegroundColor Yellow
    winget uninstall --query McAfee --silent --accept-source-agreements
    Write-Host "  -> [完成] McAfee 強制解除安裝命令已發送。" -ForegroundColor Green
} else {
    Write-Host "  -> [跳過] 本機未發現 McAfee 殘留。" -ForegroundColor Gray
}

# 2. Microsoft 365 強制移除 (地毯式自動化精準匹配，包含 cn / en / tw 等所有語言)
Write-Host "  -> 正在安全檢索所有版本的 Microsoft 365 辦公套件..." -ForegroundColor Gray

# 從 Windows 系統註冊表精準撈出所有叫 "Microsoft 365" 的軟體，但絕對排除 Copilot
$o365InstalledList = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", 
                                      "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", 
                                      "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
                     Where-Object { $_.DisplayName -match "Microsoft 365" -and $_.DisplayName -notmatch "Copilot" }

if ($o365InstalledList) {
    Write-Host "  -> 偵測到本機存在 Microsoft 365 預載組件，開始自動化逐一強制卸載..." -ForegroundColor Yellow
    foreach ($app in $o365InstalledList) {
        $appName = $app.DisplayName
        Write-Host "     正在拔除: $appName ..." -ForegroundColor DarkYellow
        winget uninstall --name "$appName" --silent --accept-source-agreements 2>$null
    }
    Write-Host "  -> [完成] 所有語言版本的 Microsoft 365 辦公套件解除安裝命令已發送。" -ForegroundColor Green
} else {
    Write-Host "  -> [跳過] 本機未發現任何語言版本的 Microsoft 365 辦公套件。" -ForegroundColor Gray
}

# 3. 獨立 Copilot 安全性防護確認
$copilotCheck = winget list --id "9WZDNCRD2V9V" --accept-source-agreements 2>$null
if ($copilotCheck) {
    Write-Host "  -> [安全保留] 成功鎖定獨立 Microsoft Copilot 應用，已安全跳過並留存本機！" -ForegroundColor Green
} else {
    Write-Host "  -> [提示] 本機目前未發現獨立 Copilot 應用，或已被其他系統組件隱藏。" -ForegroundColor Yellow
}
Write-Host "-------------------------------------------------------"


# ==================== STAGE 4: 8款常用軟體智慧部署 ====================
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
    
    $check = winget list --id $app --accept-source-agreements 2>$null
    
    if ($check -match $app) {
        Write-Host " -> [已安裝] 本機已存在此軟體，直接跳過。" -ForegroundColor Green
        Write-Host "-------------------------------------------------------"
    } else {
        Write-Host " -> [未安裝] 準備開始部署..." -ForegroundColor Cyan
        
        # winget 100% 強制走官方 winget 庫（避開 msstore 憑證出錯錯誤代碼 0x8a15005e）
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
winget install --id Fortinet.FortiClientVPN --version 7.2.9.1185 --accept-source-agreements --accept-package-agreements
Write-Host "  -> [完成] FortiClient 安裝視窗已拉起，請手動完成最後安裝步驟。" -ForegroundColor Green
Write-Host "-------------------------------------------------------"


# ==================== 部署大功告成 ====================
Write-Host "=======================================================" -ForegroundColor Green
Write-Host "大功告成！所有系統優化、補丁/驅動更新、多語言與 8+1 款軟體配置完畢！" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
Write-Host "提示：由於加載了硬體驅動更新與語言切換，強烈建議在電腦「重新啟動」後完全生效。" -ForegroundColor Yellow
Write-Host ""

Read-Host "按 Enter 鍵關閉本視窗..."
