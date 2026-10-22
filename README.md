# ShellForge — Backup e restauração da personalização do shell

Kit de backup/restauração da personalização do terminal de uma máquina
**Windows 11** — feito para ser **levado para outro PC** e reaplicado com um
comando. PowerShell 7, Windows PowerShell 5.1, Windows Terminal, WSL2,
Git Bash e CMD via Clink, todos com o prompt do Oh My Posh (o CMD usa o tema
empacotado; os demais, o tema `custom.omp.json` — veja abaixo).

> **Não é uma aplicação.** Este repo não tem build, testes, dependências ou CI.
> A peça central é o script `ShellForge.ps1`.

---

## Quick start

No **PowerShell 7** da máquina nova, dentro da pasta do repo:

```powershell
# 1. veja o que vai acontecer, sem alterar nada:
pwsh -File ShellForge.ps1 -Simular

# 2. só os arquivos de configuração (não instala Scoop, módulos nem fonte):
pwsh -File ShellForge.ps1 -SomenteConfig

# 3. instalação completa:
pwsh -File ShellForge.ps1
```

### Instalação com um comando (estilo `irm ... | iex`)

O repo é multi-arquivo (perfis, temas, fontes, listas, script WSL), então não
basta baixar só o `ShellForge.ps1`. O `install.ps1` do repo baixa o repositório
inteiro e executa o script:

Se rodado num terminal interativo sem parâmetros, o `install.ps1` (e o próprio
`ShellForge.ps1`) exibem um **menu** para escolher o modo (instalação completa,
só configuração, simulação ou sair). Em pipe/CI (entrada redirecionada) o menu
é pulado e roda a instalação completa.

```powershell
# instalação completa (modo padrão) - link curto:
irm https://is.gd/shellforge | iex

# link completo (caso o encurtador esteja indisponível):
irm https://raw.githubusercontent.com/Samueldn23/ShellForge/main/install.ps1 | iex

# dry-run (nada é alterado):
& ([ScriptBlock]::Create((irm https://is.gd/shellforge))) -Simular

# só arquivos de configuração:
& ([ScriptBlock]::Create((irm https://is.gd/shellforge))) -SomenteConfig
```

> **Segurança:** `irm ... | iex` executa código baixado da internet. Revise o
> `install.ps1` antes de rodar. O script é idempotente e grava `.bak` dos
> arquivos originais.

O script é **idempotente**: pode ser rodado quantas vezes quiser. Nada é
sobrescrito às cegas — cada arquivo é comparado por SHA256 e o original é
guardado como `.bak.<aaaaMMdd-HHmmss>` antes de ser substituído.

Antes de instalar ferramentas, o script **verifica a conexão com a internet**
(github.com:443) e **pula o que já estiver instalado**. Cada execução gera um
**log** em `%TEMP%\ShellForge-<data-hora>.log`.

### Pré-requisitos na máquina nova

| Precisa | Como |
|---|---|
| **PowerShell 7** | Instalado automaticamente via winget (`Microsoft.PowerShell`) se não estiver presente |
| **Scoop** | O script tenta instalar automaticamente se faltar.<br>Manual: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`<br>`Invoke-RestMethod -Uri https://get.scoop.sh \| Invoke-Expression` |
| **Hack Nerd Font** | O script instala automaticamente as fontes de `arquivos/Hack/`. Manual: <https://github.com/ryanoasis/nerd-fonts/releases> → **HackNerdFont-Regular.ttf** |
| **Windows Terminal** | vem no Windows 11; em versões antigas, pela Store |
| **Git for Windows** | <https://git-scm.com/download/win> — fornece `bash.exe`, `less`, `tig`, `grep` |

> **A fonte é obrigatória.** Sem uma fonte Nerd (Hack) todos os ícones do prompt
> viram quadradinhos. O script instala a Hack Nerd Font automaticamente.

---

## Como funciona

O ShellForge é um kit de **backup e restauração** da personalização do terminal.
Ele não instala um aplicativo — ele **copia arquivos de configuração e
reinstala ferramentas** de um backup para a máquina atual.

### Fluxo de restauração (`ShellForge.ps1`)

1. **Verificação de ambiente** — confirma PowerShell 7+, verifica a
   `Execution Policy` do PowerShell (se estiver `Restricted`, explica como
   habilitar com `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`),
   testa conexão com a internet (github.com:443) e registra um log em
   `%TEMP%`.
