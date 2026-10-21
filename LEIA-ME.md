# Backup da personalização do shell

Backup da configuração do terminal desta máquina, feito para ser **levado para
outra máquina Windows** e restaurado com um comando.

Origem: `C:\Users\USER` (Windows 11) — PowerShell 7.6.6, Windows Terminal 1.24,
WSL2, Git Bash, CMD via Clink.

---

## Como usar na outra máquina

1. Copie esta pasta inteira para o novo PC (pendrive, OneDrive, rede — tanto faz).
2. Abra o **PowerShell 7** na nova máquina.
3. Entre na pasta e rode:

   ```powershell
   cd <caminho>\powershell-setup-20261012-222119

   # primeiro, veja o que vai acontecer, sem alterar nada:
   pwsh -File restaurar.ps1 -Simular

   # só os arquivos de configuração (não instala nada):
   pwsh -File restaurar.ps1 -SomenteConfig

   # instalação completa (Scoop, módulos, variáveis, registro):
   pwsh -File restaurar.ps1
   ```

### Pré-requisitos na máquina nova

| Precisa | Como |
|---|---|
| **PowerShell 7** | `winget install Microsoft.PowerShell` ou pelo site da Microsoft |
| **Scoop** | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`<br>`Invoke-RestMethod -Uri https://get.scoop.sh \| Invoke-Expression` |
| **FiraCode Nerd Font** | <https://github.com/ryanoasis/nerd-fonts/releases> → instalar **FiraCodeNerdFont-Regular.ttf** (duplo clique → *Install for all users*) |
| **Windows Terminal** | vem no Windows 11; em versões antigas, pela Store |
| **Git for Windows** | <https://git-scm.com/download/win> — fornece `bash.exe` e `less`, `tig`, `grep` |

> **A fonte é obrigatória.** Sem a FiraCode Nerd Font todos os ícones do prompt
> viram quadradinhos. O script detecta e avisa, mas **não baixa sozinho**.

---

## O que é restaurado

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
| `wsl-Ubuntu.bashrc`, `wsl-OpenClawGateway.bashrc` | referência de como ficou cada distro |

### Registro e ambiente

- `HKCU\Software\Microsoft\Command Processor\AutoRun` → `chcp 65001 && clink inject --autorun`
- `POSH_THEMES_PATH`, `CLINK_DIR`, `POWERSHELL_TELEMETRY_OPTOUT=1`
- entrada `scoop\shims` no PATH do usuário

### Ferramentas (listas, reinstaladas pelo script)

- **Scoop:** `listas/scoop-apps.txt` (oh-my-posh, clink, delta, lazygit, fzf, zoxide, jq, git, 7zip, ffmpeg, gradle, nodejs, openjdk21, …)
- **Chocolatey:** `listas/choco-packages.txt` (VS Build Tools, Python, runtimes, KBs)
- **Módulos:** Terminal-Icons, Posh-Git, PSFzf

> O Chocolatey **não** é reinstalado automaticamente: exige administrador e
> baixa mais de 2 GB. Instale com `choco install <pacote> -y` se precisar.

### WSL

O script **não reinstala as distros** (elas podem ter gigabytes). Ele apenas,
para cada distro que já existir na máquina nova:

1. instala o `oh-my-posh` em `~/.local/bin` (se faltar)
2. baixa os 125 temas oficiais
3. grava `~/.omp/USER.omp.json`
4. acrescenta o bloco no `~/.bashrc` (com backup do original)
5. verifica que o prompt renderiza sem erro

O tema é enviado em **base64**, não por caminho `/mnt/...`, porque nem toda distro
monta os drives do Windows e no Linux `/mnt/d` ≠ `/mnt/D`.

---

## Detalhes que importam

### O caminho do *Documents* pode ser diferente

Nesta máquina *Documents* está redirecionado para `D:\USER\Documents`. Na outra,
provavelmente será `C:\Users\<você>\Documents`. O script usa
`[Environment]::GetFolderPath('MyDocuments')`, então acha o caminho certo sozinho.

**Consequência prática:** se você editar os perfis em `C:\Users\USER\Documents\`
num PC onde o *Documents* está redirecionado, nada acontece. Já erramos nisso.

### `gitconfig` traz identidade

O arquivo inclui `user.name`, `user.email` e `safe.directory` desta máquina.
Você pediu para incluir. Se na outra máquina usar outra identidade:

```powershell
git config --global user.name  "Outro Nome"
git config --global user.email "outro@email.com"
```

O `core.editor` aponta para o caminho absoluto do VS Code desta máquina
(`C:\Users\USER\AppData\Local\Programs\...`). Se na outra for diferente:

```powershell
git config --global core.editor "code --wait"
```

### `settings-terminal.json` tem GUIDs e caminhos fixos

- Os GUIDs dos perfis são seus e serão preservados.
- O perfil **Git Bash** aponta para `C:\Program Files\Git\bin\bash.exe` — o mesmo
  caminho na maioria das máquinas, mas confira se o seu Git foi instalado ali.
- Se o Windows Terminal não aceitar o arquivo (por exemplo, se os perfis
  dinâmicos mudarem de GUID), aplique manualmente: *Configurações → Abrir
  arquivo JSON* e cole o conteúdo de `arquivos/settings-terminal.json`.

### O script nunca sobrescreve às cegas

Cada arquivo é comparado por **SHA256** com o que já existe:

- idêntico → deixa como está
- diferente → grava um `.bak.20261012-222119` do original e só então substitui

Pode rodar o `restaurar.ps1` quantas vezes quiser.

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
   oh-my-posh print primary --config "$env:USERPROFILE\.omp\USER.omp.json"
   ```

---

## Reverter

Cada arquivo sobrescrito fica com sufixo `.bak.20261012-222119` no mesmo lugar.
Para desfazer, procure e renomeie de volta.

O tema anterior ao atual também está em
`%USERPROFILE%\.omp\USER.p10k-anterior.omp.json` nesta máquina — **não** veio
para o backup, porque já estava superado.

---

## Inventário

```
powershell-setup-20261012-222119\
├── LEIA-ME.md                  este arquivo
├── restaurar.ps1               script principal (Windows)
├── arquivos\                   os arquivos de configuração
├── listas\                     inventário do que está instalado
└── scripts\
    └── restaurar-wsl.sh        usado pelo restaurar.ps1 dentro de cada distro
```

*Gerado em 12/10/2026 às 22:21.*