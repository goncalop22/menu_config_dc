# ==============================================================================
# MODULO_AD.PS1  -  Active Directory
# Para usar isoladamente:
#   . .\Infra_Utils.ps1
#   . .\Modulo_AD.ps1
#   Configurar_Setup
#   Menu_AD
# ==============================================================================

function AD_CriarOUs {
    Cabecalho "AD DS - Criar Unidades Organizacionais"
    if (-not (TestarAD)) { return }
    $lista = @(
        @{ Nome = $CFG.OuRaiz;    Path = $script:DC        },
        @{ Nome = "Utilizadores"; Path = $script:OU_TESTES },
        @{ Nome = "Grupos";       Path = $script:OU_TESTES },
        @{ Nome = "Servidores";   Path = $script:OU_TESTES },
        @{ Nome = "Computadores"; Path = $script:OU_TESTES }
    )
    foreach ($ou in $lista) {
        try {
            $existe = Get-ADOrganizationalUnit -Filter "Name -eq '$($ou.Nome)'" -SearchBase $ou.Path -ErrorAction SilentlyContinue
            if ($existe) { Registar "OU '$($ou.Nome)' ja existe." "AVISO" }
            else {
                New-ADOrganizationalUnit -Name $ou.Nome -Path $ou.Path -ProtectedFromAccidentalDeletion $true
                Registar "OU '$($ou.Nome)' criada." "OK"
            }
        }
        catch { Registar "Erro OU '$($ou.Nome)': $($_.Exception.Message)" "ERRO" }
    }
    Pausar
}

function AD_CriarGrupos {
    Cabecalho "AD DS - Criar Grupos de Seguranca"
    if (-not (TestarAD)) { return }
    $lista = @(
        @{ Nome = "GRP_RH";        Desc = "Recursos Humanos" },
        @{ Nome = "GRP_IT";        Desc = "Tecnologias de Informacao" },
        @{ Nome = "GRP_Publico";   Desc = "Acesso pasta publica" },
        @{ Nome = "GRP_Admins";    Desc = "Administradores do projeto" },
        @{ Nome = "GRP_WebAdmins"; Desc = "Administradores IIS" },
        @{ Nome = "GRP_BackupOps"; Desc = "Operadores de Backup" }
    )
    foreach ($grp in $lista) {
        try {
            $existe = Get-ADGroup -Filter "Name -eq '$($grp.Nome)'" -ErrorAction SilentlyContinue
            if ($existe) { Registar "Grupo '$($grp.Nome)' ja existe." "AVISO" }
            else {
                New-ADGroup -Name $grp.Nome -GroupScope Global -GroupCategory Security -Description $grp.Desc -Path $script:OU_GRUPOS
                Registar "Grupo '$($grp.Nome)' criado." "OK"
            }
        }
        catch { Registar "Erro grupo '$($grp.Nome)': $($_.Exception.Message)" "ERRO" }
    }
    Pausar
}

function AD_CriarUtilizadores {
    Cabecalho "AD DS - Criar Utilizadores"
    if (-not (TestarAD)) { return }

    # Verificar se os utilizadores foram configurados no Setup
    if (-not $CFG.Utilizadores -or $CFG.Utilizadores.Count -eq 0) {
        Registar "Nenhum utilizador configurado. Corre o Setup primeiro (opcao 9)." "ERRO"
        Pausar; return
    }

    $senha = ConvertTo-SecureString $CFG.SenhaUsers -AsPlainText -Force

    foreach ($u in $CFG.Utilizadores) {
        try {
            $existe = Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue
            if ($existe) { Registar "Utilizador '$($u.Sam)' ja existe." "AVISO"; continue }
            $params = @{
                SamAccountName        = $u.Sam
                UserPrincipalName     = "$($u.Sam)@$($CFG.DomainFQDN)"
                GivenName             = $u.Nome
                Surname               = $u.Apelido
                DisplayName           = "$($u.Nome) $($u.Apelido)"
                Department            = $u.Dept
                Title                 = $u.Cargo
                Path                  = $script:OU_USERS
                AccountPassword       = $senha
                PasswordNeverExpires  = $false
                ChangePasswordAtLogon = $true
                Enabled               = $true
            }
            New-ADUser @params
            Add-ADGroupMember -Identity $u.Grupo -Members $u.Sam
            # Se for o admin (primeiro user marcado com IsAdmin), adicionar ao GRP_Admins
            if ($u.IsAdmin -eq $true) { Add-ADGroupMember -Identity "GRP_Admins" -Members $u.Sam }
            Registar "Criado: $($u.Nome) $($u.Apelido)  ->  Login: $($u.Sam)@$($CFG.DomainFQDN)  ->  $($u.Grupo)" "OK"
        }
        catch { Registar "Erro utilizador '$($u.Sam)': $($_.Exception.Message)" "ERRO" }
    }
    Write-Host ""
    Registar "Senha padrao: $($CFG.SenhaUsers)  (alterar no 1o login)" "AVISO"
    Pausar
}

