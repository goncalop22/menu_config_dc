# ==============================================================================
# MODULO_DNS.PS1  -  DNS (Domain Name System)
# Para usar isoladamente:
#   . .\Infra_Utils.ps1
#   . .\Modulo_DNS.ps1
#   Configurar_Setup
#   Menu_DNS
# ==============================================================================

function DNS_CriarZonas {
    Cabecalho "DNS - Criar Zonas"
    Import-Module DnsServer -ErrorAction SilentlyContinue

    # --- Zona direta ---
    try {
        $zona = $CFG.DomainFQDN
        $zonaExiste = Get-DnsServerZone -Name $zona -ErrorAction SilentlyContinue
        if ($zonaExiste) {
            if ($zonaExiste.ReplicationScope -ne "Forest") {
                Registar "Zona '$zona' existe mas com scope '$($zonaExiste.ReplicationScope)'. A converter para Forest..." "AVISO"
                Set-DnsServerPrimaryZone -Name $zona -ReplicationScope "Forest" -ErrorAction SilentlyContinue
                Registar "Scope da zona '$zona' atualizado para Forest." "OK"
            } else {
                Registar "Zona '$zona' ja existe com scope correto (Forest)." "AVISO"
            }
        }
        else {
            Add-DnsServerPrimaryZone -Name $zona -ReplicationScope "Forest" -DynamicUpdate "Secure"
            Registar "Zona directa '$zona' criada." "OK"
        }
    }
    catch { Registar "Erro zona directa: $($_.Exception.Message)" "ERRO" }

    # --- Zona inversa ---
    try {
        $partes  = $CFG.ScopeID.Split(".")
        $zonaInv = "$($partes[2]).$($partes[1]).$($partes[0]).in-addr.arpa"
        $networkID = "$($CFG.ScopeID)/$($CFG.SubnetPrefix)"
        $zonaInvExiste = Get-DnsServerZone -Name $zonaInv -ErrorAction SilentlyContinue
        if ($zonaInvExiste) {
            Registar "Zona inversa '$zonaInv' ja existe." "AVISO"
        }
        else {
            Add-DnsServerPrimaryZone -NetworkID $networkID -ReplicationScope "Forest" -DynamicUpdate "Secure"
            Registar "Zona inversa '$zonaInv' criada. (rede: $networkID)" "OK"
        }
    }
    catch { Registar "Erro zona inversa: $($_.Exception.Message)" "ERRO" }

    Pausar
}

function DNS_CriarRegistos {
    Cabecalho "DNS - Registos A e CNAME"
    Import-Module DnsServer -ErrorAction SilentlyContinue
    $zona = $CFG.DomainFQDN
    if (-not (Get-DnsServerZone -Name $zona -ErrorAction SilentlyContinue)) {
        Registar "Zona '$zona' nao existe! Cria as zonas primeiro (opcao 1)." "ERRO"
        Pausar; return
    }
    $registosA = @(
        @{ Nome = "dc";      IP = $CFG.IP_DC      }, @{ Nome = "web";     IP = $CFG.IP_Web     },
        @{ Nome = "server";  IP = $CFG.IP_Web     }, @{ Nome = "backup";  IP = $CFG.IP_Backup  },
        @{ Nome = "dhcp";    IP = $CFG.IP_DHCP    }, @{ Nome = "gateway"; IP = $CFG.IP_Gateway }
    )
    _SecHeader "Registos A"
    foreach ($r in $registosA) {
        try {
            if (Get-DnsServerResourceRecord -ZoneName $zona -Name $r.Nome -RRType A -ErrorAction SilentlyContinue) { Registar "Registo A '$($r.Nome)' ja existe." "AVISO" }
            else {
                Add-DnsServerResourceRecordA -ZoneName $zona -Name $r.Nome -IPv4Address $r.IP -CreatePtr:$true
                Registar "A: $($r.Nome).$zona -> $($r.IP)" "OK"
            }
        }
        catch { Registar "Erro registo A '$($r.Nome)': $($_.Exception.Message)" "ERRO" }
    }
    $registosCNAME = @(
        @{ Nome = "www"; Destino = "web.$zona" }, @{ Nome = "intranet"; Destino = "web.$zona" },
        @{ Nome = "monitor"; Destino = "dc.$zona" }
    )
    Write-Host ""
    _SecHeader "Registos CNAME"
    foreach ($c in $registosCNAME) {
        try {
            if (Get-DnsServerResourceRecord -ZoneName $zona -Name $c.Nome -RRType CName -ErrorAction SilentlyContinue) { Registar "CNAME '$($c.Nome)' ja existe." "AVISO" }
            else {
                Add-DnsServerResourceRecordCName -ZoneName $zona -Name $c.Nome -HostNameAlias $c.Destino
                Registar "CNAME: $($c.Nome).$zona -> $($c.Destino)" "OK"
            }
        }
        catch { Registar "Erro CNAME '$($c.Nome)': $($_.Exception.Message)" "ERRO" }
    }
    Pausar
}

function DNS_VerZonas {
    Cabecalho "DNS - Estado Actual"
    Import-Module DnsServer -ErrorAction SilentlyContinue
    try {
        _SecHeader "Zonas"
        Get-DnsServerZone | Format-Table -AutoSize ZoneName, ZoneType, ReplicationScope, DynamicUpdate
        _SecHeader "Registos em '$($CFG.DomainFQDN)'"
        Get-DnsServerResourceRecord -ZoneName $CFG.DomainFQDN | Sort-Object RecordType, HostName | Format-Table -AutoSize HostName, RecordType, RecordData
    }
    catch { Registar "Erro ao listar DNS: $($_.Exception.Message)" "ERRO" }
    Pausar
}

function Menu_DNS {
    do {
        Cabecalho "MODULO 2 - DNS"
        $tl=[string][char]0x2554; $tr=[string][char]0x2557; $bl=[string][char]0x255A; $br=[string][char]0x255D
        Write-Host ("  " + $tl + "===" + [string][char]0x2566 + ("=" * 72) + $tr) -ForegroundColor DarkCyan
        _MLinha "1" "Criar Zona $($CFG.DomainFQDN) + Zona Inversa"
        _MThin
        _MLinha "2" "Criar Registos A e CNAME"
        _MThin
        _MLinha "3" "Ver Zonas e Registos actuais"
        _MSep
        _MLinha "4" "Configurar TUDO o DNS  (opcoes 1 e 2 em sequencia)" "Yellow"
        _MSep
        _MLinha "0" "Voltar ao Menu Principal" "DarkGray"
        Write-Host ("  " + $bl + "===" + [string][char]0x2569 + ("=" * 72) + $br) -ForegroundColor DarkCyan
        Write-Host ""
        $op = Read-Host "  Opcao"
        if     ($op -eq "1") { DNS_CriarZonas }
        elseif ($op -eq "2") { DNS_CriarRegistos }
        elseif ($op -eq "3") { DNS_VerZonas }
        elseif ($op -eq "4") { DNS_CriarZonas; DNS_CriarRegistos }
        elseif ($op -eq "0") { return }
        else { Write-Host "  " -NoNewline; Write-Host " ER " -ForegroundColor White -BackgroundColor Red -NoNewline; Write-Host "  Opcao invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    } while ($true)
}
