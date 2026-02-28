#!/bin/bash
#
# ==============================================================================
# SCRIPT: versions.sh
# DESCRIÇÃO: Valida se a versão definida no Dockerfile corresponde à versão
#            centralizada no arquivo versions.env.
# AUTOR: Julian de Almeida Santos
# DATA: 2025-10-12
# USO: ./scripts/validation/versions.sh [--fix]
# ==============================================================================

# --- Configuração de Robustez (Boas Práticas Bash) ---
set -euo pipefail

# ----------------------------------------------------
#   SEÇÃO 1: DEFINICAO DE FUNCOES AUXILIARES
# ----------------------------------------------------

    print_success() {
        echo "✅ $1"
    }

    print_error() {
        echo "❌ $1" >&2
    }

    print_warning() {
        echo "⚠️ $1"
    }

    print_info() {
        echo "🔍 $1"
    }

    print_plain() {
        echo "$1"
    }

# ----------------------------------------------------
#   SEÇÃO 2: PARSE DE ARGUMENTOS
# ----------------------------------------------------

    AUTO_FIX=false

    if [[ "${1:-}" == "--fix" ]]; then
        AUTO_FIX=true
    fi

# ----------------------------------------------------
#   SEÇÃO 3: CARREGAMENTO DE CONFIGURAÇÕES
# ----------------------------------------------------

    if [ -f "versions.env" ]; then
        source "versions.env"
    elif [ -f "../../versions.env" ]; then
        source "../../versions.env"
        cd ../..
    else
        print_error "Arquivo 'versions.env' não encontrado."
        exit 1
    fi

# ----------------------------------------------------
#   SEÇÃO 4: VALIDAÇÃO DE VERSÃO
# ----------------------------------------------------

    DOCKERFILE="./Dockerfile"

    if [ ! -f "$DOCKERFILE" ]; then
        print_warning "Dockerfile não encontrado. Pulando validação."
        exit 0
    fi

    print_info "Iniciando validação de versões..."
    print_plain "-----------------------------------"

    # Extrai versão atual do Dockerfile
    ACTUAL_VERSION=$(grep -iE "LABEL release=" "$DOCKERFILE" | head -n 1 | cut -d'=' -f2 | tr -d '"' | tr -d "[:space:]")
    EXPECTED_VERSION="${APPSERVER_VERSION}"

    if [ "$ACTUAL_VERSION" != "$EXPECTED_VERSION" ]; then
        if [ "$AUTO_FIX" = true ]; then
            print_info "Corrigindo: $ACTUAL_VERSION -> $EXPECTED_VERSION"
            
            sed -i "s/LABEL release=\"$ACTUAL_VERSION\"/LABEL release=\"$EXPECTED_VERSION\"/" "$DOCKERFILE"
            
            # Verifica se deu certo
            NEW_VERSION=$(grep -iE "LABEL release=" "$DOCKERFILE" | head -n 1 | cut -d'=' -f2 | tr -d '"' | tr -d "[:space:]")
            if [ "$NEW_VERSION" == "$EXPECTED_VERSION" ]; then
                print_success "Versão corrigida com sucesso."
            else
                print_error "Falha ao corrigir versão."
                exit 1
            fi
        else
            print_error "Versão no Dockerfile ($ACTUAL_VERSION) difere de versions.env ($EXPECTED_VERSION)"
            print_plain "-----------------------------------"
            print_info "Dica: Execute './scripts/validation/versions.sh --fix' para corrigir automaticamente."
            exit 1
        fi
    else
        print_success "Versão correta ($EXPECTED_VERSION)"
    fi

    print_plain "-----------------------------------"
    print_success "Validação concluída."