function AD_PoliticaPasswords {
    Cabecalho "AD DS - Politica de Passwords"
    if (-not (TestarAD)) { return }
    Write-Host "  Valores actuais por defeito - pode alterar cada um:" -ForegroundColor DarkGray
    Write-Host ""
    $minLen  = LerValor "Comprimento minimo de password" "10"
    $hist    = LerValor "Historico de passwords"         "12"
    $maxAge  = LerValor "Validade maxima (dias)"         "42"
    $minAge  = LerValor "Validade minima (dias)"         "1"
    $lockThr = LerValor "Tentativas ate bloqueio"        "5"
    $lockDur = LerValor "Duracao do bloqueio (minutos)"  "30"
    Write-Host ""
    try {
        $params = @{
            Identity = $CFG.DomainFQDN; MinPasswordLength = [int]$minLen
            PasswordHistoryCount = [int]$hist; MaxPasswordAge = "$maxAge.00:00:00"
            MinPasswordAge = "$minAge.00:00:00"; LockoutThreshold = [int]$lockThr
            LockoutDuration = "00:$($lockDur.PadLeft(2,'0')):00"
            LockoutObservationWindow = "00:$($lockDur.PadLeft(2,'0')):00"
            ComplexityEnabled = $true; ReversibleEncryptionEnabled = $false
        }
        Set-ADDefaultDomainPasswordPolicy @params
        Registar "Politica de passwords aplicada." "OK"
        Write-Host ""
        $sv=[string][char]0x2502; $sh=[string][char]0x2500; $stl=[string][char]0x250C; $str=[string][char]0x2510; $sbl=[string][char]0x2514; $sbr=[string][char]0x2518
        Write-Host ("  " + $stl + $sh + "[ REGRAS APLICADAS ]" + ($sh * 54) + $str) -ForegroundColor DarkGray
        Write-Host ("  " + $sv + "  Comprimento minimo : $minLen chars".PadRight(75) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sv + "  Historico          : $hist passwords".PadRight(75) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sv + "  Validade maxima    : $maxAge dias".PadRight(75) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sv + "  Validade minima    : $minAge dia(s)".PadRight(75) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sv + "  Bloqueio apos      : $lockThr tentativas".PadRight(75) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sv + "  Duracao bloqueio   : $lockDur minutos".PadRight(75) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sv + "  Complexidade       : Activada".PadRight(75) + $sv) -ForegroundColor Gray
        Write-Host ("  " + $sbl + ($sh * 75) + $sbr) -ForegroundColor DarkGray
    }
    catch { Registar "Erro politica passwords: $($_.Exception.Message)" "ERRO" }
    Pausar
}

