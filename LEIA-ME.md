# Backup da personalizaÃ§Ã£o do shell

Backup da configuraÃ§Ã£o do terminal desta mÃ¡quina, feito para ser **levado para
outra mÃ¡quina Windows** e restaurado com um comando.

Origem: `C:\Users\USER` (Windows 11) â€” PowerShell 7.6.6, Windows Terminal 1.24,
WSL2, Git Bash, CMD via Clink.

---

## Como usar na outra mÃ¡quina

1. Copie esta pasta inteira para o novo PC (pendrive, OneDrive, rede â€” tanto faz).
2. Abra o **PowerShell 7** na nova mÃ¡quina.
3. Entre na pasta e rode:

   ```powershell
   cd <caminho>\powershell-setup-20261012-222119

   # primeiro, veja o que vai acontecer, sem alterar nada:
   pwsh -File ShellForge.ps1 -Simular

   # sÃ³ os arquivos de configuraÃ§Ã£o (nÃ£o instala nada):
   pwsh -File ShellForge.ps1 -SomenteConfig

   # instalaÃ§Ã£o completa (Scoop, mÃ³dulos, variÃ¡veis, registro):
   pwsh -File ShellForge.ps1
   ```

### PrÃ©-requisitos na mÃ¡quina nova

| Precisa | Como |
|---|---|
| **PowerShell 7** | `winget install Microsoft.PowerShell` ou pelo site da Microsoft |
| **Scoop** | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`<br>`Invoke-RestMethod -Uri https://get.scoop.sh \| Invoke-Expression` |
| **FiraCode Nerd Font** | <https://github.com/ryanoasis/nerd-fonts/releases> â†’ instalar **FiraCodeNerdFont-Regular.ttf** (duplo clique â†’ *Install for all users*) |
| **Windows Terminal** | vem no Windows 11; em versÃµes antigas, pela Store |
| **Git for Windows** | <https://git-scm.com/download/win> â€” fornece `bash.exe` e `less`, `tig`, `grep` |

> **A fonte Ã© obrigatÃ³ria.** Sem a FiraCode Nerd Font todos os Ã­cones do prompt
> viram quadradinhos. O script detecta e avisa, mas **nÃ£o baixa sozinho**.

---

## O que Ã© restaurado

### Arquivos

