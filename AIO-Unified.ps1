<#
.SYNOPSIS
    AIO UNIFICADO - Instalador y Tweaks (v6.0 - Integración con GitHub)
.DESCRIPTION
    Implementa la detección de ejecución remota (irm | iex) para descargar 'tweaks.json' de GitHub en tiempo de ejecución, permitiendo la distribución con un solo comando.
.NOTES
    Autor: Gemini (Integración basada en el proyecto de Chris Titus)
    Versión: 6.0 (Integración GitHub)
    Fecha: 5 de noviembre de 2025
    
    REQUISITO: Necesita 'tweaks.json' en la misma carpeta (para ejecución local) o en el repositorio de GitHub (para ejecución remota).
#>

# --- Configuración de GitHub ---
# IMPORTANTE: REEMPLAZA TU_USUARIO/TU_REPO por tus datos de GitHub
$GitHubUser = "Liadev-op" # Ejemplo basado en la captura
$GitHubRepo = "AIO-Deployment-Tool" # Ejemplo
$BaseUrl = "https://raw.githubusercontent.com/$GitHubUser/$GitHubRepo/main/"
$TweaksFileName = "tweaks.json"
$TweaksRemoteUrl = "$BaseUrl$TweaksFileName"
# --- Fin de Configuración de GitHub ---

# --- PREPARACIÓN: Cargar las librerías de Windows para GUI ---
try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop
} catch {
    Write-Warning "ERROR: No se pudo cargar WPF. Asegúrese de tener .NET Framework."; Read-Host "Presione Enter para salir..."; exit 1
}

# ==============================================================================
# === INICIALIZACIÓN GLOBAL Y COLORES HARDCODED (VIOLETA/AZUL) ===
# ==============================================================================

# Cargar Application Object (Patrón Correcto)
if (-not [System.Windows.Application]::Current) {
    New-Object System.Windows.Application | Out-Null
}
$App = [System.Windows.Application]::Current
$script:Version = "6.0 (Integración GitHub)" # Versión actualizada

# Colores fijos (Violeta/Azul Dark Theme)
$Colors = @{
    'MainBackgroundColor' = '#13111C';       # Fondo general (Violeta muy oscuro)
    'MainForegroundColor' = '#F7F7F7';       # Texto general (Blanco puro)
    'AccentColor'         = '#8338EC';       # Color de acento principal (Violeta Eléctrico)
    'AccentHover'         = '#9C6AFF';       # Color de acento al pasar el ratón
    'ItemBackground'      = '#303030';       # Fondo de Items 
    'TabInactiveBackground' = '#252525';     # Fondo de Tab Inactivo
    'ButtonInstall'       = '#3A86FF';       # Azul Zafiro (Botón de Instalación)
    'ButtonTweaks'        = '#4CAF50';       # Verde para botón de tweaks
    'ButtonForeground'    = '#FFFFFF';       # Color del texto del botón
}

function Get-Brush {
    param([string]$Hex)
    try {
        if ($Hex -is [string] -and $Hex -match '^#') {
            $Color = [System.Windows.Media.Color]::FromRgb([System.Convert]::ToByte($Hex.Substring(1,2), 16), [System.Convert]::ToByte($Hex.Substring(3,2), 16), [System.Convert]::ToByte($Hex.Substring(5,2), 16))
            return New-Object System.Windows.Media.SolidColorBrush $Color
        }
        return New-Object System.Windows.Media.SolidColorBrush '#000000'
    } catch {
        return New-Object System.Windows.Media.SolidColorBrush '#000000'
    }
}
$script:MainForegroundBrush = Get-Brush $Colors.MainForegroundColor
$script:ItemBackgroundBrush = Get-Brush $Colors.ItemBackground
$script:AccentBrush = Get-Brush $Colors.AccentColor

# Variables de entorno
$script:SuccessExitCodes = @(0, 3010, 1603)
$script:ExecutionHistory = @{}
$script:AllAppCheckBoxes = @()
$script:AllTweakCheckBoxes = @()

# Variables para control de instaladores (Inicializadas en Invoke-AIOUnifiedGUI)
$script:UseWinget = $false
$script:UseChocolatey = $false

