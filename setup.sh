#!/usr/bin/env bash
#
# ==============================================================================
# SCRIPT: setup.sh
# DESCRIÇÃO:
#   Automatiza o download, montagem e instalação dos pacotes do projeto
#   TOTVS-Protheus-in-Docker-AppServer a partir do GitHub.
#
# USO:
#   ./scripts/build/setup.sh
#
# REQUISITOS:
#   - curl
#   - jq
#   - tar
# ==============================================================================

set -euo pipefail

# ==============================================================================
# UTILITÁRIOS DE LOG
# ==============================================================================

log_info()    { echo -e "ℹ️  $1"; }
log_success() { echo -e "✅ $1"; }
log_warn()    { echo -e "⚠️  $1"; }
log_error()   { echo -e "❌ $1"; }

# ==============================================================================
# VALIDAÇÃO DE DEPENDÊNCIAS
# ==============================================================================

check_dependencies() {
    local dependencies=("curl" "jq" "tar")

    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Dependência não encontrada: $cmd"
            exit 1
        fi
    done

    log_success "Dependências verificadas com sucesso."
}

# ==============================================================================
# CARREGA CONFIGURAÇÕES
# ==============================================================================

load_versions_file() {
    if [[ -f "versions.env" ]]; then
        source "versions.env"
    else
        log_error "Arquivo 'versions.env' não encontrado."
        exit 1
    fi
}

# ==============================================================================
# CONFIGURAÇÕES GLOBAIS
# ==============================================================================


load_versions_file

GH_OWNER="juliansantosinfo"
GH_REPO="TOTVS-Protheus-in-Docker-Resources"
GH_BRANCH="main"
GH_RELEASE="${RESOURCE_RELEASE:-}"

# ==============================================================================
# DOWNLOAD DOS ARQUIVOS DO GITHUB
# ==============================================================================

download_from_github() {
    local api_url="$1"
    local download_dir="$2"

    log_info "Consultando API do GitHub..."
    log_info "URL: $api_url"

    curl -s "$api_url" | jq -r '.[] | select(.type=="file") | .download_url' |
    while read -r file_url; do
        [[ -z "$file_url" ]] && continue

        local file_name
        file_name=$(basename "$file_url")

        log_info "Baixando: $file_name"

        curl -sL "$file_url" -o "$download_dir/$file_name"

        log_success "Download concluído: $file_name"
    done
}

# ==============================================================================
# JUNÇÃO DE ARQUIVOS FRAGMENTADOS
# ==============================================================================

merge_split_files() {
    local base_dir="$1"
    shift
    local files=("$@")

    for file in "${files[@]}"; do
        if [[ -f "$base_dir/$file" ]]; then
            continue
        fi

        if ls "$base_dir/${file}"* >/dev/null 2>&1; then
            log_info "Montando arquivo fragmentado: $file"
            cat "$base_dir/${file}"* > "$base_dir/$file"
            log_success "Arquivo montado: $file"
        else
            log_warn "Nenhuma parte encontrada para: $file"
        fi
    done
}

# ==============================================================================
# INSTALAÇÃO DOS ARQUIVOS
# ==============================================================================

install_files() {
    local module="$1"
    local source_dir="$2"
    local dest_dir="$3"
    shift 3
    local files=("$@")

    mkdir -p "$dest_dir"
    
    log_info "Copiando arquivos..."

    for file in "${files[@]}"; do
        if [[ -f "$source_dir/$file" ]]; then
            cp "$source_dir/$file" "$dest_dir/"
            log_success "Copiado: $file"
        else
            log_warn "Arquivo não encontrado: $file"
        fi
    done
    
}

# ==============================================================================
# PROCESSAMENTO DO MÓDULO
# ==============================================================================

process_module() {
    local module="$1"

    local gh_path
    local download_dir
    local dest_dir
    local files

    case "$module" in
        appserver)
            gh_path="${GH_RELEASE}/appserver"
            download_dir="/tmp/${GH_RELEASE}/appserver"
            dest_dir="totvs"
            files=("protheus.tar.gz" "protheus_data.tar.gz")
            ;;
        *)
            log_error "Módulo inválido: $module"
            exit 1
            ;;
    esac

    local api_url="https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/contents/${gh_path}?ref=${GH_BRANCH}"

    log_info "Iniciando setup do módulo: $module"

    mkdir -p "$download_dir"

    # Verifica se já existem arquivos no destino
    local need_download=false

    for file in "${files[@]}"; do
        if [[ ! -e "$dest_dir/$file" ]]; then
            need_download=true
            break
        fi
    done

    if [[ "$need_download" == true ]]; then
        download_from_github "$api_url" "$download_dir"
        merge_split_files "$download_dir" "${files[@]}"
        install_files "$module" "$download_dir" "$dest_dir" "${files[@]}"
    else
        log_info "Arquivos já existem localmente. Download ignorado."
    fi

    log_success "Processo finalizado para módulo: $module"
}

# ==============================================================================
# EXECUÇÃO PRINCIPAL
# ==============================================================================

main() {
    check_dependencies

    process_module appserver

    log_success "Todos os módulos foram processados com sucesso."
}

main