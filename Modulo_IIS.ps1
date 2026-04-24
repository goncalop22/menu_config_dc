# ==============================================================================
# MODULO_IIS.PS1  -  IIS (Internet Information Services)
# Para usar isoladamente:
#   . .\Infra_Utils.ps1
#   . .\Modulo_IIS.ps1
#   Configurar_Setup
#   Menu_IIS
# ==============================================================================

function IIS_CriarSites {
    Cabecalho "IIS - Configurar Sites Web"
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    $pathMain=$CFG.IISMainPath; $pathIntra=$CFG.IISIntraPath; $dominio=$CFG.DomainFQDN
    $siteName=$CFG.IISSiteName; $portMain=$CFG.IISPortMain; $portIntra=$CFG.IISPortIntra
    if (-not (Test-Path $pathMain)) { New-Item -ItemType Directory -Path $pathMain -Force | Out-Null }
    $html  = "<!DOCTYPE html><html lang='pt'><head><meta charset='UTF-8'>"
    $html += "<title>$dominio</title><style>body{font-family:Segoe UI,sans-serif;"
    $html += "background:#1e1e2e;color:#cdd6f4;display:flex;align-items:center;"
    $html += "justify-content:center;height:100vh;margin:0}.card{background:#313244;"
    $html += "padding:2rem 3rem;border-radius:1rem;text-align:center}"
    $html += "h1{color:#89b4fa}p{color:#a6adc8}</style></head><body>"
    $html += "<div class='card'><h1>$dominio</h1><p>Infraestrutura Windows Server 2025</p>"
    $html += "<p>Site Principal - IIS</p></div></body></html>"
    Set-Content -Path "$pathMain\index.html" -Value $html -Encoding UTF8
    Registar "Pagina do site principal criada: $pathMain" "OK"
    if (-not (Test-Path $pathIntra)) { New-Item -ItemType Directory -Path $pathIntra -Force | Out-Null }
    $htmlI  = "<!DOCTYPE html><html lang='pt'><head><meta charset='UTF-8'>"
    $htmlI += "<title>Intranet - $dominio</title><style>body{font-family:Segoe UI,sans-serif;"
    $htmlI += "background:#1e3a5f;color:#e8f4fd;display:flex;align-items:center;"
    $htmlI += "justify-content:center;height:100vh;margin:0}.card{background:#0d2137;"
    $htmlI += "padding:2rem 3rem;border-radius:1rem;text-align:center}"
    $htmlI += "h1{color:#60a5fa}p{color:#93c5fd}</style></head><body>"
    $htmlI += "<div class='card'><h1>Intranet Corporativa</h1><p>Acesso restrito - $dominio</p></div></body></html>"
    Set-Content -Path "$pathIntra\index.html" -Value $htmlI -Encoding UTF8
    Registar "Pagina da intranet criada: $pathIntra" "OK"
    try {
        if (Get-Website -Name $siteName -ErrorAction SilentlyContinue) { Registar "Site '$siteName' ja existe." "AVISO" }
        else {
            New-Website -Name $siteName -Port $portMain -HostHeader "www.$dominio" -PhysicalPath $pathMain -Force | Out-Null
            Registar "Site '$siteName': http://www.$dominio" "OK"
        }
        if (Get-Website -Name "Intranet" -ErrorAction SilentlyContinue) { Registar "Site 'Intranet' ja existe." "AVISO" }
        else {
            New-Website -Name "Intranet" -Port $portIntra -HostHeader "intranet.$dominio" -PhysicalPath $pathIntra -Force | Out-Null
            Registar "Site 'Intranet': http://intranet.$($dominio):$($portIntra)" "OK"
        }
    }
    catch { Registar "Erro criar sites IIS: $($_.Exception.Message)" "ERRO" }
    Pausar
}

function IIS_VerSites {
    Cabecalho "IIS - Sites Configurados"
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    try {
        Get-Website | Format-Table -AutoSize Name, State, PhysicalPath
        _SecHeader "Bindings"
        Get-WebBinding | Format-Table -AutoSize Protocol, BindingInformation
    }
    catch { Registar "Erro listar IIS: $($_.Exception.Message)" "ERRO" }
    Pausar
}

function Menu_IIS {
    do {
        Cabecalho "MODULO 5 - IIS (Web Server)"
        $tl=[string][char]0x2554; $tr=[string][char]0x2557; $bl=[string][char]0x255A; $br=[string][char]0x255D
        Write-Host ("  " + $tl + "===" + [string][char]0x2566 + ("=" * 72) + $tr) -ForegroundColor DarkCyan
        _MInfo "www.$($CFG.DomainFQDN) (porta $($CFG.IISPortMain))   intranet.$($CFG.DomainFQDN) (porta $($CFG.IISPortIntra))"
        _MSep
        _MLinha "1" "Criar Sites Web"
        _MThin
        _MLinha "2" "Ver Sites e Bindings actuais"
        _MSep
        _MLinha "0" "Voltar ao Menu Principal" "DarkGray"
        Write-Host ("  " + $bl + "===" + [string][char]0x2569 + ("=" * 72) + $br) -ForegroundColor DarkCyan
        Write-Host ""
        $op = Read-Host "  Opcao"
        if     ($op -eq "1") { IIS_CriarSites }
        elseif ($op -eq "2") { IIS_VerSites }
        elseif ($op -eq "0") { return }
        else { Write-Host "  " -NoNewline; Write-Host " ER " -ForegroundColor White -BackgroundColor Red -NoNewline; Write-Host "  Opcao invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    } while ($true)
}