# ==============================================================================
# ========================= INICIO: CATÁLOGO UNIFICADO =========================
# ==============================================================================
# Nota: Este catálogo es solo para la estructura, la carga real sucede abajo.
$AppCatalog = @(
    [PSCustomObject]@{ID = 1; Name = "Office 365 (M365)"; WingetID = "Microsoft.Office"; ChocolateyID = "office365-business"; Category = "Oficina"; DirectURL = $null },
    [PSCustomObject]@{ID = 2; Name = "Adobe Reader DC"; WingetID = "Adobe.Acrobat.Reader.64-bit"; ChocolateyID = "adobereader"; Category = "Oficina"; DirectURL = $null }, 
    [PSCustomObject]@{ID = 3; Name = "WhatsApp"; WingetID = "9NKSQGP7F2NH"; ChocolateyID = "whatsapp"; Category = "Comunicación"; DirectURL = "https://web.whatsapp.com/desktop/windows/release/x64/WhatsAppSetup.exe" },
    [PSCustomObject]@{ID = 4; Name = "Google Chrome"; WingetID = "Google.Chrome"; ChocolateyID = "googlechrome"; Category = "Navegadores"; DirectURL = "https://dl.google.com/chrome/install/standalonesetup.exe" },
    [PSCustomObject]@{ID = 5; Name = "Mozilla Firefox"; WingetID = "Mozilla.Firefox"; ChocolateyID = "firefox"; Category = "Navegadores"; DirectURL = "https://download.mozilla.org/?product=firefox-stub&os=win&lang=es-ES" },
    [PSCustomObject]@{ID = 6; Name = "Zoom"; WingetID = "Zoom.Zoom"; ChocolateyID = "zoom"; Category = "Comunicación"; DirectURL = "https://zoom.us/client/latest/ZoomInstallerFull.exe" },
    [PSCustomObject]@{ID = 7; Name = "Discord"; WingetID = "Discord.Discord"; ChocolateyID = "discord"; Category = "Comunicación"; DirectURL = "https://discord.com/api/download?platform=win" },
    [PSCustomObject]@{ID = 8; Name = "WinRAR"; WingetID = "RARLab.WinRAR"; ChocolateyID = "winrar"; Category = "Utilidades"; DirectURL = "https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-624es.exe" }, 
    [PSCustomObject]@{ID = 9; Name = "7-Zip"; WingetID = "7zip.7zip"; ChocolateyID = "7zip"; Category = "Utilidades"; DirectURL = "https://www.7-zip.org/a/7z2301-x64.exe" },
    [PSCustomObject]@{ID = 10; Name = "Kramer VIA App"; WingetID = "Kramer.VIA"; ChocolateyID = "via"; Category = "Utilidades"; DirectURL = $null },
    [PSCustomObject]@{ID = 11; Name = "Lightshot"; WingetID = "Skillbrains.Lightshot"; ChocolateyID = "lightshot"; Category = "Utilidades"; DirectURL = "https://app.prntscr.com/build/setup-lightshot.exe" },
    [PSCustomObject]@{ID = 12; Name = "VLC Media Player"; WingetID = "VideoLAN.VLC"; ChocolateyID = "vlc"; Category = "Multimedia"; DirectURL = "https://get.videolan.org/vlc/3.0.20/win64/vlc-3.0.20-win64.exe" },
    [PSCustomObject]@{ID = 13; Name = "foobar2000"; WingetID = "PeterPawlowski.foobar2000"; ChocolateyID = "foobar2000"; Category = "Multimedia"; DirectURL = "https://www.foobar2000.org/getfile/f2000_201.exe" },
    [PSCustomObject]@{ID = 14; Name = "MusicBee"; WingetID = "MusicBee.MusicBee"; ChocolateyID = "musicbee"; Category = "Multimedia"; DirectURL = "https://getmusicbee.com/download.html" }, 
    [PSCustomObject]@{ID = 15; Name = "Spotify"; WingetID = "9NCBCSZSJRSB"; ChocolateyID = "spotify"; Category = "Multimedia"; DirectURL = "https://download.spotify.com/SpotifySetup.exe" },
    [PSCustomObject]@{ID = 16; Name = "LibreCAD"; WingetID = "LibreCAD.LibreCAD"; ChocolateyID = "librecad"; Category = "Diseño"; DirectURL = "https://github.com/LibreCAD/LibreCAD/releases/download/2.2.0.2/LibreCAD-Installer-2.2.0.2-Windows.exe" },
    [PSCustomObject]@{ID = 17; Name = "Okular"; WingetID = "KDE.Okular"; ChocolateyID = "okular"; Category = "Diseño"; DirectURL = $null }, 
    [PSCustomObject]@{ID = 18; Name = ".NET Framework 3.5"; WingetID = $null; ChocolateyID = "feature-dotnet35"; Category = "Desarrollo"; DirectURL = $null }, 
    [PSCustomObject]@{ID = 19; Name = "C++ Redistributables"; WingetID = $null; ChocolateyID = "vcredist-all"; Category = "Desarrollo"; DirectURL = $null }, 
    [PSCustomObject]@{ID = 20; Name = "Visual Studio Code"; WingetID = "Microsoft.VisualStudioCode"; ChocolateyID = "vscode"; Category = "Desarrollo"; DirectURL = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user" },
    [PSCustomObject]@{ID = 21; Name = "Notepad++"; WingetID = "Notepad++.Notepad++"; ChocolateyID = "notepadplusplus"; Category = "Utilidades"; DirectURL = "https://notepad-plus-plus.org/repository/8.x/8.6.2/npp.8.6.2.Installer.x64.exe" },
    [PSCustomObject]@{ID = 22; Name = "PuTTY"; WingetID = "PuTTY.PuTTY"; ChocolateyID = "putty"; Category = "Red"; DirectURL = "https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.80-installer.msi" },
    [PSCustomObject]@{ID = 23; Name = "WinSCP"; WingetID = "WinSCP.WinSCP"; ChocolateyID = "winscp"; Category = "Red"; DirectURL = "https://winscp.net/download/WinSCP-6.3.2-Setup.exe" },
    [PSCustomObject]@{ID = 24; Name = "FileZilla Client"; WingetID = "FileZilla.FileZilla.Client"; ChocolateyID = "filezilla"; Category = "Red"; DirectURL = "https://download.filezilla-project.org/client/FileZilla_3.66.4_win64_setup.exe" },
    [PSCustomObject]@{ID = 25; Name = "AnyDesk"; WingetID = "AnyDesk.AnyDesk"; ChocolateyID = "anydesk"; Category = "Red"; DirectURL = "https://download.anydesk.com/AnyDesk.exe" },
    [PSCustomObject]@{ID = 26; Name = "Radmin VPN"; WingetID = "Famatech.RadminVPN"; ChocolateyID = "radmin-vpn"; Category = "VPN"; DirectURL = "https://download.radmin-vpn.com/download/RadminVPN3110.exe" },
    [PSCustomObject]@{ID = 27; Name = "Tailscale"; WingetID = "Tailscale.Tailscale"; ChocolateyID = "tailscale"; Scope = "user"; Category = "VPN"; DirectURL = "https://pkgs.tailscale.com/stable/tailscale-setup-1.56.1.exe" },
    [PSCustomObject]@{ID = 28; Name = "OpenVPN Connect"; WingetID = "OpenVPN.OpenVPN"; ChocolateyID = "openvpn"; Category = "VPN"; DirectURL = "https://openvpn.net/downloads/openvpn-connect-v3-windows.msi" },
    [PSCustomObject]@{ID = 29; Name = "Netbird"; WingetID = "Netbird.Netbird"; ChocolateyID = "netbird"; Category = "VPN"; DirectURL = "https://netbird.io/release/netbird-installer.exe" },
    [PSCustomObject]@{ID = 30; Name = "Ventoy"; WingetID = "Ventoy.Ventoy"; ChocolateyID = "ventoy"; Category = "Sistema"; DirectURL = $null }, 
    [PSCustomObject]@{ID = 31; Name = "Balena Etcher"; WingetID = "Balena.Etcher"; ChocolateyID = "etcher"; Category = "Sistema"; DirectURL = "https://github.com/balena-io/etcher/releases/download/v1.19.19/balenaEtcher-1.19.19-x64.exe" },
    [PSCustomObject]@{ID = 32; Name = "GPU-Z"; WingetID = "TechPowerUp.GPU-Z"; ChocolateyID = "gpu-z"; Category = "Sistema"; DirectURL = $null }, 
    [PSCustomObject]@{ID = 33; Name = "CPU-Z"; WingetID = "CPUID.CPU-Z"; ChocolateyID = "cpu-z"; Category = "Sistema"; DirectURL = $null }, 
    [PSCustomObject]@{ID = 34; Name = "CrystalDiskInfo"; WingetID = "CrystalMark.CrystalDiskInfo"; ChocolateyID = "crystaldiskinfo"; Category = "Sistema"; DirectURL = $null }, 
    [PSCustomObject]@{ID = 35; Name = "NVCleanstall"; WingetID = "TechPowerUp.NVCleanstall"; ChocolateyID = "nvcleanstall"; Category = "Sistema"; DirectURL = $null }, 
    [PSCustomObject]@{ID = 36; Name = "DDU"; WingetID = "Wagnard.DisplayDriverUninstaller"; ChocolateyID = "ddu"; Category = "Sistema"; DirectURL = $null }, 
    [PSCustomObject]@{ID = 37; Name = "TreeSize Free"; WingetID = "JAMSoftware.TreeSize.Free"; ChocolateyID = "treesizefree"; Category = "Sistema"; DirectURL = "https://downloads.jam-software.de/treesize_free/TreeSizeFreeSetup.exe" },
    [PSCustomObject]@{ID = 38; Name = "BleachBit"; WingetID = "BleachBit.BleachBit"; ChocolateyID = "bleachbit"; Category = "Sistema"; DirectURL = "https://download.bleachbit.org/BleachBit-4.6.0-setup.exe" },
    [PSCustomObject]@{ID = 39; Name = "Steam"; WingetID = "Valve.Steam"; ChocolateyID = "steam-client"; DirectURL = "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"; Category = "Gaming" },
    [PSCustomObject]@{ID = 40; Name = "EA App"; WingetID = "ElectronicArts.EADesktop"; ChocolateyID = "ea-app"; Category = "Gaming"; DirectURL = "https://download.dm.origin.com/origin/live/EAappInstaller.exe" },
    [PSCustomObject]@{ID = 41; Name = "Valorant"; WingetID = "RiotGames.Valorant"; ChocolateyID = "valorant"; Category = "Gaming"; DirectURL = $null }, 
    [PSCustomObject]@{ID = 42; Name = "League of Legends"; WingetID = "RiotGames.LeagueOfLegends"; ChocolateyID = "leagueoflegends"; Category = "Gaming"; DirectURL = $null } 
) | Sort-Object ID
# ==============================================================================
# ========================= FIN: CATÁLOGO UNIFICADO ============================
# ==============================================================================

function Test-Winget { 
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }
    return $false
}
function Test-Chocolatey {
    if (Get-Command choco -ErrorAction SilentlyContinue) { return $true }
    return $false
}