| Arquivo | Vai para |
|---|---|
| `pwsh-profile.ps1` | `%MyDocuments%\PowerShell\Microsoft.PowerShell_profile.ps1` |
| `powershell51-profile.ps1` | `%MyDocuments%\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |
| `USER.omp.json` | `%USERPROFILE%\.omp\` |
| `bashrc` | `%USERPROFILE%\.bashrc` |
| `bash_profile` | `%USERPROFILE%\.bash_profile` |
| `gitconfig` | `%USERPROFILE%\.gitconfig` |
| `settings-terminal.json` | `%LOCALAPPDATA%\Packages\...\LocalState\settings.json` |
| `clink_settings` | `%LOCALAPPDATA%\clink\clink_settings` |
| `wsl-Ubuntu.bashrc`, `wsl-OpenClawGateway.bashrc` | referÃªncia de como ficou cada distro |

### Registro e ambiente

- `HKCU\Software\Microsoft\Command Processor\AutoRun` â†’ `chcp 65001 && clink inject --autorun`
- `POSH_THEMES_PATH`, `CLINK_DIR`, `POWERSHELL_TELEMETRY_OPTOUT=1`
- entrada `scoop\shims` no PATH do usuÃ¡rio

### Ferramentas (listas, reinstaladas pelo script)

- **Scoop:** `listas/scoop-apps.txt` (oh-my-posh, clink, delta, lazygit, fzf, zoxide, jq, git, 7zip, ffmpeg, gradle, nodejs, openjdk21, â€¦)
- **Chocolatey:** `listas/choco-packages.txt` (VS Build Tools, Python, runtimes, KBs)
- **MÃ³dulos:** Terminal-Icons, Posh-Git, PSFzf

> O Chocolatey **nÃ£o** Ã© reinstalado automaticamente: exige administrador e
> baixa mais de 2 GB. Instale com `choco install <pacote> -y` se precisar.

### WSL

O script **nÃ£o reinstala as distros** (elas podem ter gigabytes). Ele apenas,
para cada distro que jÃ¡ existir na mÃ¡quina nova:

1. instala o `oh-my-posh` em `~/.local/bin` (se faltar)
2. baixa os 125 temas oficiais
3. grava `~/.omp/USER.omp.json`
4. acrescenta o bloco no `~/.bashrc` (com backup do original)
5. verifica que o prompt renderiza sem erro

O tema Ã© enviado em **base64**, nÃ£o por caminho `/mnt/...`, porque nem toda distro
monta os drives do Windows e no Linux `/mnt/d` â‰  `/mnt/D`.

---

## Detalhes que importam

### O caminho do *Documents* pode ser diferente

Nesta mÃ¡quina *Documents* estÃ¡ redirecionado para `D:\USER\Documents`. Na outra,
provavelmente serÃ¡ `C:\Users\<vocÃª>\Documents`. O script usa
`[Environment]::GetFolderPath('MyDocuments')`, entÃ£o acha o caminho certo sozinho.

**ConsequÃªncia prÃ¡tica:** se vocÃª editar os perfis em `C:\Users\USER\Documents\`
num PC onde o *Documents* estÃ¡ redirecionado, nada acontece. JÃ¡ erramos nisso.

### `gitconfig` traz identidade

O arquivo inclui `user.name`, `user.email` e `safe.directory` desta mÃ¡quina.
VocÃª pediu para incluir. Se na outra mÃ¡quina usar outra identidade:

```powershell
git config --global user.name  "Outro Nome"
git config --global user.email "outro@email.com"
```

O `core.editor` aponta para o caminho absoluto do VS Code desta mÃ¡quina
(`C:\Users\USER\AppData\Local\Programs\...`). Se na outra for diferente:

```powershell
git config --global core.editor "code --wait"
```

### `settings-terminal.json` tem GUIDs e caminhos fixos

- Os GUIDs dos perfis sÃ£o seus e serÃ£o preservados.
- O perfil **Git Bash** aponta para `C:\Program Files\Git\bin\bash.exe` â€” o mesmo
  caminho na maioria das mÃ¡quinas, mas confira se o seu Git foi instalado ali.
- Se o Windows Terminal nÃ£o aceitar o arquivo (por exemplo, se os perfis
  dinÃ¢micos mudarem de GUID), aplique manualmente: *ConfiguraÃ§Ãµes â†’ Abrir
  arquivo JSON* e cole o conteÃºdo de `arquivos/settings-terminal.json`.

### O script nunca sobrescreve Ã s cegas

Cada arquivo Ã© comparado por **SHA256** com o que jÃ¡ existe:

- idÃªntico â†’ deixa como estÃ¡
- diferente â†’ grava um `.bak.20261012-222119` do original e sÃ³ entÃ£o substitui

Pode rodar o `ShellForge.ps1` quantas vezes quiser.

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
   oh-my-posh print primary --config "$env:USERPROFILE\.omp\USER.omp.json"
   ```

---

## Reverter

Cada arquivo sobrescrito fica com sufixo `.bak.20261012-222119` no mesmo lugar.
Para desfazer, procure e renomeie de volta.

O tema anterior ao atual tambÃ©m estÃ¡ em
`%USERPROFILE%\.omp\USER.p10k-anterior.omp.json` nesta mÃ¡quina â€” **nÃ£o** veio
para o backup, porque jÃ¡ estava superado.

---

## InventÃ¡rio

```
powershell-setup-20261012-222119\
â”œâ”€â”€ LEIA-ME.md                  este arquivo
â”œâ”€â”€ ShellForge.ps1               script principal (Windows)
â”œâ”€â”€ arquivos\                   os arquivos de configuraÃ§Ã£o
â”œâ”€â”€ listas\                     inventÃ¡rio do que estÃ¡ instalado
â””â”€â”€ scripts\
    â””â”€â”€ restaurar-wsl.sh        usado pelo ShellForge.ps1 dentro de cada distro
```

*Gerado em 12/10/2026 Ã s 22:21.*
