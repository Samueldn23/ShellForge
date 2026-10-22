# ShellForge â€” Backup e restauraÃ§Ã£o da personalizaÃ§Ã£o do shell

Kit de backup/restauraÃ§Ã£o da personalizaÃ§Ã£o do terminal de uma mÃ¡quina
**Windows 11** â€” feito para ser **levado para outro PC** e reaplicado com um
comando. PowerShell 7, Windows PowerShell 5.1, Windows Terminal, WSL2,
Git Bash e CMD via Clink, todos com o prompt do Oh My Posh (o CMD usa o tema
empacotado; os demais, o tema `custom.omp.json` â€” veja abaixo).

> **NÃ£o Ã© uma aplicaÃ§Ã£o.** Este repo nÃ£o tem build, testes, dependÃªncias ou CI.
> A peÃ§a central Ã© o script `ShellForge.ps1`.

---

## Quick start

No **PowerShell 7** da mÃ¡quina nova, dentro da pasta do repo:

```powershell
# 1. veja o que vai acontecer, sem alterar nada:
pwsh -File ShellForge.ps1 -Simular

# 2. sÃ³ os arquivos de configuraÃ§Ã£o (nÃ£o instala Scoop, mÃ³dulos nem fonte):
pwsh -File ShellForge.ps1 -SomenteConfig

# 3. instalaÃ§Ã£o completa:
pwsh -File ShellForge.ps1
```

O script Ã© **idempotente**: pode ser rodado quantas vezes quiser. Nada Ã©
sobrescrito Ã s cegas â€” cada arquivo Ã© comparado por SHA256 e o original Ã©
guardado como `.bak.<aaaaMMdd-HHmmss>` antes de ser substituÃ­do.

Antes de instalar ferramentas, o script **verifica a conexÃ£o com a internet**
(github.com:443) e **pula o que jÃ¡ estiver instalado**. Cada execuÃ§Ã£o gera um
**log** em `%TEMP%\ShellForge-<data-hora>.log`.

### PrÃ©-requisitos na mÃ¡quina nova

| Precisa | Como |
|---|---|
| **PowerShell 7** | Instalado automaticamente via winget (`Microsoft.PowerShell`) se nÃ£o estiver presente |
| **Scoop** | O script tenta instalar automaticamente se faltar.<br>Manual: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`<br>`Invoke-RestMethod -Uri https://get.scoop.sh \| Invoke-Expression` |
| **Hack Nerd Font** | O script instala automaticamente as fontes de `arquivos/Hack/`. Manual: <https://github.com/ryanoasis/nerd-fonts/releases> â†’ **HackNerdFont-Regular.ttf** |
| **Windows Terminal** | vem no Windows 11; em versÃµes antigas, pela Store |
| **Git for Windows** | <https://git-scm.com/download/win> â€” fornece `bash.exe`, `less`, `tig`, `grep` |

> **A fonte Ã© obrigatÃ³ria.** Sem uma fonte Nerd (Hack) todos os Ã­cones do prompt
> viram quadradinhos. O script instala a Hack Nerd Font automaticamente.

---

## Como funciona

O ShellForge Ã© um kit de **backup e restauraÃ§Ã£o** da personalizaÃ§Ã£o do terminal.
Ele nÃ£o instala um aplicativo â€” ele **copia arquivos de configuraÃ§Ã£o e
reinstala ferramentas** de um backup para a mÃ¡quina atual.

### Fluxo de restauraÃ§Ã£o (`ShellForge.ps1`)

1. **VerificaÃ§Ã£o de ambiente** â€” confirma PowerShell 7+, verifica a
   `Execution Policy` do PowerShell (se estiver `Restricted`, explica como
   habilitar com `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`),
   testa conexÃ£o com a internet (github.com:443) e registra um log em
   `%TEMP%`.
2. **Ferramentas** â€” instala o Scoop (se faltar) e os apps de
   `listas/scoop-apps.txt` (oh-my-posh, clink, delta, lazygit, fzf, zoxide,
   jq, git, 7zip, ffmpeg, gradle, nodejs, openjdk21, opencode). Se o Scoop
   nÃ£o estiver disponÃ­vel, tenta via **winget**. Apps jÃ¡ instalados sÃ£o
   detectados pelo PATH e pulados.
3. **MÃ³dulos do PowerShell** â€” Terminal-Icons, Posh-Git, PSFzf (sÃ³ os que
   faltarem).
