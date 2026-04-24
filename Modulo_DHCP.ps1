# ==============================================================================
# MODULO_DHCP.PS1  -  DHCP (Dynamic Host Configuration Protocol)
# Para usar isoladamente:
#   . .\Infra_Utils.ps1
#   . .\Modulo_DHCP.ps1
#   Configurar_Setup
#   Menu_DHCP
# ==============================================================================

function DHCP_Autorizar {
    Cabecalho "DHCP - Autorizar no AD"
    try {
        $jaAut = Get-DhcpServerInDC -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -eq $CFG.IP_DC }
        if ($jaAut) { Registar "Servidor DHCP ja esta autorizado no AD." "AVISO" }
        else {
            Add-DhcpServerInDC -DnsName "dc.$($CFG.DomainFQDN)" -IPAddress $CFG.IP_DC
            Registar "Servidor DHCP autorizado no AD." "OK"
        }
        Write-Host ""; _SecHeader "Servidores autorizados"
        Get-DhcpServerInDC | Format-Table -AutoSize IPAddress, DnsName
    }
    catch { Registar "Erro autorizar DHCP: $($_.Exception.Message)" "ERRO" }
    Pausar
}

function DHCP_CriarScope {
    Cabecalho "DHCP - Criar Scope e Opcoes"
    Registar "A verificar autorizacao do DHCP no AD..." "INFO"
    try {
        $jaAut = Get-DhcpServerInDC -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -eq $CFG.IP_DC }
        if (-not $jaAut) {
            Registar "DHCP nao esta autorizado. A autorizar agora..." "AVISO"
            Add-DhcpServerInDC -DnsName "dc.$($CFG.DomainFQDN)" -IPAddress $CFG.IP_DC
            Registar "DHCP autorizado no AD." "OK"
            Registar "A reiniciar servico DHCP..." "INFO"
            Restart-Service -Name DHCPServer -Force
            Start-Sleep -Seconds 3
            Registar "Servico DHCP reiniciado." "OK"
        }
        else { Registar "DHCP ja esta autorizado no AD." "OK" }
    }
    catch { Registar "Aviso autorizacao: $($_.Exception.Message)" "AVISO" }
    Write-Host ""
    try {
        $scopeExiste = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | Where-Object { $_.ScopeId -eq $CFG.ScopeID }
        if ($scopeExiste) { Registar "Scope '$($CFG.ScopeID)' ja existe." "AVISO" }
        else {
            $params = @{
                Name = $CFG.ScopeName; StartRange = $CFG.ScopeStart; EndRange = $CFG.ScopeEnd
                SubnetMask = $CFG.SubnetMask; Description = "IPs automaticos para clientes"
                LeaseDuration = [TimeSpan]::FromDays(8); State = "Active"
            }
            Add-DhcpServerv4Scope @params
            Registar "Scope criado: $($CFG.ScopeStart) -> $($CFG.ScopeEnd)  (ID: $($CFG.ScopeID))" "OK"
        }
    }
    catch {
        Registar "Erro criar scope: $($_.Exception.Message)" "ERRO"
        Write-Host ""
        $sv=[string][char]0x2502; $sh=[string][char]0x2500; $stl=[string][char]0x250C; $str=[string][char]0x2510; $sbl=[string][char]0x2514; $sbr=[string][char]0x2518
        Write-Host ("  " + $stl + $sh + "[ CAUSAS POSSIVEIS ]" + ($sh * 54) + $str) -ForegroundColor Yellow
        Write-Host ("  " + $sv + "  1. Scope ID incorreto - deve ser endereco de rede (ex: 192.168.0.0)".PadRight(75) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sv + "  2. Servico DHCP nao esta a correr".PadRight(75) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sv + "  3. DHCP nao autorizado no AD".PadRight(75) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sv + "  4. Ja existe um scope com IPs sobrepostos".PadRight(75) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sbl + ($sh * 75) + $sbr) -ForegroundColor Yellow
        Write-Host ""; Write-Host "  Scope ID configurado: $($CFG.ScopeID)" -ForegroundColor Cyan
        Get-Service -Name DHCPServer -ErrorAction SilentlyContinue | Format-Table -AutoSize Name, Status, DisplayName
        Pausar; return
    }
    try {
        Add-DhcpServerv4ExclusionRange -ScopeId $CFG.ScopeID -StartRange $CFG.ExclStart -EndRange $CFG.ExclEnd -ErrorAction SilentlyContinue
        Registar "Exclusao: $($CFG.ExclStart) a $($CFG.ExclEnd)" "OK"
    }
    catch { Registar "Exclusao ja existe ou erro menor." "AVISO" }
    try {
        Set-DhcpServerv4OptionValue -ScopeId $CFG.ScopeID -Router $CFG.IP_Gateway -DnsServer $CFG.IP_DC -DnsDomain $CFG.DomainFQDN
        Registar "Opcoes definidas: GW=$($CFG.IP_Gateway) DNS=$($CFG.IP_DC) Dom=$($CFG.DomainFQDN)" "OK"
    }
    catch { Registar "Erro opcoes scope: $($_.Exception.Message)" "ERRO" }
    Pausar
}

