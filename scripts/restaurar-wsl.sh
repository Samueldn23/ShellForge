#!/usr/bin/env bash
# ===========================================================================
#  restaurar-wsl.sh -- instala o Oh My Posh dentro de uma distro WSL
#
#  Uso:
#     bash restaurar-wsl.sh <tema-em-base64>
#
#  O tema chega como BASE64 pelo primeiro argumento, e nao como caminho.
#  Motivo: nem toda distro tem os drives do Windows montados em /mnt
#  (a OpenClawGateway deste PC, por exemplo, nao monta nenhum), e o Linux
#  diferencia maiuscula de minuscula em caminhos (/mnt/d != /mnt/D).
#
#  Para chamar de dentro do Windows:
#     $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes('custom.omp.json'))
#     Get-Content $script -Raw | wsl.exe -d Ubuntu -e bash -s -- $b64
# ===========================================================================
set -uo pipefail

TEMA_B64="${1:-}"

if [ -z "$TEMA_B64" ]; then
    echo "Uso: bash restaurar-wsl.sh <tema-em-base64>" >&2
    exit 1
fi

echo "usuario : $(whoami)"
echo "home    : $HOME"

# o .bashrc normalmente ja exporta esse PATH, mas este script roda num shell
# NAO interativo (stdin), entao precisa Garantir o caminho antes de testar
export PATH="$HOME/.local/bin:$PATH"

# --- 1. tema ------------------------------------------------------------------
mkdir -p "$HOME/.omp"
if printf '%s' "$TEMA_B64" | base64 -d > "$HOME/.omp/custom.omp.json" 2>/dev/null; then
    if [ -s "$HOME/.omp/custom.omp.json" ]; then
        echo "tema copiado para $HOME/.omp/custom.omp.json ($(stat -c%s "$HOME/.omp/custom.omp.json") bytes)"
    else
        echo "ERRO: o base64 decodificou para um arquivo vazio"
        exit 1
    fi
else
    echo "ERRO: nao consegui decodificar o base64 do tema"
    exit 1
fi

# --- 2. binario ---------------------------------------------------------------
if ! command -v oh-my-posh >/dev/null 2>&1; then
    echo "-- instalando oh-my-posh --"
    BIN="$HOME/.local/bin"
    mkdir -p "$BIN"
    VER="v31.8.0"
    if command -v unzip >/dev/null 2>&1; then
        curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$BIN"
    else
        # install.sh exige unzip; baixamos direto do GitHub (funciona sem unzip)
        curl -fsSL "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/$VER/posh-linux-amd64" \
             -o "$BIN/oh-my-posh"
        chmod +x "$BIN/oh-my-posh"
    fi
    export PATH="$BIN:$PATH"
    echo "   instalado: $(oh-my-posh version 2>&1)"
else
    echo "oh-my-posh ja instalado: $(oh-my-posh version 2>&1)"
fi

# --- 3. temas empacotados ------------------------------------------------------
THEMES="$HOME/.local/share/oh-my-posh/themes"
if [ ! -d "$THEMES" ] || [ -z "$(ls -A "$THEMES" 2>/dev/null)" ]; then
    echo "-- baixando os temas --"
    mkdir -p "$THEMES"
    TMP="$(mktemp)"
    curl -fsSL "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v31.8.0/themes.zip" -o "$TMP"
    if command -v unzip >/dev/null 2>&1; then
        unzip -oq "$TMP" -d "$THEMES"
    else
        python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$TMP" "$THEMES"
    fi
    rm -f "$TMP"
    echo "   $(ls "$THEMES" | wc -l) temas"
fi

# --- 4. .bashrc -----------------------------------------------------------------
RC="$HOME/.bashrc"
MARKER="# >>> oh-my-posh >>>"

if ! grep -qF "$MARKER" "$RC" 2>/dev/null; then
    [ -f "$RC" ] || touch "$RC"
    cp "$RC" "$RC.bak.$(date +%Y%m%d-%H%M%S)"
    cat >> "$RC" <<'OMP_EOF'

# >>> oh-my-posh >>>
# Binario : ~/.local/bin/oh-my-posh     (atualize com: oh-my-posh upgrade)
# Temas   : ~/.local/share/oh-my-posh/themes/
# Tema    : ~/.omp/custom.omp.json
export PATH="$HOME/.local/bin:$PATH"

if command -v oh-my-posh >/dev/null 2>&1; then
    eval "$(oh-my-posh init bash --config "$HOME/.omp/custom.omp.json" --strict)"
fi
# <<< oh-my-posh <<<
OMP_EOF
    echo ".bashrc atualizado (backup criado)"
else
    sed -i 's#^eval "$(oh-my-posh init bash --config "\$HOME/[^"]*\.omp\.json" --strict)"#eval "$(oh-my-posh init bash --config "$HOME/.omp/custom.omp.json" --strict)"#' "$RC"
    echo ".bashrc ja tinha o bloco; caminho normalizado"
fi

# --- 5. verificacao --------------------------------------------------------------
echo ""
echo "-- verificacao --"
export PATH="$HOME/.local/bin:$PATH"
SAIDA="$(oh-my-posh print primary --config "$HOME/.omp/custom.omp.json" 2>&1)"
if printf '%s' "$SAIDA" | grep -q "unable to create text"; then
    echo "FALHA: algum segmento do tema tem template invalido"
    printf '%s\n' "$SAIDA" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | head -5
    exit 1
fi
echo "tema renderiza sem erro"
bash -ic 'echo "POSH_CONFIG=$POSH_CONFIG"' 2>/dev/null | grep POSH_CONFIG || true
echo "OK"