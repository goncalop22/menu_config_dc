#Requires -RunAsAdministrator

# ==============================================================================
# INFRA_UTILS.PS1
# Funcoes utilitarias partilhadas por todos os modulos.
# Este ficheiro e carregado automaticamente pelo script principal.
# Para usar um modulo isolado faz: . .\Infra_Utils.ps1
# ==============================================================================

# Suporte de caracteres especiais na consola
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$CFG = @{}
$script:DC        = ""
$script:OU_RAIZ   = ""
$script:OU_TESTES = ""
$script:OU_USERS  = ""
$script:OU_GRUPOS = ""

# ==============================================================================
# FUNCOES UTILITARIAS
# ==============================================================================

function Registar {
    param([string]$Msg, [string]$Nivel)
    if ($Nivel -eq "") { $Nivel = "INFO" }
    $ts    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $linha = "[$ts][$Nivel] $Msg"
    $dir   = Split-Path $CFG.LogFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -Path $CFG.LogFile -Value $linha
    if ($Nivel -eq "OK") {
        Write-Host "  " -NoNewline
        Write-Host " OK " -ForegroundColor Black -BackgroundColor Green -NoNewline
        Write-Host "  $Msg" -ForegroundColor Green
    }
    elseif ($Nivel -eq "ERRO") {
        Write-Host "  " -NoNewline
        Write-Host " ER " -ForegroundColor White -BackgroundColor Red -NoNewline
        Write-Host "  $Msg" -ForegroundColor Red
    }
    elseif ($Nivel -eq "AVISO") {
        Write-Host "  " -NoNewline
        Write-Host " AV " -ForegroundColor Black -BackgroundColor Yellow -NoNewline
        Write-Host "  $Msg" -ForegroundColor Yellow
    }
    else {
        Write-Host "  " -NoNewline
        Write-Host " >> " -ForegroundColor Black -BackgroundColor Cyan -NoNewline
        Write-Host "  $Msg" -ForegroundColor Cyan
    }
}

# ==============================================================================
# FUNCOES VISUAIS
# Layout: 80 colunas totais
#   Cabecalho : "  " + boxchar(1) + 76*"=" + boxchar(1) = 80
#   Menu row  : "  " + "|"(1) + " N "(3) + "|"(1) + 72 chars + "|"(1) = 80
# ==============================================================================

function _Sep  { Write-Host ("  " + [string][char]0x2560 + ("=" * 76) + [string][char]0x2563) -ForegroundColor DarkCyan }
function _MSep { Write-Host ("  " + [string][char]0x2560 + "===" + [string][char]0x256C + ("=" * 72) + [string][char]0x2563) -ForegroundColor DarkCyan }
function _MThin{ Write-Host ("  " + [string][char]0x255F + "---" + [string][char]0x256B + ("-" * 72) + [string][char]0x2562) -ForegroundColor DarkGray }

function _Caixa {
    param([string]$Estilo = "dupla")
    if ($Estilo -eq "dupla") {
        $tl=[string][char]0x2554; $tr=[string][char]0x2557; $bl=[string][char]0x255A; $br=[string][char]0x255D; $h=[string][char]0x2550; $v=[string][char]0x2551; $ml=[string][char]0x2560; $mr=[string][char]0x2563
    } else {
        $tl=[string][char]0x250C; $tr=[string][char]0x2510; $bl=[string][char]0x2514; $br=[string][char]0x2518; $h=[string][char]0x2500; $v=[string][char]0x2502; $ml=[string][char]0x251C; $mr=[string][char]0x2524
    }
    return @{ TL=$tl; TR=$tr; BL=$bl; BR=$br; H=$h; V=$v; ML=$ml; MR=$mr }
}

function _MLinha {
    param([string]$Num, [string]$Texto, [string]$Cor = "Cyan")
    $conteudo = ("  " + $Texto).PadRight(72)
    $cc = [ConsoleColor]$Cor
    $vc = [string][char]0x2551
    Write-Host ("  " + $vc + " ") -NoNewline -ForegroundColor DarkCyan
    Write-Host $Num -NoNewline -ForegroundColor Yellow
    Write-Host (" " + $vc) -NoNewline -ForegroundColor DarkCyan
    Write-Host $conteudo -NoNewline -ForegroundColor $cc
    Write-Host $vc -ForegroundColor DarkCyan
}

