# 🖥️ Menu Configurar WS2025 — Menu de Configuração de Infraestrutura Windows Server 2025

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)
![Windows Server](https://img.shields.io/badge/Windows%20Server-2025-0078D4?logo=windows&logoColor=white)
![Active Directory](https://img.shields.io/badge/Active%20Directory-Suportado-brightgreen)
![License](https://img.shields.io/badge/License-MIT-yellow)

> Script PowerShell modular para automatizar a configuração completa de uma infraestrutura Windows Server 2025 — AD DS, DNS, DHCP, File Server e IIS — através de um menu interativo em consola.

---

## 📋 Índice

- [Sobre o Projeto](#sobre-o-projeto)
- [Funcionalidades](#funcionalidades)
- [Estrutura de Ficheiros](#estrutura-de-ficheiros)
- [Pré-requisitos](#pré-requisitos)
- [Como Usar](#como-usar)
- [Módulos](#módulos)
- [Capturas de Ecrã](#capturas-de-ecrã)
- [Contribuições](#contribuições)

---

## 📖 Sobre o Projeto

Este projeto nasceu no contexto de um trabalho académico de infraestruturas de redes com Windows Server 2025. O objetivo foi criar uma ferramenta de linha de comando que permitisse configurar todos os serviços de rede de forma guiada, rápida e com feedback visual claro — sem precisar de memorizar cmdlets ou navegar manualmente pelo Server Manager.

O script foi construído de raiz em PowerShell, com foco em:
- **Interface visual** com caixas e cores em consola (caracteres Unicode box-drawing)
- **Modularidade** — cada serviço tem o seu próprio ficheiro `.ps1` independente
- **Segurança** — verificação de administrador, confirmações antes de ações críticas, log completo de todas as operações
- **Facilidade de uso** — assistente de configuração inicial com valores por defeito, tudo configurável

---

## ✨ Funcionalidades

- 🗂️ **Active Directory** — Criação automática de OUs, Grupos de Segurança, Utilizadores e GPOs
- 🌐 **DNS** — Zonas direta e inversa, registos A e CNAME
- 📡 **DHCP** — Autorização no AD, Scope com exclusões, Reservas de IP
- 📁 **File Server** — Partilhas SMB com permissões NTFS granulares por grupo
- 🌍 **IIS** — Site principal e Intranet com páginas HTML geradas automaticamente
- 📊 **Estado Geral** — Dashboard rápido com estado de todos os serviços
- ⚡ **Configuração Total** — Executa todos os módulos em sequência com um único comando
- 📝 **Logging** — Registo detalhado de todas as operações em ficheiro de log
- 🔄 **Reutilizável** — Cada módulo pode ser executado isoladamente sem o script completo

---

## 📁 Estrutura de Ficheiros

```
Menu_configurar_dc/
│
├── Infra_Principal.ps1      # Ponto de entrada — carrega todos os módulos
├── Infra_Utils.ps1          # Funções partilhadas + Assistente de Setup inicial
│
├── Modulo_AD.ps1            # Active Directory (OUs, Grupos, Utilizadores, GPOs)
├── Modulo_DNS.ps1           # DNS (Zonas, Registos A, CNAME)
├── Modulo_DHCP.ps1          # DHCP (Scope, Opções, Reservas)
├── Modulo_FileServer.ps1    # File Server (Partilhas SMB + Permissões NTFS)
└── Modulo_IIS.ps1           # IIS (Sites Web e Intranet)
```

---

## ⚙️ Pré-requisitos

| Requisito | Detalhe |
|---|---|
| Sistema Operativo | Windows Server 2025 (ou 2019/2022 com adaptações mínimas) |
| PowerShell | Versão 5.1 ou superior |
| Permissões | Administrador do domínio |
| Roles instaladas | AD DS, DNS Server, DHCP Server, File Server, IIS (Web Server) |
| Domínio | Domínio Active Directory já promovido antes de correr o script |

> ⚠️ **Importante:** O script deve ser executado com privilégios de Administrador. Caso contrário, termina automaticamente com uma mensagem de erro.

---

## 🚀 Como Usar

### Script Completo

Coloca todos os ficheiros `.ps1` na mesma pasta e executa:

```powershell
.\Infra_Principal.ps1
```

O assistente de configuração inicial é lançado automaticamente e pede os parâmetros da tua rede (domínio, IPs, pool DHCP, etc.) antes de abrir o menu principal.

---

### Módulo Isolado

Se precisares apenas de configurar um serviço específico (por exemplo só o DHCP):

```powershell
# Carrega as funções partilhadas
. .\Infra_Utils.ps1

# Carrega o módulo pretendido
. .\Modulo_DHCP.ps1

# Corre o setup para definir os parâmetros da rede
Configurar_Setup

# Abre o menu do módulo
Menu_DHCP
```

Funciona da mesma forma para qualquer outro módulo: `Menu_AD`, `Menu_DNS`, `Menu_FileServer`, `Menu_IIS`.

---

## 📦 Módulos

### 1️⃣ Active Directory (`Modulo_AD.ps1`)

| Função | Descrição |
|---|---|
| `AD_CriarOUs` | Cria as Unidades Organizacionais (Utilizadores, Grupos, Servidores, Computadores) |
| `AD_CriarGrupos` | Cria 6 grupos de segurança: GRP_RH, GRP_IT, GRP_Publico, GRP_Admins, GRP_WebAdmins, GRP_BackupOps |
| `AD_CriarUtilizadores` | Cria 7 contas pré-definidas com login gerado automaticamente (`nome.apelido`) |
| `AD_PoliticaPasswords` | Configura a política de passwords do domínio (comprimento, histórico, bloqueio, etc.) |
| `AD_CriarGPOs` | Cria e liga 3 GPOs: bloqueio de ecrã, desativação de AutoRun e aviso legal no login |

---

### 2️⃣ DNS (`Modulo_DNS.ps1`)

| Função | Descrição |
|---|---|
| `DNS_CriarZonas` | Cria a zona direta integrada no AD e a zona de pesquisa inversa |
| `DNS_CriarRegistos` | Adiciona registos A (dc, web, backup, dhcp, gateway) e CNAME (www, intranet, monitor) |
| `DNS_VerZonas` | Lista todas as zonas e registos existentes |

---

### 3️⃣ DHCP (`Modulo_DHCP.ps1`)

| Função | Descrição |
|---|---|
| `DHCP_Autorizar` | Autoriza o servidor DHCP no Active Directory |
| `DHCP_CriarScope` | Cria o scope com pool de IPs, intervalo de exclusão e opções (GW, DNS, domínio) |
| `DHCP_CriarReservas` | Adiciona reservas de IP por endereço MAC (número definido pelo utilizador) |
| `DHCP_VerEstado` | Mostra scopes, opções, reservas e leases ativos |

---

### 4️⃣ File Server (`Modulo_FileServer.ps1`)

| Função | Descrição |
|---|---|
| `FS_CriarPartilhas` | Cria pastas RH, IT e Publico com permissões NTFS por grupo e partilha SMB |
| `FS_VerPartilhas` | Lista partilhas ativas e respetivas permissões de acesso |

Permissões configuradas automaticamente:

| Partilha | GRP_RH | GRP_IT | GRP_Publico | GRP_Admins |
|---|---|---|---|---|
| RH | Modify | — | — | FullControl |
| IT | — | Modify | — | FullControl |
| Publico | Read | Modify | Modify | FullControl |

---

### 5️⃣ IIS (`Modulo_IIS.ps1`)

| Função | Descrição |
|---|---|
| `IIS_CriarSites` | Cria o site principal (`www.dominio`) e a Intranet (`intranet.dominio`) com páginas HTML geradas |
| `IIS_VerSites` | Lista os sites configurados e respetivos bindings |

---

## 🎨 Interface

O menu foi desenhado para funcionar com 80 colunas, usando caracteres Unicode de box-drawing para uma experiência visual limpa:

```
  ╔══════════════════════════════════════════════════════════════════════════════╗
  ║   SERVER   INFRAESTRUTURA  WINDOWS SERVER 2025                              ║
  ╠══════════════════════════════════════════════════════════════════════════════╣
  ║  Dom: grupo2.local   Rede: 192.168.0.0/24                                  ║
  ╠══════════════════════════════════════════════════════════════════════════════╣
  ║   >   MENU PRINCIPAL                                                        ║
  ╚══════════════════════════════════════════════════════════════════════════════╝

  ╔═══╦════════════════════════════════════════════════════════════════════════╗
  ║ 1 ║  Active Directory        OUs, Grupos, Utilizadores, GPOs              ║
  ╟---╫------------------------------------------------------------------------╢
  ║ 2 ║  DNS                     Zonas, Registos A, CNAME                     ║
  ╟---╫------------------------------------------------------------------------╢
  ║ 3 ║  DHCP                    Scope, Opcoes, Reservas                      ║
  ...
```

O sistema de logging usa badges coloridos na consola:

- ✅ `[ OK ]` — Verde — Operação concluída com sucesso
- ❌ `[ ER ]` — Vermelho — Erro durante a operação
- ⚠️ `[ AV ]` — Amarelo — Aviso (recurso já existe, etc.)
- ℹ️ `[ >> ]` — Ciano — Informação geral

---

## 📝 Log

Todas as operações são registadas num ficheiro de log configurável (por defeito `C:\Logs\Infra.log`) no formato:

```
[2025-04-24 14:32:01][OK] OU 'GRUPO2' criada.
[2025-04-24 14:32:02][OK] Grupo 'GRP_IT' criado.
[2025-04-24 14:32:03][AVISO] Utilizador 'admin.ti' ja existe.
[2025-04-24 14:32:05][ERRO] Erro zona directa: The zone already exists.
```

---

## 🤝 Contribuições

Contribuições são bem-vindas! Podes abrir uma *issue* para reportar bugs ou sugerir melhorias, ou submeter um *pull request* diretamente.

---

## 📄 Licença

Distribuído sob a licença MIT. Consulta o ficheiro `LICENSE` para mais detalhes.

---

<p align="center">
  Feito com ☕ e muitas horas de PowerShell
</p>
