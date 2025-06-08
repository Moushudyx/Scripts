# ��Ϸ�浵���ݽű�

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

Show-Info -message "���ڼ�黷��..."
# ����7-Zip��װ·��
function Get-7ZipPath {
    # ���ȴ�ע����в���
    try {
        $regKey = Get-ItemProperty -Path "HKCU:\SOFTWARE\7-Zip" -ErrorAction Stop
        $sevenZipPath = Join-Path $regKey.Path "7z.exe"
        if (Test-Path $sevenZipPath) {
            return $sevenZipPath
        }
    }
    catch {
        # ���Դ������������ҷ�ʽ
    }
    # ������װ·��
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
# ��ȡSteam��Ϸ�浵·��
function Get-SteamGameSavePath {
    param (
        [string]$gameId,
        [string]$gameName
    )

    try {
        # ��ȡSteam��װ·��
        $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath
        if (-not (Test-Path $steamPath)) {
            throw "Steam ·����Ч"
        }
    }
    catch {
        Show-Error -message "δ�ҵ� Steam ��װ·����"
        exit
    }

    $userdataPath = Join-Path $steamPath "userdata"
    if (-not (Test-Path $userdataPath)) {
        Show-Error -message "δ�ҵ� Steam �û�����Ŀ¼��"
        exit
    }

    # �����û�ID�ļ���
    $userIdFolders = Get-ChildItem -Path $userdataPath | Where-Object { $_.PSIsContainer }
    $remotePath = $null
    foreach ($user in $userIdFolders) {
        $gameDataPath = Join-Path $user.FullName "$gameId\remote"
        if (Test-Path $gameDataPath) {
            $remotePath = $gameDataPath
            Show-Info -message "���ҵ��浵·����$remotePath"
            break
        }
    }

    if (-not $remotePath) {
        Show-Error -message "δ�ҵ� $gameName �Ĵ浵·����"
        exit
    }

    return $remotePath
}

# 1�����7-Zip
$sevenZipPath = Get-7ZipPath
if (-not $sevenZipPath) {
    Show-Error -message "δ�ҵ� 7-Zip ��������������� 7-Zip ��Ϊѹ�����ߡ�"
    exit
}

# 2��ѡ����Ϸ
# ֧�ֵ���Ϸ�б�
$games = @(
    "������������",
    "�������˻�Ұ",
    "�������"
)

# ��ʾ��Ϸѡ��˵�
Show-Info -message "��ѡ��Ҫ���ݵ���Ϸ��"
for ($i = 0; $i -lt $games.Count; $i++) {
    Write-Host "    $([string]::Format("{0,2}", $i+1)). $($games[$i])"
}
while ($true) {
    $choice = Read-Host "������ѡ�1-$($games.Count))"
    if ($choice -match '^\d+$' -and $choice -ge 1 -and $choice -le $games.Count) {
        break
    }
    else {
        Show-Warning -message "��������Ч��ѡ�"
    }
}

$selectedGame = $games[$choice - 1]
Show-Info -message "��ѡ��$selectedGame"

# 3��������Ϸ��ȡ�浵·��
if ($selectedGame -eq "������������") {
    $gameId = "1446780"
    $sourcePath = Get-SteamGameSavePath -gameId $gameId -gameName $selectedGame
}
elseif ($selectedGame -eq "�������˻�Ұ") {
    $gameId = "2246340"
    $sourcePath = Get-SteamGameSavePath -gameId $gameId -gameName $selectedGame
}
elseif ($selectedGame -eq "�������") {
    $nmsPath = Join-Path $env:APPDATA "HelloGames\NMS"
    if (-not (Test-Path $nmsPath)) {
        Show-Error -message "δ�ҵ� ������� �Ĵ浵·����"
        exit
    }
    $sourcePath = $nmsPath
    Show-Info -message "���ҵ��浵·����$sourcePath"
}

# 4������
# ���ɱ����ļ���
$date = Get-Date
$filename = "{0}���� {1}_{2}.7z" -f $selectedGame, $date.ToString("yyyyMMdd"), $date.ToString("HHmm")
$outputPath = Join-Path $PSScriptRoot $filename

# ִ��ѹ������
Show-Info -message "��ʼ����..."
$process = Start-Process -FilePath $sevenZipPath -ArgumentList "a", "-t7z", "`"$outputPath`"", "`"$sourcePath`"" -NoNewWindow -Wait -PassThru

if ($process.ExitCode -eq 0) {
    Show-Success -message "���ݳɹ����浽��$outputPath"
}
else {
    Show-Error -message "����ʧ�ܣ�7-Zip���ش��룺$($process.ExitCode)"
}
