#Requires -RunAsAdministrator

# ==============================================================================
# INFRA_PRINCIPAL.PS1  -  Script Principal
# Carrega todos os modulos e apresenta o menu principal.
#
# ESTRUTURA DE FICHEIROS (todos na mesma pasta):
#   Infra_Principal.ps1    <- este ficheiro (ponto de entrada)
#   Infra_Utils.ps1        <- funcoes partilhadas + setup inicial
#   Modulo_AD.ps1          <- Active Directory
#   Modulo_DNS.ps1         <- DNS
#   Modulo_DHCP.ps1        <- DHCP
#   Modulo_FileServer.ps1  <- File Server / Partilhas
#   Modulo_IIS.ps1         <- IIS / Web Server
#
# USO DO SCRIPT COMPLETO:
#   .\Infra_Principal.ps1
#
# USO DE UM MODULO ISOLADO (exemplo DNS):
#   . .\Infra_Utils.ps1
#   . .\Modulo_DNS.ps1
#   Configurar_Setup
#   Menu_DNS
# ==============================================================================

# --- Carregar todos os modulos ------------------------------------------------
$PSScriptRoot_atual = $PSScriptRoot
if (-not $PSScriptRoot_atual) { $PSScriptRoot_atual = Split-Path $MyInvocation.MyCommand.Path }

. "$PSScriptRoot_atual\Infra_Utils.ps1"
. "$PSScriptRoot_atual\Modulo_AD.ps1"
. "$PSScriptRoot_atual\Modulo_DNS.ps1"
. "$PSScriptRoot_atual\Modulo_DHCP.ps1"
. "$PSScriptRoot_atual\Modulo_FileServer.ps1"
. "$PSScriptRoot_atual\Modulo_IIS.ps1"

# ==============================================================================
# ESTADO GERAL
# ==============================================================================

function Ver_EstadoGeral {
    Cabecalho "Estado Geral da Infraestrutura"
    _SecHeader "Servicos"
    $servicos = @("ADWS","DNS","DHCPServer","W3SVC","LanmanServer","wbengine")
    foreach ($s in $servicos) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -eq "Running") {
                Write-Host "  " -NoNewline; Write-Host " ON " -ForegroundColor Black -BackgroundColor Green -NoNewline
                Write-Host "  $($svc.DisplayName)" -ForegroundColor Green
            }
            else {
                Write-Host "  " -NoNewline; Write-Host " OFF" -ForegroundColor White -BackgroundColor DarkRed -NoNewline
                Write-Host "  $($svc.DisplayName)" -ForegroundColor Red
            }
        }
    }
    Write-Host ""; _SecHeader "Active Directory"
    try {
        $dom = Get-ADDomain -ErrorAction SilentlyContinue
        if ($dom) {
            $nu = (Get-ADUser  -Filter * -ErrorAction SilentlyContinue | Measure-Object).Count
            $ng = (Get-ADGroup -Filter * -ErrorAction SilentlyContinue | Measure-Object).Count
            Write-Host "  Dominio: $($dom.DNSRoot)   PDC: $($dom.PDCEmulator)" -ForegroundColor Cyan
            Write-Host "  Utilizadores: $nu   Grupos: $ng" -ForegroundColor Cyan
        }
    }
    catch { Write-Host "  AD nao acessivel." -ForegroundColor DarkGray }
    Write-Host ""; _SecHeader "DNS"
    try { Get-DnsServerZone -ErrorAction SilentlyContinue | Format-Table -AutoSize ZoneName, ZoneType, DynamicUpdate }
    catch { Write-Host "  DNS nao acessivel." -ForegroundColor DarkGray }
    _SecHeader "DHCP"
    try {
        Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | Format-Table -AutoSize ScopeId, StartRange, EndRange, State
        $nl = (Get-DhcpServerv4Lease -ScopeId $CFG.ScopeID -ErrorAction SilentlyContinue | Measure-Object).Count
        Write-Host "  Leases activos: $nl" -ForegroundColor Cyan
    }
    catch { Write-Host "  DHCP nao acessivel." -ForegroundColor DarkGray }
    _SecHeader "Rede"
    Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback" } | Format-Table -AutoSize InterfaceAlias, IPAddress, PrefixLength
    Pausar
}

# ==============================================================================
# CONFIGURACAO TOTAL
# ==============================================================================