2. **Ferramentas** — instala o Scoop (se faltar) e os apps de
   `listas/scoop-apps.txt` (oh-my-posh, clink, delta, lazygit, fzf, zoxide,
   jq, git, 7zip, ffmpeg, gradle, nodejs, openjdk21, opencode). Se o Scoop
   não estiver disponível, tenta via **winget**. Apps já instalados são
   detectados pelo PATH e pulados.
3. **Módulos do PowerShell** — Terminal-Icons, Posh-Git, PSFzf (só os que
   faltarem).
4. **Fonte Nerd** — instala a Hack Nerd Font por usuário (sem admin) a partir
   de `arquivos/Hack/`, se não estiver instalada.
5. **Arquivos de configuração** — copia perfis, `.bashrc`, `.gitconfig`,
   `custom.omp.json`, `clink_settings` e `settings-terminal.json` para seus
   destinos, com backup `.bak` se já existirem.
6. **Registro do CMD** — cria a chave `HKCU\Software\Microsoft\Command
   Processor` e grava o `AutoRun` do Clink (se instalado).
7. **Variáveis de ambiente** — ajusta `PATH`, `POSH_THEMES_PATH`, `CLINK_DIR`
   e `POWERSHELL_TELEMETRY_OPTOUT`.
8. **WSL** — para cada distro existente (listada em `listas/wsl-distros.txt`),
   instala o oh-my-posh (se faltar), baixa os temas, grava
   `~/.omp/custom.omp.json` e atualiza o `~/.bashrc` (com backup).

### Por que um arquivo de tema em base64 no WSL?
Nem toda distro WSL monta os drives do Windows (`/mnt/d`), e o Linux diferencia
maiúscula de minúscula (`/mnt/d` ≠ `/mnt/D`). Por isso o tema viaja como
base64 pelo argumento do script, e não por caminho.

### Idempotência
O script compara SHA256 antes de copiar. Se o arquivo já estiver igual, não
faz nada. Se for diferente, grava um `.bak.<aaaaMMdd-HHmmss>` do original e
só então substitui. Pode rodar quantas vezes quiser.

---

## O que é restaurado

### Arquivos