function Invoke-InstallPackageManagers {
    Write-Host "`n-- INSTALACIÓN DE GESTORES --" -ForegroundColor Yellow
    
    if (-not $script:UseWinget) {
        Write-Host "Winget no encontrado. Las instalaciones Nivel 1 se omitirán." -ForegroundColor DarkYellow
    }

    if (-not $script:UseChocolatey) {
        Write-Host "Chocolatey no encontrado. Intentando la instalación automática..." -ForegroundColor DarkYellow
        try {
            $ChocoInstallCommand = @"
Set-ExecutionPolicy Bypass -Scope Process -Force; 
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; 
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
"@
            # Ejecutar el script de instalación de Chocolatey
            Invoke-Expression $ChocoInstallCommand 2>&1 | Out-Null
            
            # Re-testear
            if (Test-Chocolatey) {
                $script:UseChocolatey = $true
                Write-Host " [OK] Chocolatey instalado exitosamente." -ForegroundColor Green
            } else {
                Write-Host " [FALLO] No se pudo instalar Chocolatey. Las instalaciones Nivel 2 podrían fallar." -ForegroundColor Red
            }
        } catch {
            Write-Host " [ERROR] Falló la ejecución del script de instalación de Chocolatey: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Test-AppInstalled {
    param([PSCustomObject]$App)
    $AppName = $App.Name
    $ChocoId = $App.ChocolateyID

    if ($ChocoId -eq "feature-dotnet35") {
        try {
            $Feature = Get-WindowsOptionalFeature -Online -FeatureName NetFx3
            if ($Feature.State -eq "Enabled") { return $true }
        } catch {}
    }
    
    if ($ChocoId -eq "vcredist-all") { $ChocoId = "vcredist2015-2022" }

    if ($script:UseWinget -and $App.WingetID) {
        try {
            $Result = winget list --id $App.WingetID -e 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $Result -match $App.WingetID) { return $true }
        } catch {}
    }
    
    if ($script:UseChocolatey -and $App.ChocolateyID) {
        try {
            $UninstallerPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
            $UninstallerPathUser = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
            
            if (Get-ItemProperty -Path "$UninstallerPath\*" -ErrorAction SilentlyContinue | Where-Object { 
                $_.DisplayName -like "*$AppName*" -or $_.DisplayName -like "*$ChocoId*" 
            }) { return $true }
            
            if (Get-ItemProperty -Path "$UninstallerPathUser\*" -ErrorAction SilentlyContinue | Where-Object { 
                $_.DisplayName -like "*$AppName*" -or $_.DisplayName -like "*$ChocoId*" 
            }) { return $true }
        } catch {}
    }
    return $false
}

function Invoke-DownloadAndRun($Url, $AppName) {
    Write-Host "  -> Ejecutando descarga directa (Fallback Nivel 3) para $AppName..." -ForegroundColor DarkCyan
    
    $DownloadPath = Join-Path $env:TEMP "$($AppName)_Installer.exe"
    
    try {
        # Descargar el archivo
        $WebClient = New-Object System.Net.WebClient
        # --- FIX: Establecer un User-Agent para evitar el error 403 Forbidden ---
        $WebClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.127 Safari/537.36")
        # ------------------------------------------------------------------------
        $WebClient.DownloadFile($Url, $DownloadPath)
        
        # Ejecutar el instalador descargado en modo silencioso o interactivo
        Write-Host "  -> Ejecutando instalador $DownloadPath. Esto podría requerir interacción..." -ForegroundColor DarkCyan
        $Process = Start-Process -FilePath $DownloadPath -ArgumentList "/S" -Wait -PassThru -ErrorAction Stop # Intentando /S (silencioso)
        
        # Si el proceso termina correctamente
        if ($Process.ExitCode -in $script:SuccessExitCodes) {
            Write-Host " [OK] Instalación de $AppName por descarga directa exitosa." -ForegroundColor Green
            Remove-Item $DownloadPath -ErrorAction SilentlyContinue
            return $true
        } else {
            # Si la instalación silenciosa falla, reintentar de forma interactiva.
             Write-Host " [ADVERTENCIA] La instalación silenciosa falló (Code: $($Process.ExitCode)). Reintentando de forma interactiva (se abrirá una ventana)." -ForegroundColor Yellow
             Start-Process -FilePath $DownloadPath -Wait -ErrorAction Stop # Ejecución interactiva
             Write-Host " [OK] Instalación interactiva completada." -ForegroundColor Green
             Remove-Item $DownloadPath -ErrorAction SilentlyContinue
             return $true
        }
    } catch {
        # FIX DE PARSING DE POWERSHELL
        $ErrorMessage = $_.Exception.Message
        Write-Host " [ERROR] Falló la descarga o ejecución directa de ${AppName}: ${ErrorMessage}" -ForegroundColor Red
        return $false
    }
}


function Invoke-InstallApp {
    param([PSCustomObject]$App)
    $AppName = $App.Name
    $WingetID = $App.WingetID
    $ChocolateyID = $App.ChocolateyID
    $DirectURL = $App.DirectURL
    $ExitCode = -1

    Write-Host "`n[Procesando: $AppName]..." -ForegroundColor Yellow

    if ($ChocolateyID -eq "feature-dotnet35") {
        Write-Host "  -> Habilitando Característica de Windows: .NET 3.5..." -ForegroundColor Cyan
        try { $Output = DISM /Online /Enable-Feature /FeatureName:NetFx3 /All 2>&1 | Out-String } catch { $Output = $_.Exception.Message }
        $ExitCode = $LASTEXITCODE
        if ($ExitCode -in $script:SuccessExitCodes) { 
            Write-Host " [OK] .NET 3.5 habilitado exitosamente (Code: $ExitCode)." -ForegroundColor Green
            return $true
        } else { return $false }
    }

    if (Test-AppInstalled -App $App) {
        Write-Host "  -> [OK] '$AppName' ya está instalado en el sistema. Saltando instalación." -ForegroundColor Green
        return $true
    }

    # NIVEL 1: WINGET
    if ($script:UseWinget -and $WingetID) {
        $InstallScope = if ($App.Scope -eq "user" -or $WingetID -match "9N" -or $AppName -eq "Tailscale") { "user" } else { "machine" }

        Write-Host "  -> Ejecutando instalación de Winget (Nivel 1)..." -ForegroundColor Cyan
        
        try { $Output = winget install $WingetID --silent --accept-package-agreements --accept-source-agreements --scope $InstallScope 2>&1 | Out-String } catch { Write-Host " [ERROR] Fallo al invocar winget.exe: $($_.Exception.Message)" -ForegroundColor Red }
        $ExitCode = $LASTEXITCODE

        if ($ExitCode -in $script:SuccessExitCodes -and (Test-AppInstalled -App $App)) {
            Write-Host " [OK] Instalación de Winget para '$AppName' exitosa y VERIFICADA (Code: $ExitCode)." -ForegroundColor Green
            return $true
        }
        Write-Host " [FALLO] Winget falló (Código: $ExitCode). Continuando al Nivel 2..." -ForegroundColor DarkYellow
    }

    # NIVEL 2: CHOCOLATEY
    if ($script:UseChocolatey -and $ChocolateyID) {
        Write-Host "  -> Ejecutando instalación de Chocolatey (Nivel 2)..." -ForegroundColor Cyan
        try { $Output = choco install $ChocolateyID -y --limit-output --force -r 2>&1 | Out-String } catch { Write-Host " [ERROR] Fallo al invocar choco.exe: $($_.Exception.Message)" -ForegroundColor Red }
        $ExitCode = $LASTEXITCODE

        if ($ExitCode -in $script:SuccessExitCodes -and (Test-AppInstalled -App $App)) {
            Write-Host " [OK] Instalación de Chocolatey para '$AppName' exitosa y VERIFICADA (Code: $ExitCode)." -ForegroundColor Green
            return $true
        } elseif ($ExitCode -in $script:SuccessExitCodes) {
            Write-Host " [ADVERTENCIA] Choco reportó éxito (Code: $ExitCode), pero NO SE PUDO VERIFICAR. Marcando como EXITOSO." -ForegroundColor Yellow
            return $true
        } else {
             Write-Host " [ERROR] Chocolatey falló (Código: $ExitCode). Continuando al Nivel 3..." -ForegroundColor Red
        }
    }

    # NIVEL 3: INSTALADOR DIRECTO (Solo si URL está disponible)
    if ($DirectURL) {
        if (Invoke-DownloadAndRun -Url $DirectURL -AppName $AppName) {
            return $true
        }
    }

    Write-Host "  -> [ERROR] Fallo total al instalar '$AppName'. No se pudo completar la instalación por ningún método." -ForegroundColor Red
    return $false
}

function Invoke-AppInstaller {
    param([int[]]$SelectedIDs)
    
    # --------------------------------------------------------------------------------
    # Instalar gestores si es necesario
    Invoke-InstallPackageManagers
    
    # Comprobación de estado de gestores
    $StatusWinget = if ($script:UseWinget) { "DISPONIBLE" } else { "NO ENCONTRADO" }
    $StatusChoco = if ($script:UseChocolatey) { "DISPONIBLE" } else { "NO ENCONTRADO" }
    
    Write-Host "`n-- ESTADO DE INSTALADORES --" -ForegroundColor White
    Write-Host "Winget: $StatusWinget" -ForegroundColor Cyan
    Write-Host "Chocolatey: $StatusChoco" -ForegroundColor Cyan
    Write-Host "----------------------------" -ForegroundColor White
    # --------------------------------------------------------------------------------

    $AppsToProcess = $AppCatalog | Where-Object { $_.ID -in $SelectedIDs }
    $SucceededCount = 0
    $FailedApps = @()

    Write-Host "`n======================================================================================" -ForegroundColor Green
    Write-Host "         INICIANDO INSTALACIÓN DE $($AppsToProcess.Count) APLICACIONES" -ForegroundColor White
    Write-Host "======================================================================================" -ForegroundColor Green

    foreach ($App in $AppsToProcess) {
        if (Invoke-InstallApp -App $App) {
            $SucceededCount++
            $script:ExecutionHistory[$App.Name] = "OK"
        } else {
            $FailedApps += $App.Name
            $script:ExecutionHistory[$App.Name] = "ERROR"
        }
    }

    Write-Host " `n======================================================================================" -ForegroundColor Green
    Write-Host "         RESUMEN DE PROCESO" -ForegroundColor White
    Write-Host "======================================================================================" -ForegroundColor Green

    Write-Host "Procesos Exitosos: ${SucceededCount}" -ForegroundColor Green 
    
    if ($FailedApps.Count -gt 0) {
        Write-Host "[ERROR] Se encontraron errores en el proceso de: $($FailedApps.Count)" -ForegroundColor Red
        $FailedApps | ForEach-Object { Write-Host "   - $_" -ForegroundColor DarkRed }
    } else {
        Write-Host "¡Todo completado sin errores!" -ForegroundColor Green
    }
}

# --------------------------------------------------------------------------------
# --- FUNCIONES DE APLICACIÓN DE TWEAKS (VERBOS CORREGIDOS Y LÓGICA DE REGISTRO MEJORADA) ---
# --------------------------------------------------------------------------------

function Set-RegistryTweak {
    param ([string]$Path, [string]$Name, [string]$Type, [string]$Data)
    
    # Comprobar si la intención es eliminar la entrada (por el valor de tu JSON)
    if ($Data -eq "<RemoveEntry>") {
        try {
            if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop
                Write-Host " [OK] Registro ELIMINADO: $Path - $Name" -ForegroundColor Green
            } else {
                Write-Host " [INFO] Registro a ELIMINAR no encontrado: $Path - $Name" -ForegroundColor DarkYellow
            }
        } catch {
            Write-Warning " [FALLO] ELIMINACIÓN DE REGISTRO: $Path - $Name. Error: $($_.Exception.Message)"
        }
        return
    }

    # Si no es eliminación, procede a establecer el valor
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        $RegType = [Microsoft.Win32.RegistryValueKind]::$Type
        
        # Manejo especial para valores que deberían ser números/bools pero vienen como cadena
        $ValueToSet = switch ($Type.ToLower()) {
            "dword" { [System.Convert]::ToUInt32($Data) }
            "qword" { [System.Convert]::ToUInt64($Data) }
            default { $Data }
        }

        Set-ItemProperty -Path $Path -Name $Name -Value $ValueToSet -Type $RegType -Force -ErrorAction Stop
        Write-Host " [OK] Registro ESTABLECIDO: $Path - $Name" -ForegroundColor Green
    } catch { 
        Write-Warning " [FALLO] ESTABLECER REGISTRO: $Path - $Name. Error: $($_.Exception.Message)" 
    }
}