function Config_Tudo {
    Cabecalho "Configuracao Total"
    $tl=[string][char]0x2554; $tr=[string][char]0x2557; $bl=[string][char]0x255A; $br=[string][char]0x255D
    $h=[string][char]0x2550; $v=[string][char]0x2551; $ml=[string][char]0x2560; $mr=[string][char]0x2563
    Write-Host ("  " + $tl + ($h * 76) + $tr) -ForegroundColor DarkYellow
    Write-Host ("  " + $v + "  Vai configurar todos os modulos em sequencia:".PadRight(76) + $v) -ForegroundColor Yellow
    Write-Host ("  " + $ml + ($h * 76) + $mr) -ForegroundColor DarkYellow
    Write-Host ("  " + $v + "   1/5  AD DS       OUs, Grupos, Users, Passwords, GPOs".PadRight(76) + $v) -ForegroundColor Gray
    Write-Host ("  " + $v + "   2/5  DNS         Zonas, Registos A, CNAME".PadRight(76) + $v) -ForegroundColor Gray
    Write-Host ("  " + $v + "   3/5  DHCP        Autorizar, Scope".PadRight(76) + $v) -ForegroundColor Gray
    Write-Host ("  " + $v + "   4/5  File Server Partilhas RH, IT, Publico".PadRight(76) + $v) -ForegroundColor Gray
    Write-Host ("  " + $v + "   5/5  IIS         Sites web e intranet".PadRight(76) + $v) -ForegroundColor Gray
    Write-Host ("  " + $ml + ($h * 76) + $mr) -ForegroundColor DarkYellow
    Write-Host ("  " + $v + "  Pre-requisito: todas as roles instaladas e dominio criado.".PadRight(76) + $v) -ForegroundColor DarkGray
    Write-Host ("  " + $bl + ($h * 76) + $br) -ForegroundColor DarkYellow
    Write-Host ""
    if (-not (Confirmar "Confirma a configuracao completa?")) { return }
    Write-Host ""; _SecHeader "1/5  Active Directory" "Cyan"
    AD_CriarOUs; AD_CriarGrupos; AD_CriarUtilizadores; AD_PoliticaPasswords; AD_CriarGPOs
    Write-Host ""; _SecHeader "2/5  DNS" "Cyan"
    DNS_CriarZonas; DNS_CriarRegistos
    Write-Host ""; _SecHeader "3/5  DHCP" "Cyan"
    DHCP_Autorizar; DHCP_CriarScope
    Write-Host ""; _SecHeader "4/5  File Server" "Cyan"
    FS_CriarPartilhas
    Write-Host ""; _SecHeader "5/5  IIS" "Cyan"
    IIS_CriarSites
    Write-Host ""
    Write-Host "  " -NoNewline; Write-Host " OK " -ForegroundColor Black -BackgroundColor Green -NoNewline
    Write-Host "  Configuracao total concluida!" -ForegroundColor Green
    Write-Host "  Log: $($CFG.LogFile)" -ForegroundColor DarkGray
    Pausar
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================

function Menu_Principal {
    do {
        Cabecalho "MENU PRINCIPAL"
        $tl=[string][char]0x2554; $tr=[string][char]0x2557; $bl=[string][char]0x255A; $br=[string][char]0x255D
        Write-Host ("  " + $tl + "===" + [string][char]0x2566 + ("=" * 72) + $tr) -ForegroundColor DarkCyan
        _MLinha "1" "Active Directory        OUs, Grupos, Utilizadores, GPOs"
        _MThin
        _MLinha "2" "DNS                     Zonas, Registos A, CNAME"
        _MThin
        _MLinha "3" "DHCP                    Scope, Opcoes, Reservas"
        _MThin
        _MLinha "4" "File Server             Partilhas RH, IT, Publico"
        _MThin
        _MLinha "5" "IIS                     Sites web e intranet"
        _MSep
        _MLinha "6" "Estado Geral            Servicos, AD, DNS, DHCP, Rede" "White"
        _MLinha "7" "Configuracao Total      Todos os modulos em sequencia" "Yellow"
        _MSep
        _MLinha "9" "Rever / Alterar Configuracoes" "DarkGray"
        _MLinha "0" "Sair" "DarkGray"
        Write-Host ("  " + $bl + "===" + [string][char]0x2569 + ("=" * 72) + $br) -ForegroundColor DarkCyan
        Write-Host ""
        $op = Read-Host "  Seleciona uma opcao"
        if     ($op -eq "1") { Menu_AD }
        elseif ($op -eq "2") { Menu_DNS }
        elseif ($op -eq "3") { Menu_DHCP }
        elseif ($op -eq "4") { Menu_FileServer }
        elseif ($op -eq "5") { Menu_IIS }
        elseif ($op -eq "6") { Ver_EstadoGeral }
        elseif ($op -eq "7") { Config_Tudo }
        elseif ($op -eq "9") { Configurar_Setup }
        elseif ($op -eq "0") {
            Clear-Host; Write-Host ""
            $tl2=[string][char]0x2554; $tr2=[string][char]0x2557; $bl2=[string][char]0x255A; $br2=[string][char]0x255D; $h2=[string][char]0x2550; $v2=[string][char]0x2551
            Write-Host ("  " + $tl2 + ($h2 * 76) + $tr2) -ForegroundColor DarkCyan
            Write-Host ("  " + $v2 + "  Script terminado.  Log: $($CFG.LogFile)".PadRight(76) + $v2) -ForegroundColor Cyan
            Write-Host ("  " + $bl2 + ($h2 * 76) + $br2) -ForegroundColor DarkCyan
            Write-Host ""; return
        }
        else { Write-Host "  " -NoNewline; Write-Host " ER " -ForegroundColor White -BackgroundColor Red -NoNewline; Write-Host "  Opcao invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    } while ($true)
}

# ==============================================================================
# PONTO DE ENTRADA
# ==============================================================================

$admin = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $tl=[string][char]0x2554; $tr=[string][char]0x2557; $bl=[string][char]0x255A; $br=[string][char]0x255D; $h=[string][char]0x2550; $v=[string][char]0x2551; $ml=[string][char]0x2560; $mr=[string][char]0x2563
    Write-Host ""
    Write-Host ("  " + $tl + ($h * 76) + $tr) -ForegroundColor DarkRed
    Write-Host ("  " + $v) -NoNewline -ForegroundColor DarkRed
    Write-Host "  " -NoNewline; Write-Host " ERRO " -ForegroundColor White -BackgroundColor DarkRed -NoNewline
    Write-Host "  Execute este script como Administrador!".PadRight(68) -NoNewline -ForegroundColor Red
    Write-Host $v -ForegroundColor DarkRed
    Write-Host ("  " + $v + "  Clique direito no PowerShell -> Executar como Administrador".PadRight(76) + $v) -ForegroundColor DarkGray
    Write-Host ("  " + $bl + ($h * 76) + $br) -ForegroundColor DarkRed
    Write-Host ""; exit 1
}

Configurar_Setup
Menu_Principal