function _MInfo {
    param([string]$Texto, [string]$Cor = "DarkGray")
    $conteudo = ("  " + $Texto).PadRight(72)
    $cc = [ConsoleColor]$Cor
    $vc = [string][char]0x2551
    Write-Host ("  " + $vc + "   " + $vc) -NoNewline -ForegroundColor DarkCyan
    Write-Host $conteudo -NoNewline -ForegroundColor $cc
    Write-Host $vc -ForegroundColor DarkCyan
}

function _LinhaBox {
    param([string]$Texto, [string]$Cor = "Gray")
    $vc = [string][char]0x2502
    $linha = ("  " + $vc + "  " + $Texto).PadRight(79) + $vc
    Write-Host $linha -ForegroundColor ([ConsoleColor]$Cor)
}

function Cabecalho {
    param([string]$Titulo)
    Clear-Host
    $tl=[string][char]0x2554; $tr=[string][char]0x2557; $bl=[string][char]0x255A; $br=[string][char]0x255D
    $h=[string][char]0x2550; $v=[string][char]0x2551; $ml=[string][char]0x2560; $mr=[string][char]0x2563

    $domRede = " Dom: " + $CFG.DomainFQDN + "   Rede: " + $CFG.ScopeID + "/" + $CFG.SubnetPrefix
    $badge   = " SERVER "

    Write-Host ""
    Write-Host ("  " + $tl + ($h * 76) + $tr) -ForegroundColor DarkCyan
    # Banner
    Write-Host ("  " + $v) -NoNewline -ForegroundColor DarkCyan
    Write-Host "  " -NoNewline
    Write-Host $badge -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
    Write-Host ("  INFRAESTRUTURA  WINDOWS SERVER 2025" + (" " * 32)) -NoNewline -ForegroundColor Cyan
    Write-Host $v -ForegroundColor DarkCyan
    # Separador
    Write-Host ("  " + $ml + ($h * 76) + $mr) -ForegroundColor DarkCyan
    # Info bar
    Write-Host ("  " + $v) -NoNewline -ForegroundColor DarkCyan
    Write-Host ($domRede.PadRight(76)) -NoNewline -ForegroundColor DarkGray
    Write-Host $v -ForegroundColor DarkCyan
    # Separador
    Write-Host ("  " + $ml + ($h * 76) + $mr) -ForegroundColor DarkCyan
    # Titulo
    Write-Host ("  " + $v) -NoNewline -ForegroundColor DarkCyan
    Write-Host "  " -NoNewline
    Write-Host " > " -ForegroundColor Black -BackgroundColor DarkBlue -NoNewline
    Write-Host ("  " + $Titulo).PadRight(73) -NoNewline -ForegroundColor White
    Write-Host $v -ForegroundColor DarkCyan
    # Rodape
    Write-Host ("  " + $bl + ($h * 76) + $br) -ForegroundColor DarkCyan
    Write-Host ""
}

function Confirmar {
    param([string]$Pergunta)
    $tl=[string][char]0x250C; $tr=[string][char]0x2510; $bl=[string][char]0x2514; $br=[string][char]0x2518
    $h=[string][char]0x2500; $v=[string][char]0x2502
    Write-Host ""
    Write-Host ("  " + $tl + ($h * 55) + $tr) -ForegroundColor DarkYellow
    Write-Host ("  " + $v + "  " + $Pergunta.PadRight(53) + $v) -ForegroundColor Yellow
    Write-Host ("  " + $bl + ($h * 55) + $br) -ForegroundColor DarkYellow
    $r = Read-Host "  [S/N]"
    return ($r -eq "S" -or $r -eq "s")
}