4. **Fonte Nerd** â€” instala a Hack Nerd Font por usuÃ¡rio (sem admin) a partir
   de `arquivos/Hack/`, se nÃ£o estiver instalada.
5. **Arquivos de configuraÃ§Ã£o** â€” copia perfis, `.bashrc`, `.gitconfig`,
   `custom.omp.json`, `clink_settings` e `settings-terminal.json` para seus
   destinos, com backup `.bak` se jÃ¡ existirem.
6. **Registro do CMD** â€” cria a chave `HKCU\Software\Microsoft\Command
   Processor` e grava o `AutoRun` do Clink (se instalado).
7. **VariÃ¡veis de ambiente** â€” ajusta `PATH`, `POSH_THEMES_PATH`, `CLINK_DIR`
   e `POWERSHELL_TELEMETRY_OPTOUT`.
8. **WSL** â€” para cada distro existente (listada em `listas/wsl-distros.txt`),
   instala o oh-my-posh (se faltar), baixa os temas, grava
   `~/.omp/custom.omp.json` e atualiza o `~/.bashrc` (com backup).

### Por que um arquivo de tema em base64 no WSL?
Nem toda distro WSL monta os drives do Windows (`/mnt/d`), e o Linux diferencia
maiÃºscula de minÃºscula (`/mnt/d` â‰  `/mnt/D`). Por isso o tema viaja como
base64 pelo argumento do script, e nÃ£o por caminho.

### IdempotÃªncia
O script compara SHA256 antes de copiar. Se o arquivo jÃ¡ estiver igual, nÃ£o
faz nada. Se for diferente, grava um `.bak.<aaaaMMdd-HHmmss>` do original e
sÃ³ entÃ£o substitui. Pode rodar quantas vezes quiser.

---

## O que Ã© restaurado

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
| `arquivos/wsl-*.bashrc` | referÃªncia de como ficou cada distro |

### Registro e ambiente

- `HKCU\Software\Microsoft\Command Processor\AutoRun` â†’ `chcp 65001 && clink inject --autorun`
- `HKCR\Directory\shell\PowerShell7` e `HKCR\Drive\shell\PowerShell7` â†’ menu de contexto "Abrir com PowerShell 7" (com Ã­cone do PowerShell 7)
- `POSH_THEMES_PATH`, `CLINK_DIR`, `POWERSHELL_TELEMETRY_OPTOUT=1`
- entrada `scoop\shims` no PATH do usuÃ¡rio
- `defaultProfile` do Windows Terminal â†’ GUID do PowerShell 7

### Ferramentas

- **Scoop** â€” `listas/scoop-apps.txt`: oh-my-posh, clink, delta, lazygit, fzf,
  zoxide, jq, git, 7zip, ffmpeg, gradle, nodejs, openjdk21, opencode, â€¦
  O script tenta instalar o **Scoop** automaticamente se faltar. Se a instalaÃ§Ã£o
  do Scoop falhar, ele tenta instalar os apps equivalentes via **winget**
  (gradle e openjdk21 nÃ£o tÃªm equivalente; o script indica o link manual).
  Antes de instalar qualquer app, o script **verifica se o comando jÃ¡ existe
  no PATH** e pula o que jÃ¡ estiver instalado.
- **Chocolatey** â€” `listas/choco-packages.txt`: VS Build Tools, Python, runtimes, KBs.
  **NÃ£o Ã© reinstalado pelo script**: exige administrador e baixa mais de 2 GB.
  Instale com `choco install <pacote> -y` se precisar.
- **MÃ³dulos do PowerShell** â€” Terminal-Icons, Posh-Git, PSFzf. O script sÃ³
  instala os que faltarem.
- **Fonte Hack Nerd Font** â€” instalada automaticamente a partir de `arquivos/Hack/`
  (por usuÃ¡rio, sem precisar de admin).

### WSL

O script **nÃ£o reinstala as distros** (elas podem ter gigabytes). Ele apenas,
para cada distro que jÃ¡ existir na mÃ¡quina nova:

1. instala o `oh-my-posh` em `~/.local/bin` (se faltar)
2. baixa os temas oficiais
3. grava `~/.omp/custom.omp.json`
4. acrescenta o bloco no `~/.bashrc` (com backup do original)
5. verifica que o prompt renderiza sem erro