function AD_CriarGPOs {
    Cabecalho "AD DS - Group Policy Objects"
    if (-not (TestarAD)) { return }
    try {
        $nome = "GPO_BloqueioEcra"
        if (-not (Get-GPO -Name $nome -ErrorAction SilentlyContinue)) {
            New-GPO -Name $nome -Comment "Bloqueio automatico de sessao" | Out-Null
            Registar "GPO '$nome' criada." "OK"
        }
        $chave = "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop"
        Set-GPRegistryValue -Name $nome -Key $chave -ValueName "ScreenSaverTimeout"  -Type String -Value "600"
        Set-GPRegistryValue -Name $nome -Key $chave -ValueName "ScreenSaveActive"    -Type String -Value "1"
        Set-GPRegistryValue -Name $nome -Key $chave -ValueName "ScreenSaverIsSecure" -Type String -Value "1"
        New-GPLink -Name $nome -Target $script:OU_USERS -LinkEnabled Yes -ErrorAction SilentlyContinue | Out-Null
        Registar "GPO '$nome' ligada a OU=Utilizadores." "OK"
    }
    catch { Registar "Erro GPO BloqueioEcra: $($_.Exception.Message)" "ERRO" }
    try {
        $nome = "GPO_SegurancaBasica"
        if (-not (Get-GPO -Name $nome -ErrorAction SilentlyContinue)) {
            New-GPO -Name $nome -Comment "Desactivar AutoRun" | Out-Null
            Registar "GPO '$nome' criada." "OK"
        }
        $chave2 = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        Set-GPRegistryValue -Name $nome -Key $chave2 -ValueName "NoDriveTypeAutoRun" -Type DWord -Value 255
        New-GPLink -Name $nome -Target $script:OU_TESTES -LinkEnabled Yes -ErrorAction SilentlyContinue | Out-Null
        Registar "GPO '$nome' ligada a OU=$($CFG.OuRaiz)." "OK"
    }
    catch { Registar "Erro GPO SegurancaBasica: $($_.Exception.Message)" "ERRO" }
    try {
        $nome = "GPO_AvisoLogin"
        if (-not (Get-GPO -Name $nome -ErrorAction SilentlyContinue)) {
            New-GPO -Name $nome -Comment "Aviso legal no login" | Out-Null
            Registar "GPO '$nome' criada." "OK"
        }
        $chave3 = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System"
        Set-GPRegistryValue -Name $nome -Key $chave3 -ValueName "legalnoticecaption" -Type String -Value "$($CFG.DomainFQDN) - Acesso Restrito"
        Set-GPRegistryValue -Name $nome -Key $chave3 -ValueName "legalnoticetext"    -Type String -Value "Acesso reservado a colaboradores autorizados. Actividade monitorizada."
        New-GPLink -Name $nome -Target $script:DC -LinkEnabled Yes -ErrorAction SilentlyContinue | Out-Null
        Registar "GPO '$nome' ligada ao dominio." "OK"
    }
    catch { Registar "Erro GPO AvisoLogin: $($_.Exception.Message)" "ERRO" }
    Pausar
}

function Menu_AD {
    do {
        Cabecalho "MODULO 1 - Active Directory"
        $vc=[string][char]0x2551; $tl=[string][char]0x2554; $tr=[string][char]0x2557; $bl=[string][char]0x255A; $br=[string][char]0x255D; $h=[string][char]0x2550
        Write-Host ("  " + $tl + "===" + [string][char]0x2566 + ("=" * 72) + $tr) -ForegroundColor DarkCyan
        _MLinha "1" "Criar OUs            Utilizadores, Grupos, Servidores, Computadores"
        _MThin
        _MLinha "2" "Criar Grupos         RH, IT, Publico, Admins, WebAdmins, BackupOps"
        _MThin
        _MLinha "3" "Criar Utilizadores   7 contas de exemplo pre-definidas"
        _MThin
        _MLinha "4" "Politica de Passwords"
        _MThin
        _MLinha "5" "Criar GPOs           Bloqueio ecra, AutoRun, Aviso login"
        _MSep
        _MLinha "6" "Configurar TUDO o AD  (opcoes 1 a 5 em sequencia)" "Yellow"
        _MSep
        _MLinha "0" "Voltar ao Menu Principal" "DarkGray"
        Write-Host ("  " + $bl + "===" + [string][char]0x2569 + ("=" * 72) + $br) -ForegroundColor DarkCyan
        Write-Host ""
        $op = Read-Host "  Opcao"
        if     ($op -eq "1") { AD_CriarOUs }
        elseif ($op -eq "2") { AD_CriarGrupos }
        elseif ($op -eq "3") { AD_CriarUtilizadores }
        elseif ($op -eq "4") { AD_PoliticaPasswords }
        elseif ($op -eq "5") { AD_CriarGPOs }
        elseif ($op -eq "6") { AD_CriarOUs; AD_CriarGrupos; AD_CriarUtilizadores; AD_PoliticaPasswords; AD_CriarGPOs }
        elseif ($op -eq "0") { return }
        else { Write-Host "  " -NoNewline; Write-Host " ER " -ForegroundColor White -BackgroundColor Red -NoNewline; Write-Host "  Opcao invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    } while ($true)
}