function Pausar {
    Write-Host ""
    Write-Host ("  " + ([string][char]0x2500 * 45)) -ForegroundColor DarkGray
    Write-Host "  Prima " -NoNewline -ForegroundColor DarkGray
    Write-Host "ENTER" -NoNewline -ForegroundColor White
    Write-Host " para continuar..." -ForegroundColor DarkGray
    Write-Host ("  " + ([string][char]0x2500 * 45)) -ForegroundColor DarkGray
    $null = Read-Host
}

function TestarAD {
    try {
        Get-ADDomain -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        Registar "AD DS nao acessivel. Confirme que o dominio esta criado." "ERRO"
        Pausar
        return $false
    }
}

function LerValor {
    param([string]$Pergunta, [string]$Default)
    if ($Default -ne "") {
        $resposta = Read-Host "  $Pergunta [$Default]"
        if ($resposta -eq "") { return $Default }
        return $resposta
    }
    else {
        do { $resposta = Read-Host "  $Pergunta" } while ($resposta -eq "")
        return $resposta
    }
}

function ValidarIP {
    param([string]$IP)
    return ($IP -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$")
}

function _SecHeader {
    param([string]$Titulo, [string]$Cor = "Cyan")
    $h = [string][char]0x2500
    $pad = 72 - $Titulo.Length
    if ($pad -lt 0) { $pad = 0 }
    Write-Host ("  " + [string][char]0x2500 + [string][char]0x2500 + [string][char]0x2500 + " " + $Titulo + " " + ([string][char]0x2500 * $pad)) -ForegroundColor ([ConsoleColor]$Cor)
}

# ==============================================================================
# ASSISTENTE DE CONFIGURACAO INICIAL
# ==============================================================================

function Configurar_Setup {
    Clear-Host
    $tl=[string][char]0x2554; $tr=[string][char]0x2557; $bl=[string][char]0x255A; $br=[string][char]0x255D
    $h=[string][char]0x2550; $v=[string][char]0x2551; $ml=[string][char]0x2560; $mr=[string][char]0x2563
    $stl=[string][char]0x250C; $str=[string][char]0x2510; $sbl=[string][char]0x2514; $sbr=[string][char]0x2518
    $sh=[string][char]0x2500; $sv=[string][char]0x2502

    Write-Host ""
    Write-Host ("  " + $tl + ($h * 76) + $tr) -ForegroundColor DarkYellow
    Write-Host ("  " + $v) -NoNewline -ForegroundColor DarkYellow
    Write-Host "  " -NoNewline
    Write-Host " SETUP " -ForegroundColor Black -BackgroundColor DarkYellow -NoNewline
    Write-Host ("  ASSISTENTE DE CONFIGURACAO INICIAL" + (" " * 32)) -NoNewline -ForegroundColor Yellow
    Write-Host $v -ForegroundColor DarkYellow
    Write-Host ("  " + $ml + ($h * 76) + $mr) -ForegroundColor DarkYellow
    Write-Host ("  " + $v + "  Configure a infraestrutura de acordo com a sua rede" + (" " * 25) + $v) -ForegroundColor Yellow
    Write-Host ("  " + $v + "  Prima ENTER para aceitar o valor entre [ ]" + (" " * 34) + $v) -ForegroundColor DarkGray
    Write-Host ("  " + $bl + ($h * 76) + $br) -ForegroundColor DarkYellow
    Write-Host ""

    do {
        Write-Host ("  " + $stl + $sh + "[ DOMINIO ]" + ($sh * 63) + $str) -ForegroundColor Cyan
        $fqdn    = LerValor "Dominio FQDN       (ex: grupo2.local)" "grupo2.local"
        $netbios = LerValor "Nome NetBIOS        (ex: GRUPO2)" ($fqdn.Split(".")[0].ToUpper())
        $ouRaiz  = LerValor "Nome OU raiz no AD  (ex: GRUPO2)" ($fqdn.Split(".")[0])
        $senhaUsers = LerValor "Senha padrao utilizadores" "$($netbios)@2025!"
        Write-Host ("  " + $sbl + ($sh * 75) + $sbr) -ForegroundColor Cyan
        Write-Host ""

        Write-Host ("  " + $stl + $sh + "[ IPS DOS SERVIDORES ]" + ($sh * 52) + $str) -ForegroundColor Cyan
        $ipDC      = LerValor "IP do DC / DNS"         "192.168.0.1"
        $ipWeb     = LerValor "IP do Servidor Web"     "192.168.0.2"
        $ipBackup  = LerValor "IP do Servidor Backup"  "192.168.0.3"
        $ipDHCP    = LerValor "IP do Servidor DHCP"    "192.168.0.4"
        $ipGateway = LerValor "IP do Gateway / Router" "192.168.0.254"
        $mask      = LerValor "Mascara de sub-rede"    "255.255.255.0"
        $prefix    = LerValor "Prefixo CIDR            (ex: 24)" "24"
        Write-Host ("  " + $sbl + ($sh * 75) + $sbr) -ForegroundColor Cyan
        Write-Host ""

        Write-Host ("  " + $stl + $sh + "[ DHCP ]" + ($sh * 65) + $str) -ForegroundColor Cyan
        $scopeStart = LerValor "Inicio do pool de IPs   (ex: 192.168.0.100)" "192.168.0.100"
        $scopeEnd   = LerValor "Fim do pool de IPs      (ex: 192.168.0.200)" "192.168.0.200"
        $scopeName  = LerValor "Nome do scope" "Clientes-LAN"
        $exclStart  = LerValor "Exclusao - inicio       (IPs dos servidores)" "192.168.0.1"
        $exclEnd    = LerValor "Exclusao - fim          (IPs dos servidores)" "192.168.0.99"
        $ipP   = $scopeStart.Split(".")
        $mP    = $mask.Split(".")
        $scopeID = "$([int]$ipP[0] -band [int]$mP[0]).$([int]$ipP[1] -band [int]$mP[1]).$([int]$ipP[2] -band [int]$mP[2]).$([int]$ipP[3] -band [int]$mP[3])"
        Write-Host "  " -NoNewline; Write-Host " >> " -ForegroundColor Black -BackgroundColor Cyan -NoNewline
        Write-Host "  Scope ID calculado: $scopeID" -ForegroundColor Cyan
        Write-Host ("  " + $sbl + ($sh * 75) + $sbr) -ForegroundColor Cyan
        Write-Host ""

        Write-Host ("  " + $stl + $sh + "[ FILE SERVER ]" + ($sh * 58) + $str) -ForegroundColor Cyan
        $fsBase = LerValor "Pasta base das partilhas" "C:\Partilhas"
        Write-Host ("  " + $sbl + ($sh * 75) + $sbr) -ForegroundColor Cyan
        Write-Host ""

        Write-Host ("  " + $stl + $sh + "[ IIS ]" + ($sh * 66) + $str) -ForegroundColor Cyan
        $iisSiteName  = LerValor "Nome do site principal IIS" ($netbios + "Main")
        $iisMainPath  = LerValor "Pasta do site principal"    "C:\inetpub\wwwroot\$ouRaiz"
        $iisIntraPath = LerValor "Pasta da intranet"          "C:\inetpub\wwwroot\intranet"
        $iisPortMain  = LerValor "Porta site principal"       "80"
        $iisPortIntra = LerValor "Porta intranet"             "8080"
        Write-Host ("  " + $sbl + ($sh * 75) + $sbr) -ForegroundColor Cyan
        Write-Host ""

        Write-Host ("  " + $stl + $sh + "[ UTILIZADORES DO DOMINIO ]" + ($sh * 47) + $str) -ForegroundColor Cyan
        Write-Host ("  " + $sv + "  Grupos disponiveis: GRP_RH, GRP_IT, GRP_Publico, GRP_Admins, GRP_WebAdmins, GRP_BackupOps") -ForegroundColor DarkGray
        Write-Host ("  " + $sv + "  O login sera gerado automaticamente: nome.apelido@$fqdn") -ForegroundColor DarkGray
        Write-Host ""

        $listaUsers = @()

        # Utilizador admin (obrigatorio, fixo)
        Write-Host "  " -NoNewline; Write-Host " 1/7 " -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
        Write-Host "  Administrador IT (conta de servico)" -ForegroundColor Cyan
        $u1Nome     = LerValor "    Nome"     "Admin"
        $u1Apelido  = LerValor "    Apelido"  "TI"
        $u1Sam      = ($u1Nome.ToLower().Trim() + "." + $u1Apelido.ToLower().Trim()) -replace '\s',''
        Write-Host "    Login gerado: $u1Sam" -ForegroundColor Green
        $listaUsers += @{ Sam=$u1Sam; Nome=$u1Nome; Apelido=$u1Apelido; Dept="IT"; Grupo="GRP_IT"; Cargo="IT Admin"; IsAdmin=$true }

        Write-Host ""
        Write-Host "  " -NoNewline; Write-Host " 2/7 " -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
        Write-Host "  Utilizador RH 1" -ForegroundColor Cyan
        $u2Nome     = LerValor "    Nome"     "Ana"
        $u2Apelido  = LerValor "    Apelido"  "Silva"
        $u2Sam      = ($u2Nome.ToLower().Trim() + "." + $u2Apelido.ToLower().Trim()) -replace '\s',''
        Write-Host "    Login gerado: $u2Sam" -ForegroundColor Green
        $listaUsers += @{ Sam=$u2Sam; Nome=$u2Nome; Apelido=$u2Apelido; Dept="RH"; Grupo="GRP_RH"; Cargo="RH Tech"; IsAdmin=$false }

        Write-Host ""
        Write-Host "  " -NoNewline; Write-Host " 3/7 " -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
        Write-Host "  Utilizador RH 2" -ForegroundColor Cyan
        $u3Nome     = LerValor "    Nome"     "Carlos"
        $u3Apelido  = LerValor "    Apelido"  "Ferreira"
        $u3Sam      = ($u3Nome.ToLower().Trim() + "." + $u3Apelido.ToLower().Trim()) -replace '\s',''
        Write-Host "    Login gerado: $u3Sam" -ForegroundColor Green
        $listaUsers += @{ Sam=$u3Sam; Nome=$u3Nome; Apelido=$u3Apelido; Dept="RH"; Grupo="GRP_RH"; Cargo="RH Tech"; IsAdmin=$false }

        Write-Host ""
        Write-Host "  " -NoNewline; Write-Host " 4/7 " -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
        Write-Host "  Utilizador IT" -ForegroundColor Cyan
        $u4Nome     = LerValor "    Nome"     "Pedro"
        $u4Apelido  = LerValor "    Apelido"  "Costa"
        $u4Sam      = ($u4Nome.ToLower().Trim() + "." + $u4Apelido.ToLower().Trim()) -replace '\s',''
        Write-Host "    Login gerado: $u4Sam" -ForegroundColor Green
        $listaUsers += @{ Sam=$u4Sam; Nome=$u4Nome; Apelido=$u4Apelido; Dept="IT"; Grupo="GRP_IT"; Cargo="IT Tech"; IsAdmin=$false }

        Write-Host ""
        Write-Host "  " -NoNewline; Write-Host " 5/7 " -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
        Write-Host "  Utilizador Publico" -ForegroundColor Cyan
        $u5Nome     = LerValor "    Nome"     "Joao"
        $u5Apelido  = LerValor "    Apelido"  "Santos"
        $u5Sam      = ($u5Nome.ToLower().Trim() + "." + $u5Apelido.ToLower().Trim()) -replace '\s',''
        Write-Host "    Login gerado: $u5Sam" -ForegroundColor Green
        $listaUsers += @{ Sam=$u5Sam; Nome=$u5Nome; Apelido=$u5Apelido; Dept="Geral"; Grupo="GRP_Publico"; Cargo="Staff"; IsAdmin=$false }

        Write-Host ""
        Write-Host "  " -NoNewline; Write-Host " 6/7 " -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
        Write-Host "  Administrador Web IIS (conta de servico)" -ForegroundColor Cyan
        $u6Nome     = LerValor "    Nome"     "Web"
        $u6Apelido  = LerValor "    Apelido"  "Admin"
        $u6Sam      = ($u6Nome.ToLower().Trim() + "." + $u6Apelido.ToLower().Trim()) -replace '\s',''
        Write-Host "    Login gerado: $u6Sam" -ForegroundColor Green
        $listaUsers += @{ Sam=$u6Sam; Nome=$u6Nome; Apelido=$u6Apelido; Dept="IT"; Grupo="GRP_WebAdmins"; Cargo="Web Admin"; IsAdmin=$false }

        Write-Host ""
        Write-Host "  " -NoNewline; Write-Host " 7/7 " -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
        Write-Host "  Operador de Backup (conta de servico)" -ForegroundColor Cyan
        $u7Nome     = LerValor "    Nome"     "Backup"
        $u7Apelido  = LerValor "    Apelido"  "Op"
        $u7Sam      = ($u7Nome.ToLower().Trim() + "." + $u7Apelido.ToLower().Trim()) -replace '\s',''
        Write-Host "    Login gerado: $u7Sam" -ForegroundColor Green
        $listaUsers += @{ Sam=$u7Sam; Nome=$u7Nome; Apelido=$u7Apelido; Dept="IT"; Grupo="GRP_BackupOps"; Cargo="Backup Op"; IsAdmin=$false }

        Write-Host ("  " + $sbl + ($sh * 75) + $sbr) -ForegroundColor Cyan
        Write-Host ""

        Write-Host ("  " + $stl + $sh + "[ OUTRAS ]" + ($sh * 63) + $str) -ForegroundColor Cyan
        $logFile = LerValor "Ficheiro de log" "C:\Logs\Infra.log"
        Write-Host ("  " + $sbl + ($sh * 75) + $sbr) -ForegroundColor Cyan
        Write-Host ""

        # -- RESUMO ------------------------------------------------------------
        Clear-Host
        Write-Host ""
        Write-Host ("  " + $tl + ($h * 76) + $tr) -ForegroundColor DarkYellow
        Write-Host ("  " + $v) -NoNewline -ForegroundColor DarkYellow
        Write-Host "  " -NoNewline
        Write-Host " CHECK " -ForegroundColor Black -BackgroundColor DarkYellow -NoNewline
        Write-Host ("  RESUMO DA CONFIGURACAO" + (" " * 46)) -NoNewline -ForegroundColor Yellow
        Write-Host $v -ForegroundColor DarkYellow
        Write-Host ("  " + $bl + ($h * 76) + $br) -ForegroundColor DarkYellow
        Write-Host ""

        Write-Host ("  " + $stl + $sh + "[ DOMINIO ]" + ($sh * 29) + $str + "  " + $stl + $sh + "[ IPS ]" + ($sh * 22) + $str) -ForegroundColor DarkGray
        Write-Host ("  " + $sv + "  FQDN    : " + $fqdn.PadRight(24) + $sv + "  " + $sv + "  DC/DNS  : " + $ipDC.PadRight(15) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sv + "  NetBIOS : " + $netbios.PadRight(24) + $sv + "  " + $sv + "  Web     : " + $ipWeb.PadRight(15) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sv + "  OU raiz : " + $ouRaiz.PadRight(24) + $sv + "  " + $sv + "  Backup  : " + $ipBackup.PadRight(15) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sv + "  Senha   : " + $senhaUsers.PadRight(24) + $sv + "  " + $sv + "  DHCP    : " + $ipDHCP.PadRight(15) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sbl + ($sh * 41) + $sbr + "  " + $sv + "  GW      : " + $ipGateway.PadRight(15) + $sv) -ForegroundColor DarkGray
        Write-Host ("  " + (" " * 45) + $sv + "  Mascara : " + "$mask/$prefix".PadRight(15) + $sv) -ForegroundColor Gray
        Write-Host ("  " + (" " * 45) + $sbl + ($sh * 29) + $sbr) -ForegroundColor DarkGray
        Write-Host ""
        Write-Host ("  " + $stl + $sh + "[ DHCP ]" + ($sh * 65) + $str) -ForegroundColor DarkGray
        Write-Host ("  " + $sv + "  Scope : $scopeID   Pool : $scopeStart - $scopeEnd   Nome : $scopeName") -ForegroundColor Gray
        Write-Host ("  " + $sv + "  Excl  : $exclStart  a  $exclEnd") -ForegroundColor Gray
        Write-Host ("  " + $sbl + ($sh * 75) + $sbr) -ForegroundColor DarkGray
        Write-Host ""
        Write-Host ("  " + $stl + $sh + "[ IIS / FILE SERVER ]" + ($sh * 52) + $str) -ForegroundColor DarkGray
        Write-Host ("  " + $sv + "  Site     : $iisSiteName (porta $iisPortMain)   $iisMainPath") -ForegroundColor Gray
        Write-Host ("  " + $sv + "  Intranet : porta $iisPortIntra   $iisIntraPath") -ForegroundColor Gray
        Write-Host ("  " + $sv + "  Partilhas: $fsBase") -ForegroundColor Gray
        Write-Host ("  " + $sbl + ($sh * 75) + $sbr) -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Log: $logFile" -ForegroundColor DarkGray
        Write-Host ""

        # Resumo dos utilizadores
        Write-Host ("  " + $stl + $sh + "[ UTILIZADORES - Logins gerados ]" + ($sh * 40) + $str) -ForegroundColor DarkGray
        foreach ($u in $listaUsers) {
            $loginStr = ($u.Sam + "@" + $fqdn).PadRight(35)
            $grupoStr = $u.Grupo.PadRight(18)
            Write-Host ("  " + $sv + "  " + $loginStr + $grupoStr + $sv) -ForegroundColor Gray
        }
        Write-Host ("  " + $sbl + ($sh * 75) + $sbr) -ForegroundColor DarkGray
        Write-Host ""

        $ok = Confirmar "Confirma estas configuracoes?"
        if (-not $ok) {
            Write-Host ""
            Write-Host "  " -NoNewline
            Write-Host " AV " -ForegroundColor Black -BackgroundColor Yellow -NoNewline
            Write-Host "  A reiniciar configuracao..." -ForegroundColor Yellow
            Write-Host ""
            Start-Sleep -Seconds 1
        }
    } while (-not $ok)

    $CFG.DomainFQDN    = $fqdn
    $CFG.DomainNetBIOS = $netbios
    $CFG.OuRaiz        = $ouRaiz
    $CFG.SenhaUsers    = $senhaUsers
    $CFG.IP_DC         = $ipDC
    $CFG.IP_Web        = $ipWeb
    $CFG.IP_Backup     = $ipBackup
    $CFG.IP_DHCP       = $ipDHCP
    $CFG.IP_Gateway    = $ipGateway
    $CFG.SubnetMask    = $mask
    $CFG.SubnetPrefix  = $prefix
    $CFG.ScopeID       = $scopeID
    $CFG.ScopeStart    = $scopeStart
    $CFG.ScopeEnd      = $scopeEnd
    $CFG.ScopeName     = $scopeName
    $CFG.ExclStart     = $exclStart
    $CFG.ExclEnd       = $exclEnd
    $CFG.FSBase        = $fsBase
    $CFG.IISSiteName   = $iisSiteName
    $CFG.IISMainPath   = $iisMainPath
    $CFG.IISIntraPath  = $iisIntraPath
    $CFG.IISPortMain   = [int]$iisPortMain
    $CFG.IISPortIntra  = [int]$iisPortIntra
    $CFG.LogFile       = $logFile
    $CFG.Utilizadores  = $listaUsers   # array de hashtables com os dados de cada user

    $script:DC        = (($fqdn -split "\.") | ForEach-Object { "DC=$_" }) -join ","
    $script:OU_RAIZ   = $script:DC
    $script:OU_TESTES = "OU=$ouRaiz,$($script:DC)"
    $script:OU_USERS  = "OU=Utilizadores,OU=$ouRaiz,$($script:DC)"
    $script:OU_GRUPOS = "OU=Grupos,OU=$ouRaiz,$($script:DC)"

    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host " OK " -ForegroundColor Black -BackgroundColor Green -NoNewline
    Write-Host "  Configuracao guardada. A carregar o menu..." -ForegroundColor Green
    Start-Sleep -Seconds 1
}