| Arquivo | Vai para |
|---|---|
| `arquivos/pwsh-profile.ps1` | `%MyDocuments%\PowerShell\Microsoft.PowerShell_profile.ps1` |
| `arquivos/powershell51-profile.ps1` | `%MyDocuments%\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |
| `arquivos/custom.omp.json` | `%USERPROFILE%\.omp\` |
| `arquivos/bashrc` | `%USERPROFILE%\.bashrc` |
| `arquivos/bash_profile` | `%USERPROFILE%\.bash_profile` |
| `arquivos/gitconfig` | `%USERPROFILE%\.gitconfig` |
| `arquivos/settings-terminal.json` | `%LOCALAPPDATA%\Packages\...\LocalState\settings.json` |
| `arquivos/clink_settings` | `%LOCALAPPDATA%\clink\clink_settings` |
| `arquivos/wsl-*.bashrc` | referência de como ficou cada distro |

### Registro e ambiente

- `HKCU\Software\Microsoft\Command Processor\AutoRun` → `chcp 65001 && clink inject --autorun`
- `HKCR\Directory\shell\PowerShell7` e `HKCR\Drive\shell\PowerShell7` → menu de contexto "Abrir com PowerShell 7" (com ícone do PowerShell 7)
- `POSH_THEMES_PATH`, `CLINK_DIR`, `POWERSHELL_TELEMETRY_OPTOUT=1`
- entrada `scoop\shims` no PATH do usuário
- `defaultProfile` do Windows Terminal → GUID do PowerShell 7

### Ferramentas

- **Scoop** — `listas/scoop-apps.txt`: oh-my-posh, clink, delta, lazygit, fzf,
  zoxide, jq, git, 7zip, ffmpeg, gradle, nodejs, openjdk21, opencode, …
  O script tenta instalar o **Scoop** automaticamente se faltar. Se a instalação
  do Scoop falhar, ele tenta instalar os apps equivalentes via **winget**
  (gradle e openjdk21 não têm equivalente; o script indica o link manual).
  Antes de instalar qualquer app, o script **verifica se o comando já existe
  no PATH** e pula o que já estiver instalado.
- **Chocolatey** — `listas/choco-packages.txt`: VS Build Tools, Python, runtimes, KBs.
  **Não é reinstalado pelo script**: exige administrador e baixa mais de 2 GB.
  Instale com `choco install <pacote> -y` se precisar.
- **Módulos do PowerShell** — Terminal-Icons, Posh-Git, PSFzf. O script só
  instala os que faltarem.
- **Fonte Hack Nerd Font** — instalada automaticamente a partir de `arquivos/Hack/`
  (por usuário, sem precisar de admin).

### WSL

O script **não reinstala as distros** (elas podem ter gigabytes). Ele apenas,
para cada distro que já existir na máquina nova:

1. instala o `oh-my-posh` em `~/.local/bin` (se faltar)
2. baixa os temas oficiais
3. grava `~/.omp/custom.omp.json`
4. acrescenta o bloco no `~/.bashrc` (com backup do original)
5. verifica que o prompt renderiza sem erro

O tema é enviado em **base64**, não por caminho `/mnt/...`, porque nem toda
distro monta os drives do Windows e no Linux `/mnt/d` ≠ `/mnt/D`.

---

## Detalhes que importam

### O caminho do *Documents* pode ser diferente

Na máquina de origem o *Documents* está redirecionado para `D:\USER\Documents`.
O script usa `[Environment]::GetFolderPath('MyDocuments')`, então acha o caminho
certo sozinho em qualquer máquina.

**Consequência prática:** num PC com o *Documents* redirecionado, editar os
perfis em `C:\Users\<usuário>\Documents\PowerShell\...` não surte efeito nenhum.

### `gitconfig` traz identidade

Inclui `user.name`, `user.email` e `safe.directory` da máquina de origem. Se na
outra máquina usar outra identidade:

```powershell
git config --global user.name  "Outro Nome"
git config --global user.email "outro@email.com"
```

O `core.editor` aponta para o caminho absoluto do VS Code da máquina de origem.
Se na outra for diferente:

```powershell
git config --global core.editor "code --wait"
```

### `settings-terminal.json` tem GUIDs e caminhos fixos

- Os GUIDs dos perfis são da máquina de origem e serão preservados.
- O perfil **Git Bash** aponta para `C:\Program Files\Git\bin\bash.exe` — o mesmo
  caminho na maioria das máquinas, mas confira se o seu Git foi instalado ali.
- Se o Windows Terminal não aceitar o arquivo (por exemplo, se os perfis
  dinâmicos mudarem de GUID), aplique manualmente: *Configurações → Abrir
  arquivo JSON* e cole o conteúdo de `arquivos/settings-terminal.json`.

### Um tema, quatro shells

`custom.omp.json` é usado pelo PowerShell 7, pelo Windows PowerShell 5.1, pelo
Git Bash e por ambas as distros WSL. Já o `arquivos/clink_settings` ainda aponta
para o tema empacotado `powerlevel10k_rainbow.omp.json` — o CMD via Clink
**não** segue o `custom.omp.json`. Editar o tema não muda o CMD.

Para voltar ao tema empacotado do Scoop nos outros shells, troque a linha do
tema no perfil correspondente por:

```powershell
$OmpTheme = Join-Path $env:POSH_THEMES_PATH 'powerlevel10k_rainbow.omp.json'
```

### `-SomenteConfig` também mexe no WSL

Apesar do nome, o modo `-SomenteConfig` pula Scoop, módulos e fonte, mas
**continua aplicando todas as distros WSL** — instalando o oh-my-posh dentro
delas. Não existe guarda para a etapa `[7/7]`.

---

## Depois de restaurar

1. **Abra um terminal novo.** PATH e variáveis de ambiente só chegam a
   processos criados depois.
2. Confira a fonte nas configurações do terminal.
3. Se o prompt aparecer sem ícones, é a fonte.
4. Se o CMD ficar sem prompt, o Clink não injetou:

   ```cmd
   clink autorun install
   ```

5. Teste rápido do tema:

   ```powershell
   oh-my-posh print primary --config "$env:USERPROFILE\.omp\custom.omp.json"
   ```

## Reverter

Cada arquivo sobrescrito fica com sufixo `.bak.<aaaaMMdd-HHmmss>` no mesmo lugar.
Para desfazer, procure e renomeie de volta.

---

## Estrutura

```
ShellForge/
├── README.md                  este arquivo
├── AGENTS.md                  instruções para agentes de IA
├── ShellForge.ps1              script principal (Windows)
├── arquivos/                  os arquivos de configuração
├── listas/                    inventário do que está instalado
└── scripts/
    └── restaurar-wsl.sh       usado pelo ShellForge.ps1 dentro de cada distro