function DHCP_CriarReservas {
    Cabecalho "DHCP - Reservas de IP"
    Write-Host "  Quantas reservas quer adicionar?" -ForegroundColor White
    $qtd = Read-Host "  Numero de reservas"
    if ($qtd -notmatch "^\d+$" -or [int]$qtd -eq 0) { Registar "Numero invalido. Operacao cancelada." "AVISO"; Pausar; return }
    $reservas = @()
    for ($i = 1; $i -le [int]$qtd; $i++) {
        Write-Host ""; _SecHeader "Reserva $i de $qtd"
        $nome = LerValor "  Nome / descricao" "Dispositivo-$i"
        $ip   = LerValor "  IP a reservar" ""
        $mac  = LerValor "  MAC address  (formato: 00-11-22-33-44-55)" ""
        $reservas += @{ IP = $ip; MAC = $mac; Nome = $nome }
    }
    Write-Host ""
    foreach ($r in $reservas) {
        try {
            $existe = Get-DhcpServerv4Reservation -ScopeId $CFG.ScopeID -ClientId $r.MAC -ErrorAction SilentlyContinue
            if ($existe) { Registar "Reserva '$($r.Nome)' ja existe." "AVISO" }
            else {
                Add-DhcpServerv4Reservation -ScopeId $CFG.ScopeID -IPAddress $r.IP -ClientId $r.MAC -Description $r.Nome
                Registar "Reserva: $($r.Nome) -> $($r.IP) [$($r.MAC)]" "OK"
            }
        }
        catch { Registar "Erro reserva '$($r.Nome)': $($_.Exception.Message)" "ERRO" }
    }
    Pausar
}

function DHCP_VerEstado {
    Cabecalho "DHCP - Estado Actual"
    try {
        _SecHeader "Scopes"
        Get-DhcpServerv4Scope | Format-Table -AutoSize ScopeId, Name, StartRange, EndRange, State
        _SecHeader "Opcoes"
        Get-DhcpServerv4OptionValue -ScopeId $CFG.ScopeID -ErrorAction SilentlyContinue | Format-Table -AutoSize OptionId, Name, Value
        _SecHeader "Reservas"
        Get-DhcpServerv4Reservation -ScopeId $CFG.ScopeID -ErrorAction SilentlyContinue | Format-Table -AutoSize IPAddress, ClientId, Description
        _SecHeader "Leases Activos"
        Get-DhcpServerv4Lease -ScopeId $CFG.ScopeID -ErrorAction SilentlyContinue | Format-Table -AutoSize IPAddress, HostName, LeaseExpiryTime
    }
    catch { Registar "Erro estado DHCP: $($_.Exception.Message)" "ERRO" }
    Pausar
}

function Menu_DHCP {
    do {
        Cabecalho "MODULO 3 - DHCP"
        $tl=[string][char]0x2554; $tr=[string][char]0x2557; $bl=[string][char]0x255A; $br=[string][char]0x255D
        Write-Host ("  " + $tl + "===" + [string][char]0x2566 + ("=" * 72) + $tr) -ForegroundColor DarkCyan
        _MInfo "Pool: $($CFG.ScopeStart) a $($CFG.ScopeEnd)   Exclusao: $($CFG.ExclStart) a $($CFG.ExclEnd)"
        _MSep
        _MLinha "1" "Autorizar servidor DHCP no AD"
        _MThin
        _MLinha "2" "Criar Scope + Exclusoes + Opcoes"
        _MThin
        _MLinha "3" "Adicionar Reservas de IP  (inseridas pelo utilizador)"
        _MThin
        _MLinha "4" "Ver Estado actual"
        _MSep
        _MLinha "5" "Configurar TUDO o DHCP  (opcoes 1 e 2 em sequencia)" "Yellow"
        _MSep
        _MLinha "0" "Voltar ao Menu Principal" "DarkGray"
        Write-Host ("  " + $bl + "===" + [string][char]0x2569 + ("=" * 72) + $br) -ForegroundColor DarkCyan
        Write-Host ""
        $op = Read-Host "  Opcao"
        if     ($op -eq "1") { DHCP_Autorizar }
        elseif ($op -eq "2") { DHCP_CriarScope }
        elseif ($op -eq "3") { DHCP_CriarReservas }
        elseif ($op -eq "4") { DHCP_VerEstado }
        elseif ($op -eq "5") { DHCP_Autorizar; DHCP_CriarScope }
        elseif ($op -eq "0") { return }
        else { Write-Host "  " -NoNewline; Write-Host " ER " -ForegroundColor White -BackgroundColor Red -NoNewline; Write-Host "  Opcao invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    } while ($true)
}
