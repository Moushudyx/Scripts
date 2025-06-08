# 游戏存档备份脚本

function Show-Error {
    param (
        [string]$message,
        [switch]$exit
    )
    Write-Host "X " -Foregroundcolor Red -NoNewline
    Write-Host "$message"
    if ($exit) {
        exit
    }
}
function Show-Success {
    param (
        [string]$message
    )
    Write-Host "> " -Foregroundcolor Green -NoNewline
    Write-Host "$message"
}
function Show-Warning {
    param (
        [string]$message
    )
    Write-Host "> " -Foregroundcolor Yellow -NoNewline
    Write-Host "$message" 
}
function Show-Info {
    param (
        [string]$message
    )
    Write-Host "> " -Foregroundcolor Cyan -NoNewline
    Write-Host "$message" 
}

Show-Info -message "正在检查环境..."
# 查找7-Zip安装路径
function Get-7ZipPath {
    # 优先从注册表中查找
    try {
        $regKey = Get-ItemProperty -Path "HKCU:\SOFTWARE\7-Zip" -ErrorAction Stop
        $sevenZipPath = Join-Path $regKey.Path "7z.exe"
        if (Test-Path $sevenZipPath) {
            return $sevenZipPath
        }
    }
    catch {
        # 忽略错误，用其他查找方式
    }
    # 常见安装路径
    $commonPaths = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe",
        "D:\Program Files\7-Zip\7z.exe",
        "D:\Program Files (x86)\7-Zip\7z.exe"
    )
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}
# 获取Steam游戏存档路径
function Get-SteamGameSavePath {
    param (
        [string]$gameId,
        [string]$gameName
    )

    try {
        # 获取Steam安装路径
        $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath
        if (-not (Test-Path $steamPath)) {
            throw "Steam 路径无效"
        }
    }
    catch {
        Show-Error -message "未找到 Steam 安装路径。"
        exit
    }

    $userdataPath = Join-Path $steamPath "userdata"
    if (-not (Test-Path $userdataPath)) {
        Show-Error -message "未找到 Steam 用户数据目录。"
        exit
    }

    # 查找用户ID文件夹
    $userIdFolders = Get-ChildItem -Path $userdataPath | Where-Object { $_.PSIsContainer }
    $remotePath = $null
    foreach ($user in $userIdFolders) {
        $gameDataPath = Join-Path $user.FullName "$gameId\remote"
        if (Test-Path $gameDataPath) {
            $remotePath = $gameDataPath
            Show-Info -message "已找到存档路径：$remotePath"
            break
        }
    }

    if (-not $remotePath) {
        Show-Error -message "未找到 $gameName 的存档路径。"
        exit
    }

    return $remotePath
}

# 1、检查7-Zip
$sevenZipPath = Get-7ZipPath
if (-not $sevenZipPath) {
    Show-Error -message "未找到 7-Zip 软件，本工具依赖 7-Zip 作为压缩工具。"
    exit
}

# 2、选择游戏
# 支持的游戏列表
$games = @(
    "怪物猎人崛起",
    "怪物猎人荒野",
    "无人深空"
)

# 显示游戏选择菜单
Show-Info -message "请选择要备份的游戏："
for ($i = 0; $i -lt $games.Count; $i++) {
    Write-Host "    $([string]::Format("{0,2}", $i+1)). $($games[$i])"
}
while ($true) {
    $choice = Read-Host "请输入选项（1-$($games.Count))"
    if ($choice -match '^\d+$' -and $choice -ge 1 -and $choice -le $games.Count) {
        break
    }
    else {
        Show-Warning -message "请输入有效的选项。"
    }
}

$selectedGame = $games[$choice - 1]
Show-Info -message "已选择：$selectedGame"

# 3、根据游戏获取存档路径
if ($selectedGame -eq "怪物猎人崛起") {
    $gameId = "1446780"
    $sourcePath = Get-SteamGameSavePath -gameId $gameId -gameName $selectedGame
}
elseif ($selectedGame -eq "怪物猎人荒野") {
    $gameId = "2246340"
    $sourcePath = Get-SteamGameSavePath -gameId $gameId -gameName $selectedGame
}
elseif ($selectedGame -eq "无人深空") {
    $nmsPath = Join-Path $env:APPDATA "HelloGames\NMS"
    if (-not (Test-Path $nmsPath)) {
        Show-Error -message "未找到 无人深空 的存档路径。"
        exit
    }
    $sourcePath = $nmsPath
    Show-Info -message "已找到存档路径：$sourcePath"
}

# 4、备份
# 生成备份文件名
$date = Get-Date
$filename = "{0}备份 {1}_{2}.7z" -f $selectedGame, $date.ToString("yyyyMMdd"), $date.ToString("HHmm")
$outputPath = Join-Path $PSScriptRoot $filename

# 执行压缩操作
Show-Info -message "开始备份..."
$process = Start-Process -FilePath $sevenZipPath -ArgumentList "a", "-t7z", "`"$outputPath`"", "`"$sourcePath`"" -NoNewWindow -Wait -PassThru

if ($process.ExitCode -eq 0) {
    Show-Success -message "备份成功保存到：$outputPath"
}
else {
    Show-Error -message "备份失败，7-Zip返回代码：$($process.ExitCode)"
}
