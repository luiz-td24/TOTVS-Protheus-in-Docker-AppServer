#!/usr/bin/env bash
#
# ==============================================================================
# SCRIPT:      unpack.sh
# DESCRIÇÃO:   Processa e descompacta pacotes de dependências do diretório 'packages'
#              para as pastas correspondentes no projeto TOTVS Protheus.
# AUTOR:       Julian de Almeida Santos
# DATA:        2026-02-28
# USO:         ./unpack.sh [appserver|webapp|rpo|helps|dictionaries|menus|all]
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 🛠️ CONFIGURAÇÕES E CAMINHOS
# ------------------------------------------------------------------------------

# Diretórios base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="${BASE_DIR}/packages"
TOTVS_BIN_DIR="${BASE_DIR}/totvs/protheus/bin/appserver"
TOTVS_APO_DIR="${BASE_DIR}/totvs/protheus/apo"
TOTVS_SYSTEMLOAD_DIR="${BASE_DIR}/totvs/protheus_data/systemload"
TOTVS_SYSTEM_DIR="${BASE_DIR}/totvs/protheus_data/system"
VERSIONS_FILE="${BASE_DIR}/versions.env"

# Cores para logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# 📢 FUNÇÕES DE LOG
# ------------------------------------------------------------------------------

log_info()    { echo -e "ℹ️  $1"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn()    { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error()   { echo -e "${RED}❌ $1${NC}"; exit 1; }

# ------------------------------------------------------------------------------
# 🔍 VALIDAÇÕES INICIAIS
# ------------------------------------------------------------------------------

if [[ ! -f "$VERSIONS_FILE" ]]; then
    log_error "Arquivo de versões não encontrado em: $VERSIONS_FILE"
fi

# shellcheck source=/dev/null
source "$VERSIONS_FILE"

if [[ -z "${APPSERVER_BUILD_VERSION:-}" ]]; then
    log_error "A variável 'APPSERVER_BUILD_VERSION' não está definida no arquivo $VERSIONS_FILE"
fi

# ------------------------------------------------------------------------------
# 🚀 PROCESSAMENTO DO APPSERVER BINARY (TAR.GZ + VALIDAÇÃO)
# ------------------------------------------------------------------------------

process_appserver_bin() {
    echo "------------------------------------------------------------------------"
    log_info "Iniciando processamento do binário do AppServer..."

    local found_file=""
    found_file=$(find "$PACKAGES_DIR" -maxdepth 1 -iname "*APPSERVER_BUILD-*.TAR.GZ" -print -quit)

    if [[ -z "$found_file" ]]; then
        log_warn "Nenhum pacote de binário encontrado em '$PACKAGES_DIR' com 'APPSERVER_BUILD-'. Pulando..."
        return
    fi

    local filename
    filename=$(basename "$found_file")
    
    local file_version
    file_version=$(echo "$filename" | sed -n 's/.*APPSERVER_BUILD-\([0-9.]*\).*/\1/p')

    if [[ -z "$file_version" ]]; then
        log_error "Não foi possível extrair a versão do arquivo: $filename"
    fi

    log_info "Arquivo localizado: $filename"
    log_info "Versão detectada: $file_version"

    if [[ "$file_version" != "$APPSERVER_BUILD_VERSION" ]]; then
        echo -e "${RED}🚨 ERRO: Versão do arquivo (${file_version}) diverge do versions.env (${APPSERVER_BUILD_VERSION})${NC}"
        exit 1
    fi

    log_info "Descompactando para: $TOTVS_BIN_DIR..."
    mkdir -p "$TOTVS_BIN_DIR"
    tar -xzf "$found_file" -C "$TOTVS_BIN_DIR"
    
    log_success "Binário do AppServer descompactado com sucesso!"
}

# ------------------------------------------------------------------------------
# 🚀 PROCESSAMENTO DO SMARTCLIENT WEBAPP (WEBAPP.SO)
# ------------------------------------------------------------------------------

process_webapp() {
    echo "------------------------------------------------------------------------"
    log_info "Iniciando processamento do SmartClient WebApp (webapp.so)..."

    local found_file=""
    # Busca por arquivos que contenham 'SMARTCLIENT_WEBAPP' e terminem em '.TAR.GZ'
    found_file=$(find "$PACKAGES_DIR" -maxdepth 1 -iname "*SMARTCLIENT_WEBAPP*.TAR.GZ" -print -quit)

    if [[ -z "$found_file" ]]; then
        log_warn "Nenhum pacote de WebApp encontrado em '$PACKAGES_DIR' com '*SMARTCLIENT_WEBAPP*.TAR.GZ'. Pulando..."
        return
    fi

    local filename
    filename=$(basename "$found_file")
    log_info "Arquivo localizado: $filename"

    log_info "Descompactando para: $TOTVS_BIN_DIR..."
    mkdir -p "$TOTVS_BIN_DIR"
    tar -xzf "$found_file" -C "$TOTVS_BIN_DIR"
    
    log_success "SmartClient WebApp descompactado com sucesso!"
}

# ------------------------------------------------------------------------------
# 🚀 PROCESSAMENTO DO RPO (REPOSITÓRIO DE OBJETOS - CÓPIA E RENOMEAÇÃO)
# ------------------------------------------------------------------------------

process_rpo() {
    echo "------------------------------------------------------------------------"
    log_info "Iniciando processamento do RPO (Repositório de Objetos)..."

    local found_file=""
    found_file=$(find "$PACKAGES_DIR" -maxdepth 1 -iname "*REPOSITORIO_DE_OBJETOS*.RPO" -print -quit)

    if [[ -z "$found_file" ]]; then
        log_warn "Nenhum arquivo de RPO encontrado em '$PACKAGES_DIR' com '*REPOSITORIO_DE_OBJETOS*.RPO'. Pulando..."
        return
    fi

    local filename
    filename=$(basename "$found_file")
    
    local target_name
    target_name=$(echo "$filename" | awk -F'_' '{print $NF}' | tr '[:upper:]' '[:lower:]')

    log_info "Arquivo localizado: $filename"
    log_info "Nome final do RPO: $target_name"

    log_info "Copiando para: $TOTVS_APO_DIR..."
    mkdir -p "$TOTVS_APO_DIR"
    
    cp -f "$found_file" "$TOTVS_APO_DIR/$target_name"
    
    log_success "RPO processado com sucesso!"
}

# ------------------------------------------------------------------------------
# 🚀 PROCESSAMENTO DO HELPS (ZIP - SEM VALIDAÇÃO DE VERSÃO)
# ------------------------------------------------------------------------------

process_helps() {
    echo "------------------------------------------------------------------------"
    log_info "Iniciando processamento dos arquivos de Helps..."

    local found_file=""
    found_file=$(find "$PACKAGES_DIR" -maxdepth 1 -iname "*HELPS_COMP*.ZIP" -print -quit)

    if [[ -z "$found_file" ]]; then
        log_warn "Nenhum pacote de Helps encontrado em '$PACKAGES_DIR' com '*HELPS_COMP*.ZIP'. Pulando..."
        return
    fi

    local filename
    filename=$(basename "$found_file")
    log_info "Arquivo localizado: $filename"

    log_info "Extraindo para: $TOTVS_SYSTEMLOAD_DIR..."
    mkdir -p "$TOTVS_SYSTEMLOAD_DIR"
    
    unzip -oq "$found_file" -d "$TOTVS_SYSTEMLOAD_DIR"
    
    log_success "Arquivos de Helps extraídos com sucesso!"
}

# ------------------------------------------------------------------------------
# 🚀 PROCESSAMENTO DOS DICIONÁRIOS (ZIP - SEM VALIDAÇÃO DE VERSÃO)
# ------------------------------------------------------------------------------

process_dictionaries() {
    echo "------------------------------------------------------------------------"
    log_info "Iniciando processamento dos arquivos de Dicionários..."

    local found_file=""
    found_file=$(find "$PACKAGES_DIR" -maxdepth 1 -iname "*DICIONARIOS_COMP*.ZIP" -print -quit)

    if [[ -z "$found_file" ]]; then
        log_warn "Nenhum pacote de Dicionários encontrado em '$PACKAGES_DIR' com '*DICIONARIOS_COMP*.ZIP'. Pulando..."
        return
    fi

    local filename
    filename=$(basename "$found_file")
    log_info "Arquivo localizado: $filename"

    log_info "Extraindo para: $TOTVS_SYSTEMLOAD_DIR..."
    mkdir -p "$TOTVS_SYSTEMLOAD_DIR"
    
    unzip -oq "$found_file" -d "$TOTVS_SYSTEMLOAD_DIR"
    
    log_success "Arquivos de Dicionários extraídos com sucesso!"
}

# ------------------------------------------------------------------------------
# 🚀 PROCESSAMENTO DOS MENUS (ZIP - SEM VALIDAÇÃO DE VERSÃO)
# ------------------------------------------------------------------------------

process_menus() {
    echo "------------------------------------------------------------------------"
    log_info "Iniciando processamento dos arquivos de Menus..."

    local found_file=""
    found_file=$(find "$PACKAGES_DIR" -maxdepth 1 -iname "*MENUS*.ZIP" -print -quit)

    if [[ -z "$found_file" ]]; then
        log_warn "Nenhum pacote de Menus encontrado em '$PACKAGES_DIR' com '*MENUS*.ZIP'. Pulando..."
        return
    fi

    local filename
    filename=$(basename "$found_file")
    log_info "Arquivo localizado: $filename"

    log_info "Extraindo para: $TOTVS_SYSTEM_DIR..."
    mkdir -p "$TOTVS_SYSTEM_DIR"
    
    unzip -oq "$found_file" -d "$TOTVS_SYSTEM_DIR"
    
    log_success "Arquivos de Menus extraídos com sucesso!"
}

# ------------------------------------------------------------------------------
# 🏁 EXECUÇÃO PRINCIPAL
# ------------------------------------------------------------------------------

main() {
    local target="${1:-all}"
    
    log_info "🚀 Iniciando o script de descompactação de dependências..."
    
    case "$target" in
        appserver)
            process_appserver_bin
            ;;
        webapp)
            process_webapp
            ;;
        rpo)
            process_rpo
            ;;
        helps)
            process_helps
            ;;
        dictionaries)
            process_dictionaries
            ;;
        menus)
            process_menus
            ;;
        all)
            process_appserver_bin
            process_webapp
            process_rpo
            process_helps
            process_dictionaries
            process_menus
            ;;
        *)
            log_error "Opção inválida: $target. Use: appserver|webapp|rpo|helps|dictionaries|menus|all"
            ;;
    esac
    
    echo "------------------------------------------------------------------------"
    log_success "Processamento concluído!"
}

main "$@"