function Set-ServiceTweak {
    param ([string]$Name, [string]$State)
    try {
        $Service = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($Service) {
            if ($Service.Status -ne "Stopped" -and $State -eq "Disabled") { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-Service -Name $Name -StartupType $State -ErrorAction Stop
            Write-Host " [OK] Servicio: $Name puesto en $State" -ForegroundColor Green
        } else { Write-Warning " [INFO] Servicio: $Name no encontrado. Omitiendo." }
    } catch { Write-Warning " [FALLO] Servicio: $Name. Error: $($_.Exception.Message)" }
}

function Set-TaskTweak {
    param ([string]$Name, [string]$State)
    try {
        $Task = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
        if ($Task) {
            if ($State -eq "Disabled") { $Task | Disable-ScheduledTask -ErrorAction Stop } else { $Task | Enable-ScheduledTask -ErrorAction Stop }
            Write-Host " [OK] Tarea: $Name puesto en $State" -ForegroundColor Green
        } else { Write-Warning " [INFO] Tarea: $Name no encontrada. Omitiendo." }
    } catch { Write-Warning " [FALLO] Tarea: $Name. Error: $($_.Exception.Message)" }
}

function Invoke-CommandTweak {
    param ([string]$Command)
    try {
        # Ejecutar el comando/script
        Invoke-Expression $Command 2>&1 | Out-Null
        Write-Host " [OK] Comando: $($Command.Substring(0, [System.Math]::Min($Command.Length, 30)))... ejecutado." -ForegroundColor Green
    } catch { Write-Warning " [FALLO] Comando: $Command. Error: $($_.Exception.Message)" }
}

# --- FUNCIÓN PRINCIPAL DE TWEAKS ---
function Invoke-SelectedTweaks {
    param($TweaksToApply)

    Write-Host "`n======================================================="
    Write-Host "APLICANDO $($TweaksToApply.Count) TWEAKS..." -ForegroundColor White

    foreach ($Tweak in $TweaksToApply) {
        Write-Host "`n- Aplicando Tweak: $($Tweak.Content)" -ForegroundColor Yellow
        
        # Llamadas a las funciones corregidas
        if ($Tweak.Registry) { foreach ($Reg in $Tweak.Registry) { Set-RegistryTweak -Path $Reg.Path -Name $Reg.Name -Type $Reg.Type -Data $Reg.Value } }
        if ($Tweak.Service) { foreach ($Svc in $Tweak.Service) { Set-ServiceTweak -Name $Svc.Name -State $Svc.StartupType } }
        if ($Tweak.Task) { foreach ($Task in $Tweak.Task) { Set-TaskTweak -Name $Task.Name -State $Task.State } }
        if ($Tweak.InvokeScript) { foreach ($Cmd in $Tweak.InvokeScript) { Invoke-CommandTweak -Command $Cmd } }
    }

    Write-Host "¡Tweaks aplicados!" -ForegroundColor Green
    Write-Host "======================================================="
}
# --------------------------------------------------------------------------------
# --- FIN DE FUNCIONES DE APLICACIÓN DE TWEAKS ---
# --------------------------------------------------------------------------------


function Invoke-AIOUnifiedGUI {
    
    # --- 1. Comprobaciones Previas ---
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-NOT ([Security.Principal.WindowsPrincipal]$Identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "ERROR: Este script DEBE ejecutarse como Administrador."; Read-Host "Presione Enter para salir..."; return
    }

    # --- 1b. Detección de entorno y Carga de Tweaks ---
    $IsRemoteExecution = $MyInvocation.MyCommand.Definition.StartsWith("Invoke-RestMethod")
    
    if ($IsRemoteExecution) {
        # Caso 1: Ejecución remota (irm | iex). Descargamos el JSON temporalmente.
        Write-Host "Ejecución remota detectada. Descargando configuración desde GitHub..." -ForegroundColor Cyan
        try {
            # Establecer una política de seguridad para la descarga (necesario para GitHub raw)
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            
            $ContentRaw = Invoke-RestMethod -Uri $TweaksRemoteUrl -ErrorAction Stop
            $ContentClean = $ContentRaw.Trim() -replace '[\u0000-\u001F\u007F-\u009F]', ''
            $script:TweaksConfig = $ContentClean | ConvertFrom-Json
            Write-Host "Configuración de Tweaks cargada exitosamente desde GitHub." -ForegroundColor Green
        } catch {
            Write-Warning "ERROR: No se pudo descargar 'tweaks.json' de GitHub. $($_.Exception.Message)"
            [System.Windows.MessageBox]::Show("ERROR: No se pudo cargar 'tweaks.json' desde la URL remota.", "Error de Carga", "OK", "Error"); 
            return
        }
    } else {
        # Caso 2: Ejecución local (.\AIO-Unified.ps1). Usamos el archivo local.
        $script:PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
        $TweaksConfigPath = Join-Path $script:PSScriptRoot "tweaks.json" 
        
        if (-not (Test-Path $TweaksConfigPath)) { 
            [System.Windows.MessageBox]::Show("ERROR: No se encuentra 'tweaks.json' en la carpeta local.", "Error de Archivo", "OK", "Error"); return
        }

        # Cargar el JSON de Tweaks (Lógica de tu script original)
        try {
            $ContentRaw = [System.IO.File]::ReadAllText($TweaksConfigPath)
            $ContentClean = $ContentRaw.Trim() -replace '[\u0000-\u001F\u007F-\u009F]', ''
            $script:TweaksConfig = $ContentClean | ConvertFrom-Json
            
            if ($null -eq $script:TweaksConfig -or $script:TweaksConfig.Count -eq 0) { throw "El archivo 'tweaks.json' está vacío o la conversión falló." }
        } catch {
            [System.Windows.MessageBox]::Show("Error fatal al leer 'tweaks.json': $($_.Exception.Message)", "Error de JSON", "OK", "Error"); return
        }
    }
    # --- Fin de Detección y Carga ---
    
    $script:UseWinget = Test-Winget
    $script:UseChocolatey = Test-Chocolatey

    # --- FIX CRÍTICO DEL TÍTULO DE LA VENTANA ---
    # Eliminamos el ampersand y hardcodeamos el título de la versión
    $WindowXAMLTitile = "AIO Installer and Tweaks (v$($script:Version))"
    # --- FIN DEL FIX ---

    $Host.UI.RawUI.WindowTitle = $WindowXAMLTitile

    # --- 2. Definición de la GUI (XAML) - Diseño Modernizado (FIX XAML) ---
    Write-Host "Cargando interfaz gráfica con diseño avanzado..." -ForegroundColor Yellow
    
    # XAML con estilos INLINE (hardcoded) para evitar errores de StaticResource
    $XamlContent = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$WindowXAMLTitile" 
        Height="750" Width="850" WindowStartupLocation="CenterScreen"
        Background="$($Colors.MainBackgroundColor)">

    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />   <RowDefinition Height="*" />      <RowDefinition Height="Auto" />   </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="0,0,0,15">
            <TextBlock Text="⚙️ AIO Deployment Tool" 
                       FontSize="28" FontWeight="Bold" 
                       Foreground="$($Colors.AccentColor)" 
                       HorizontalAlignment="Left" />
            <TextBlock Text="Installer and System Tweaks (v$($script:Version))" 
                       FontSize="14" FontWeight="SemiBold" 
                       Foreground="$($Colors.MainForegroundColor)" 
                       Opacity="0.7" 
                       HorizontalAlignment="Left" />
        </StackPanel>

        <TabControl Grid.Row="1" Background="$($Colors.MainBackgroundColor)" 
                    BorderBrush="#333333" BorderThickness="0">
            
            <TabControl.Resources>
                <Style TargetType="{x:Type TabItem}">
                    <Setter Property="Background" Value="$($Colors.TabInactiveBackground)"/>
                    <Setter Property="Foreground" Value="$($Colors.MainForegroundColor)"/>
                    <Setter Property="BorderThickness" Value="0,0,0,2"/>
                    <Setter Property="BorderBrush" Value="Transparent"/>
                    <Setter Property="Padding" Value="15,8"/>
                    <Style.Triggers>
                        <Trigger Property="IsSelected" Value="True">
                            <Setter Property="Background" Value="$($Colors.MainBackgroundColor)"/>
                            <Setter Property="BorderBrush" Value="$($Colors.AccentColor)"/>
                            <Setter Property="Foreground" Value="$($Colors.MainForegroundColor)"/> 
                        </Trigger>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Background" Value="#3D3D3F"/>
                        </Trigger>
                    </Style.Triggers>
                </Style>
            </TabControl.Resources>

            <TabItem Header="Instalador de Aplicaciones" FontSize="14" FontWeight="Bold">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <Grid x:Name="AppGrid" Margin="15" />
                </ScrollViewer>
            </TabItem>
            
            <TabItem Header="Tweaks del Sistema" FontSize="14" FontWeight="Bold">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="*" />
                        <RowDefinition Height="Auto" />
                    </Grid.RowDefinitions>

                    <ScrollViewer VerticalScrollBarVisibility="Auto" Grid.Row="0">
                        <Grid x:Name="TweaksGrid" Margin="15" />
                    </ScrollViewer>
                    
                    <Button x:Name="Button_Tweaks" Content="Aplicar Tweaks Seleccionados" 
                            Grid.Row="1" Padding="20,10" Margin="0,10,0,0"
                            FontSize="14" FontWeight="Bold" 
                            Background="$($Colors.ButtonTweaks)" 
                            Foreground="$($Colors.ButtonForeground)"
                            BorderThickness="0" 
                            HorizontalAlignment="Right"/>
                </Grid>
            </TabItem>
            
        </TabControl>

        <Grid Grid.Row="2" Margin="0,15,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="Auto" />
            </Grid.ColumnDefinitions>

            <StatusBar Grid.Column="0" Background="Transparent" Foreground="$($Colors.MainForegroundColor)" 
                       HorizontalAlignment="Left" VerticalAlignment="Center">
                <StatusBarItem>
                    <TextBlock x:Name="StatusBarText" Text="Listo. Seleccione una pestaña." Opacity="0.7" />
                </StatusBarItem>
            </StatusBar>
            
            <Button x:Name="Button_Install" Content="Iniciar Instalación" 
                    Grid.Column="1" Padding="25,10"
                    FontSize="16" FontWeight="ExtraBold" 
                    Background="$($Colors.ButtonInstall)" 
                    Foreground="$($Colors.ButtonForeground)"
                    BorderThickness="0" 
                    VerticalAlignment="Bottom"/>
        </Grid>
    </Grid>
</Window>
"@

    # --- 3. Carga y Creación de la GUI ---
    try {
        # 1. Cargar el XAML
        $StringReader = New-Object System.IO.StringReader $XamlContent
        $XmlReader = [System.Xml.XmlReader]::Create($StringReader)
        $Window = [System.Windows.Markup.XamlReader]::Load($XmlReader)
        
        $InstallButton = $Window.FindName("Button_Install")
        $AppGrid = $Window.FindName("AppGrid") # Referencia al nuevo Grid de Apps
        $TweaksButton = $Window.FindName("Button_Tweaks")
        $TweaksGrid = $Window.FindName("TweaksGrid")
        $StatusBarText = $Window.FindName("StatusBarText")
    } catch {
        [System.Windows.MessageBox]::Show("Error fatal al cargar la GUI de XAML: $($_.Exception.Message)", "Error de XAML", "OK", "Error"); return
    }
    
    # --- 4. Poblar Pestaña 1: Instalador (LISTA PLANA DE 3 COLUMNAS) - Diseño COMPACTO ---
    $ColCount = 3
    $ColIndex = 0; $RowIndex = 0
    
    # 4a. Definir columnas del Grid de Apps
    for ($i = 0; $i -lt $ColCount; $i++) {
        $AppGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)}))
    }

    foreach ($App in $AppCatalog) {
        
        # Iniciar una nueva fila si es necesario
        if ($ColIndex -eq 0) { $AppGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Auto)})) }

        # Crear un contenedor moderno (Border)
        $AppBorder = New-Object System.Windows.Controls.Border
        $AppBorder.Background = $script:ItemBackgroundBrush
        $AppBorder.Margin = "2" # Compacto
        $AppBorder.CornerRadius = New-Object System.Windows.CornerRadius(6) 
        $AppBorder.Padding = New-Object System.Windows.Thickness(3, 5, 3, 5) # Compacto verticalmente

        # Usamos un Grid dentro del Border para alinear el CheckBox y el texto
        $InnerGrid = New-Object System.Windows.Controls.Grid
        $InnerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Auto)}))
        $InnerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)}))

        $CheckBox = New-Object System.Windows.Controls.CheckBox
        $CheckBox.Margin = New-Object System.Windows.Thickness(0,0,10,0) 
        $CheckBox.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $CheckBox.Tag = $App.ID 

        $TextBlock = New-Object System.Windows.Controls.TextBlock
        $TextBlock.Text = $App.Name
        $TextBlock.FontSize = 11 # Compacto
        $TextBlock.FontWeight = [System.Windows.FontWeights]::SemiBold
        $TextBlock.Foreground = $script:MainForegroundBrush
        $TextBlock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        [System.Windows.Controls.Grid]::SetColumn($CheckBox, 0)
        [System.Windows.Controls.Grid]::SetColumn($TextBlock, 1)

        $InnerGrid.Children.Add($CheckBox) | Out-Null
        $InnerGrid.Children.Add($TextBlock) | Out-Null
        
        $AppBorder.Child = $InnerGrid

        [System.Windows.Controls.Grid]::SetColumn($AppBorder, $ColIndex)
        [System.Windows.Controls.Grid]::SetRow($AppBorder, $RowIndex)
        $AppGrid.Children.Add($AppBorder) | Out-Null
        $script:AllAppCheckBoxes += $CheckBox
        
        $ColIndex++; 
        if ($ColIndex -eq $ColCount) { 
            $ColIndex = 0; 
            $RowIndex++; 
        }
    }
    
    # --- 5. Poblar Pestaña 2: Tweaks (LISTA PLANA DE 3 COLUMNAS) - Diseño COMPACTO ---
    $TweaksColCount = 3
    $TweaksColIndex = 0; $TweaksRowIndex = 0
    
    # 5a. Definir columnas del Grid de Tweaks
    for ($i = 0; $i -lt $TweaksColCount; $i++) {
        $TweaksGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)}))
    }
    
    $AllTweaks = @()
    # Recopilar todos los tweaks sin agrupar
    foreach ($TweakProperty in $script:TweaksConfig.PSObject.Properties) {
        $AllTweaks += $TweakProperty.Value 
    }
    $TweaksSorted = $AllTweaks | Sort-Object -Property Order, Content
    
    Write-Host "DIAGNÓSTICO: Se encontraron $($AllTweaks.Count) Tweaks." -ForegroundColor Cyan
    
    foreach ($TweakData in $TweaksSorted) {
        if ($TweaksColIndex -eq 0) { $TweaksGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Auto)})) }

        # Crear un contenedor moderno (Border)
        $TweakBorder = New-Object System.Windows.Controls.Border
        $TweakBorder.Background = $script:ItemBackgroundBrush
        $TweakBorder.Margin = "2" # Compacto
        $TweakBorder.CornerRadius = New-Object System.Windows.CornerRadius(6) # Compacto
        $TweakBorder.Padding = New-Object System.Windows.Thickness(3, 5, 3, 5) # Compacto verticalmente
        
        # Usamos un Grid dentro del Border para alinear el CheckBox y el texto
        $InnerGrid = New-Object System.Windows.Controls.Grid
        $InnerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Auto)}))
        $InnerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)}))

        $TweakCheckBox = New-Object System.Windows.Controls.CheckBox
        $TweakCheckBox.Margin = New-Object System.Windows.Thickness(0,0,10,0)
        $TweakCheckBox.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $TweakCheckBox.Tag = $TweakData 

        $TextBlock = New-Object System.Windows.Controls.TextBlock
        $TextBlock.Text = $TweakData.Content
        $TextBlock.FontSize = 11 # Compacto
        $TextBlock.FontWeight = [System.Windows.FontWeights]::SemiBold
        $TextBlock.Foreground = $script:MainForegroundBrush
        $TextBlock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        
        if ($TweakData.Description) { $TextBlock.ToolTip = $TweakData.Description }

        [System.Windows.Controls.Grid]::SetColumn($TweakCheckBox, 0)
        [System.Windows.Controls.Grid]::SetColumn($TextBlock, 1)

        $InnerGrid.Children.Add($TweakCheckBox) | Out-Null
        $InnerGrid.Children.Add($TextBlock) | Out-Null
        
        $TweakBorder.Child = $InnerGrid

        [System.Windows.Controls.Grid]::SetColumn($TweakBorder, $TweaksColIndex)
        [System.Windows.Controls.Grid]::SetRow($TweakBorder, $TweaksRowIndex)
        $TweaksGrid.Children.Add($TweakBorder) | Out-Null
        $script:AllTweakCheckBoxes += $TweakCheckBox
        
        $TweaksColIndex++; 
        if ($TweaksColIndex -eq $TweaksColCount) { 
            $TweaksColIndex = 0; 
            $TweaksRowIndex++; 
        }
    }
    
    # --- 6. Lógica de Botones ---
    $InstallButton.Add_Click({
        $SelectedIDs = @()
        foreach ($CheckBox in $script:AllAppCheckBoxes) {
            if ($CheckBox.IsChecked -eq $true) { $SelectedIDs += $CheckBox.Tag }
        }
        if ($SelectedIDs.Count -eq 0) { $StatusBarText.Text = "Seleccione al menos una app."; return }
        
        $StatusBarText.Text = "Iniciando instalación de apps... Revisa la consola."
        Write-Host "======================================================================================" -ForegroundColor Green
        Write-Host "INICIANDO INSTALACIÓN DE APPS SELECCIONADAS..." -ForegroundColor White
        
        Invoke-AppInstaller -SelectedIDs $SelectedIDs
        
        $StatusBarText.Text = "Proceso de apps completado."
    }) 
    
    $TweaksButton.Add_Click({
        $TweaksToApply = @()
        foreach ($CheckBox in $script:AllTweakCheckBoxes) {
            if ($CheckBox.IsChecked -eq $true) { $TweaksToApply += $CheckBox.Tag; $CheckBox.IsChecked = $false }
        }
        if ($TweaksToApply.Count -eq 0) { $StatusBarText.Text = "Seleccione al menos un Tweak."; return }
        
        $StatusBarText.Text = "Aplicando $($TweaksToApply.Count) tweaks... Revisa la consola."
        Invoke-SelectedTweaks -TweaksToApply $TweaksToApply
        
        $StatusBarText.Text = "¡Tweaks aplicados! Revisa la consola para ver el log."
        [System.Windows.MessageBox]::Show("¡$($TweaksToApply.Count) tweaks han sido aplicados!`n`nRevisa la consola desde la que ejecutaste el script para ver el log detallado.", "Tweaks Aplicados", "OK", "Information")
    })

    # --- 7. Mostrar la Ventana ---
    Write-Host "¡Listo! Mostrando el menú de selección."
    $Window.ShowDialog() | Out-Null
    Write-Host "Cerrando AIO."
    return $Window
}

# --- Iniciar el script ---
Invoke-AIOUnifiedGUI