```

> Só `listas/scoop-apps.txt` e `listas/wsl-distros.txt` são lidos pelo script.
> Os outros arquivos de `listas/` e os `arquivos/wsl-*.bashrc` são **só
> documentação** — editá-los não muda comportamento algum.

---

## English

### Objective

**ShellForge** is a backup and restore kit for terminal/shell personalization on
Windows 11. It is not an application - it is a set of configuration files plus a
PowerShell script that reapplies them on another machine.

It restores:
- **PowerShell 7** and **Windows PowerShell 5.1** profiles (with Oh My Posh)
- **Git Bash** (`.bashrc`, `.bash_profile`)
- **WSL** (Ubuntu, OpenClawGateway): Oh My Posh + theme
- **CMD via Clink**: prompt customization
- **Windows Terminal**: settings, font, profiles
- **Git**: global config, safe directories
- **Tools**: Scoop, Oh My Posh, Clink, delta, lazygit, fzf, zoxide, jq, git,
  7zip, ffmpeg, gradle, nodejs, openjdk21, opencode
- **Modules**: Terminal-Icons, Posh-Git, PSFzf
- **Font**: Hack Nerd Font (installed per-user, no admin required)
- **Environment variables**: PATH, POSH_THEMES_PATH, CLINK_DIR, etc.

### How it works

1. **Environment check**: confirms PowerShell 7+, checks PowerShell
   `Execution Policy` (if `Restricted`, explains how to enable with
   `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`),
   tests internet connectivity (github.com:443), and starts a log file in
   `%TEMP%`.
2. **Tools**: installs Scoop if missing (renaming any partial installation to
   a backup), then installs each app from `listas/scoop-apps.txt`. Already
   installed apps (detected via PATH) are skipped. If Scoop is unavailable,
   falls back to **winget**.
3. **Modules**: installs only missing PowerShell modules.
4. **Font**: installs Hack Nerd Font per-user from `arquivos/Hack/` if not
   present.
5. **Config files**: copies profiles, `.bashrc`, `.gitconfig`,
   `custom.omp.json`, `clink_settings` and `settings-terminal.json` to their
   destinations, with `.bak` backup if they already exist.
6. **CMD registry**: creates `HKCU\Software\Microsoft\Command Processor` and
   sets the Clink `AutoRun` value.
7. **Environment**: adjusts `PATH`, `POSH_THEMES_PATH`, `CLINK_DIR` and
   `POWERSHELL_TELEMETRY_OPTOUT`.
8. **WSL**: for each existing distro listed in `listas/wsl-distros.txt`,
   installs Oh My Posh if missing, downloads official themes, writes
   `~/.omp/custom.omp.json` and updates `~/.bashrc` (with backup).
9. **PowerShell 7 as default**: sets PowerShell 7 as default profile in
   Windows Terminal and adds "Abrir com PowerShell 7" to the right-click
   context menu of folders and drives in Windows Explorer.

The theme is sent to WSL as **base64** because not every distro mounts Windows
drives (`/mnt/d`), and Linux is case-sensitive (`/mnt/d` is not `/mnt/D`).

### Installation

#### Prerequisites
- **PowerShell 7**: installed automatically via winget (`Microsoft.PowerShell`) if not present
- **Windows Terminal**: included in Windows 11
- **Git for Windows**: <https://git-scm.com/download/win>

#### Quick start
```powershell
# 1. Preview what will happen (no changes):
pwsh -File ShellForge.ps1 -Simular

# 2. Config files only (no tools/modules/font):
pwsh -File ShellForge.ps1 -SomenteConfig

# 3. Full install:
pwsh -File ShellForge.ps1
```

The script is **idempotent**: it compares SHA256 before copying. If a file
already matches, it does nothing. If it differs, it saves a
`.bak.<aaaaMMdd-HHmmss>` copy of the original before replacing it.

### Reverting
Every overwritten file keeps a `.bak.<aaaaMMdd-HHmmss>` suffix in the same
location. To undo, find and rename those files back.

### Structure
```
ShellForge/
+-- README.md                  this file (PT-BR + EN)
+-- AGENTS.md                  instructions for AI agents
+-- ShellForge.ps1              main script (Windows)
+-- arquivos/                  configuration payload
+-- listas/                    inventory (only scoop-apps.txt and wsl-distros.txt are read)
+-- scripts/
    +-- restaurar-wsl.sh       runs inside each WSL distro
```

> Only `listas/scoop-apps.txt` and `listas/wsl-distros.txt` are read by the
> script. The other files in `listas/` and `arquivos/wsl-*.bashrc` are
> documentation only.