O tema Ã© enviado em **base64**, nÃ£o por caminho `/mnt/...`, porque nem toda
distro monta os drives do Windows e no Linux `/mnt/d` â‰  `/mnt/D`.

---

## Detalhes que importam

### O caminho do *Documents* pode ser diferente

Na mÃ¡quina de origem o *Documents* estÃ¡ redirecionado para `D:\USER\Documents`.
O script usa `[Environment]::GetFolderPath('MyDocuments')`, entÃ£o acha o caminho
certo sozinho em qualquer mÃ¡quina.

**ConsequÃªncia prÃ¡tica:** num PC com o *Documents* redirecionado, editar os
perfis em `C:\Users\<usuÃ¡rio>\Documents\PowerShell\...` nÃ£o surte efeito nenhum.

### `gitconfig` traz identidade

Inclui `user.name`, `user.email` e `safe.directory` da mÃ¡quina de origem. Se na
outra mÃ¡quina usar outra identidade:

```powershell
git config --global user.name  "Outro Nome"
git config --global user.email "outro@email.com"
```

O `core.editor` aponta para o caminho absoluto do VS Code da mÃ¡quina de origem.
Se na outra for diferente:

```powershell
git config --global core.editor "code --wait"
```

### `settings-terminal.json` tem GUIDs e caminhos fixos

- Os GUIDs dos perfis sÃ£o da mÃ¡quina de origem e serÃ£o preservados.
- O perfil **Git Bash** aponta para `C:\Program Files\Git\bin\bash.exe` â€” o mesmo
  caminho na maioria das mÃ¡quinas, mas confira se o seu Git foi instalado ali.
- Se o Windows Terminal nÃ£o aceitar o arquivo (por exemplo, se os perfis
  dinÃ¢micos mudarem de GUID), aplique manualmente: *ConfiguraÃ§Ãµes â†’ Abrir
  arquivo JSON* e cole o conteÃºdo de `arquivos/settings-terminal.json`.

### Um tema, quatro shells

`custom.omp.json` Ã© usado pelo PowerShell 7, pelo Windows PowerShell 5.1, pelo
Git Bash e por ambas as distros WSL. JÃ¡ o `arquivos/clink_settings` ainda aponta
para o tema empacotado `powerlevel10k_rainbow.omp.json` â€” o CMD via Clink
**nÃ£o** segue o `custom.omp.json`. Editar o tema nÃ£o muda o CMD.

Para voltar ao tema empacotado do Scoop nos outros shells, troque a linha do
tema no perfil correspondente por:

```powershell
$OmpTheme = Join-Path $env:POSH_THEMES_PATH 'powerlevel10k_rainbow.omp.json'
```

### `-SomenteConfig` tambÃ©m mexe no WSL

Apesar do nome, o modo `-SomenteConfig` pula Scoop, mÃ³dulos e fonte, mas
**continua aplicando todas as distros WSL** â€” instalando o oh-my-posh dentro
delas. NÃ£o existe guarda para a etapa `[7/7]`.

---

## Depois de restaurar

1. **Abra um terminal novo.** PATH e variÃ¡veis de ambiente sÃ³ chegam a
   processos criados depois.
2. Confira a fonte nas configuraÃ§Ãµes do terminal.
3. Se o prompt aparecer sem Ã­cones, Ã© a fonte.
4. Se o CMD ficar sem prompt, o Clink nÃ£o injetou:

   ```cmd
   clink autorun install
   ```

5. Teste rÃ¡pido do tema:

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
â”œâ”€â”€ README.md                  este arquivo
â”œâ”€â”€ AGENTS.md                  instruÃ§Ãµes para agentes de IA
â”œâ”€â”€ ShellForge.ps1              script principal (Windows)
â”œâ”€â”€ arquivos/                  os arquivos de configuraÃ§Ã£o
â”œâ”€â”€ listas/                    inventÃ¡rio do que estÃ¡ instalado
â””â”€â”€ scripts/
    â””â”€â”€ restaurar-wsl.sh       usado pelo ShellForge.ps1 dentro de cada distro
```

> SÃ³ `listas/scoop-apps.txt` e `listas/wsl-distros.txt` sÃ£o lidos pelo script.
> Os outros arquivos de `listas/` e os `arquivos/wsl-*.bashrc` sÃ£o **sÃ³
> documentaÃ§Ã£o** â€” editÃ¡-los nÃ£o muda comportamento algum.
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

