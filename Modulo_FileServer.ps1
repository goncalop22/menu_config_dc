# ==============================================================================
# MODULO_FILESERVER.PS1  -  File Server (Partilhas SMB + Permissoes NTFS)
# Para usar isoladamente:
#   . .\Infra_Utils.ps1
#   . .\Modulo_FileServer.ps1
#   Configurar_Setup
#   Menu_FileServer
# ==============================================================================

function FS_CriarPartilhas {
    Cabecalho "File Server - Partilhas e Permissoes NTFS"
    $nb = $CFG.DomainNetBIOS; $base = $CFG.FSBase
    $partilhas = @(
        @{ Nome="RH";      Path="$base\RH";      Desc="Pasta restrita - Recursos Humanos";           Perms=@(@{Grupo="$nb\GRP_RH";Direito="Modify"},@{Grupo="$nb\GRP_Admins";Direito="FullControl"}) },
        @{ Nome="IT";      Path="$base\IT";      Desc="Pasta restrita - Tecnologias de Informacao";  Perms=@(@{Grupo="$nb\GRP_IT";Direito="Modify"},@{Grupo="$nb\GRP_Admins";Direito="FullControl"}) },
        @{ Nome="Publico"; Path="$base\Publico"; Desc="Pasta publica - acesso geral";                Perms=@(@{Grupo="$nb\GRP_Publico";Direito="Modify"},@{Grupo="$nb\GRP_RH";Direito="Read"},@{Grupo="$nb\GRP_IT";Direito="Modify"},@{Grupo="$nb\GRP_Admins";Direito="FullControl"}) }
    )
    foreach ($p in $partilhas) {
        Write-Host ""; _SecHeader $p.Nome
        try {
            if (-not (Test-Path $p.Path)) { New-Item -ItemType Directory -Path $p.Path -Force | Out-Null; Registar "Pasta criada: $($p.Path)" "OK" }
            else { Registar "Pasta '$($p.Path)' ja existe." "AVISO" }
            $acl = Get-Acl $p.Path; $acl.SetAccessRuleProtection($true, $false)
            $rAdmin = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators","FullControl","ContainerInherit,ObjectInherit","None","Allow")
            $acl.AddAccessRule($rAdmin)
            foreach ($perm in $p.Perms) {
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($perm.Grupo,$perm.Direito,"ContainerInherit,ObjectInherit","None","Allow")
                $acl.AddAccessRule($rule)
                Registar "NTFS [$($p.Nome)]: $($perm.Grupo) = $($perm.Direito)" "OK"
            }
            Set-Acl -Path $p.Path -AclObject $acl
            if (Get-SmbShare -Name $p.Nome -ErrorAction SilentlyContinue) { Registar "Partilha SMB '$($p.Nome)' ja existe." "AVISO" }
            else {
                New-SmbShare -Name $p.Nome -Path $p.Path -Description $p.Desc -FullAccess "BUILTIN\Administrators" -ChangeAccess "$nb\Domain Users" | Out-Null
                Registar "SMB criado: \\$(hostname)\$($p.Nome)" "OK"
            }
        }
        catch { Registar "Erro '$($p.Nome)': $($_.Exception.Message)" "ERRO" }
    }
    Pausar
}

function FS_VerPartilhas {
    Cabecalho "File Server - Partilhas Activas"
    try {
        _SecHeader "Partilhas SMB"
        Get-SmbShare | Where-Object { $_.Name -notmatch "^(ADMIN|IPC|print|C|D|E)\$" } | Format-Table -AutoSize Name, Path, Description
        _SecHeader "Permissoes"
        $nomes = (Get-SmbShare | Where-Object { $_.Name -notmatch "^(ADMIN|IPC|print|C|D|E)\$" }).Name
        foreach ($n in $nomes) { Get-SmbShareAccess -Name $n | Format-Table -AutoSize Name, AccountName, AccessRight }
    }
    catch { Registar "Erro listar partilhas: $($_.Exception.Message)" "ERRO" }
    Pausar
}

function Menu_FileServer {
    do {
        Cabecalho "MODULO 4 - File Server"
        $tl=[string][char]0x2554; $tr=[string][char]0x2557; $bl=[string][char]0x255A; $br=[string][char]0x255D
        Write-Host ("  " + $tl + "===" + [string][char]0x2566 + ("=" * 72) + $tr) -ForegroundColor DarkCyan
        _MInfo "Pasta base: $($CFG.FSBase)"
        _MSep
        _MLinha "1" "Criar Partilhas RH, IT e Publico + Permissoes NTFS"
        _MThin
        _MLinha "2" "Ver Partilhas e Permissoes actuais"
        _MSep
        _MLinha "0" "Voltar ao Menu Principal" "DarkGray"
        Write-Host ("  " + $bl + "===" + [string][char]0x2569 + ("=" * 72) + $br) -ForegroundColor DarkCyan
        Write-Host ""
        $op = Read-Host "  Opcao"
        if     ($op -eq "1") { FS_CriarPartilhas }
        elseif ($op -eq "2") { FS_VerPartilhas }
        elseif ($op -eq "0") { return }
        else { Write-Host "  " -NoNewline; Write-Host " ER " -ForegroundColor White -BackgroundColor Red -NoNewline; Write-Host "  Opcao invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    } while ($true)
}
