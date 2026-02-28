# Dockerização do AppServer para ERP TOTVS Protheus

## Overview

Este projeto contém a implementação do container Docker para o **AppServer** Protheus.

A imagem é projetada para rodar sobre distribuições **Enterprise Linux** (como **Red Hat UBI** ou **Oracle Linux**), oferecendo segurança e estabilidade corporativa.

### Modos de Operação

Esta imagem é versátil e pode operar em três modos distintos, configurados através da variável de ambiente `APPSERVER_MODE`:
*   **`application`** (padrão): Servidor de aplicação principal (SmartClient Web/TCP).
*   **`rest`**: Servidor configurado para atender requisições da API REST.
*   **`sqlite`**: Servidor de arquivos locais (LocalFiles) para alta performance de I/O em banco de dados local.

**Otimização:** O servidor web de gerenciamento legado em Python/Flask foi removido para reduzir o tamanho da imagem e aumentar a segurança.

### Outros Componentes Necessários

*   **Banco de Dados**: `mssql`, `postgres` ou `oracle`.
*   **dbaccess**: Middleware de acesso ao banco.
*   **licenseserver**: Gestão de licenças.

## Início Rápido

**Importante:** Este contêiner precisa estar na mesma rede Docker que os serviços de `dbaccess` e `licenseserver` para funcionar.

1.  **Baixe a imagem (se disponível no Docker Hub):**
    ```bash
    docker pull juliansantosinfo/totvs_appserver:latest
    ```

2.  **Crie a rede Docker (caso ainda não exista):**
    ```bash
    docker network create totvs
    ```

3.  **Execute o contêiner:**

    *   **Modo Aplicação (Smartclient):**
        ```bash
        docker run -d \
          --name totvs_appserver \
          --network totvs \
          -p 1234:1234 \
          -p 1235:1235 \
          -e "APPSERVER_MODE=application" \
          juliansantosinfo/totvs_appserver:latest
        ```

    *   **Modo REST (API):**
        ```bash
        docker run -d \
          --name totvs_apprest \
          --network totvs \
          -p 8080:8080 \
          -e "APPSERVER_MODE=rest" \
          juliansantosinfo/totvs_appserver:latest
        ```

    *   **Modo SQlite Server:**
        ```bash
        docker run -d \
          --name totvs_appsqlite \
          --network totvs \
          -p 12346:12346 \
          -e "APPSERVER_MODE=sqlite" \
          juliansantosinfo/totvs_appserver:latest
        ```

## Build Local

Caso queira construir a imagem localmente:

1.  Baixe os binários do servidor de aplicação, dicionários, help de campos, menus e o repositório de objetos (tttm120.rpo) e coloque nos diretórios correspondentes.

    Exemplo da estrutura de arquivos para o binário do servidor de aplicação e repositório de objetos.

    ```txt
    protheus
    ├── apo
    │   └── tttm120.rpo
    └── bin
        └── appserver
            ├── appserver.ini
            ├── appsrvlinux
            ├── ...

    protheus_data
    ├── data
    ├── system
    │   ├── sigaacd.xnu
    │   ├── sigaagd.xnu
    │   ├── sigaagr.xnu
    │   ├── ...
    └── systemload
        ├── hlpeng.txt
        ├── hlppor.txt
        ├── hlpspa.txt
        ├── sx2.unq
        └── sxsbra.txt
    ```

2.  Execute o script de build:
    ```bash
    ./build.sh
    ```

### Opções de Build

O script `build.sh` suporta várias opções:

```bash
./build.sh [OPTIONS]
```

**Opções disponíveis:**
- `--progress=<MODE>` - Define o modo de progresso (auto|plain|tty) [padrão: auto]
- `--no-cache` - Desabilita o cache do Docker
- `--no-extract` - Desabilita compressão de recursos no build
- `--build-arg KEY=VALUE` - Passa argumentos adicionais para o Docker build
- `--tag=<TAG>` - Define uma tag customizada para a imagem
- `-h, --help` - Exibe ajuda

**Exemplos:**
```bash
# Build padrão
./build.sh

# Build sem cache com progresso detalhado
./build.sh --progress=plain --no-cache

# Build com imagem base customizada
./build.sh --build-arg IMAGE_BASE=custom:tag

# Build com tag customizada
./build.sh --tag=myuser/appserver:1.0
```

### Build com Imagem Base Customizada

Quando usando uma imagem base customizada que já contém os recursos do Protheus (via `IMAGE_BASE` no `versions.env`), o script automaticamente pula a validação de diretórios locais:

```bash
# No GitHub Actions, IMAGE_BASE é carregado automaticamente
# Para build local com imagem customizada:
export IMAGE_BASE=juliansantosinfo/imagebase:totvs.protheus.appserver.1212510
./build.sh
```

## Push para Registry

Para enviar a imagem para o Docker Hub:

```bash
./push.sh [OPTIONS]
```

**Opções disponíveis:**
- `--no-latest` - Não faz push da tag 'latest'
- `--tag=<TAG>` - Define uma tag customizada para push
- `-h, --help` - Exibe ajuda

**Comportamento:**
- A tag `latest` só é enviada quando em branches `main` ou `master`
- Em outras branches, apenas a tag versionada é enviada

**Exemplos:**
```bash
# Push padrão (versão + latest se em main/master)
./push.sh

# Push apenas da versão (sem latest)
./push.sh --no-latest

# Push de tag customizada
./push.sh --tag=myuser/appserver:custom
```

## CI/CD com GitHub Actions

O projeto inclui workflow automatizado em `.github/workflows/deploy.yml` que:

1. **Detecta mudanças relevantes** - Ignora alterações em documentação e configurações
2. **Carrega imagem base customizada** - Usa `IMAGE_BASE` do `versions.env`
3. **Build automatizado** - Executa `./build.sh` com detecção de ambiente
4. **Push condicional** - Envia `latest` apenas em branches principais

**Configuração necessária:**

Adicione os secrets no repositório GitHub:
- `DOCKER_USERNAME` - Usuário do Docker Hub
- `DOCKER_TOKEN` - Token de acesso do Docker Hub

**Triggers:**
- Push em branches: `master`, `main`, `12.1.*`
- Pull requests para essas branches
- Execução manual via `workflow_dispatch`

## Variáveis de Ambiente

| Variável | Descrição | Padrão |
|---|---|---|
| `APPSERVER_MODE` | Define o modo de operação: `application`, `rest` ou `sqlite`. | `application` |
| `APPSERVER_DBACCESS_DATABASE` | Tipo do banco de dados (POSTGRES, MSSQL, ORACLE). | `MSSQL` |
| `APPSERVER_DBACCESS_SERVER` | Host do serviço DBAccess. | `totvs_dbaccess` |
| `APPSERVER_DBACCESS_PORT` | Porta do serviço DBAccess. | `7890` |
| `APPSERVER_DBACCESS_ALIAS` | Alias da conexão com o banco. | `protheus` |
| `APPSERVER_LICENSE_SERVER` | Host do License Server. | `totvs_licenseserver` |
| `APPSERVER_LICENSE_PORT` | Porta do License Server. | `5555` |
| `APPSERVER_PORT` | Porta principal do AppServer (TCP). | `1234` |
| `APPSERVER_WEB_PORT` | Porta da interface web (Smartclient). | `1235` |
| `APPSERVER_REST_PORT` | Porta do serviço REST (usado no modo `rest`). | `8080` |
| `APPSERVER_ENVIRONMENT_LOCALFILES`| Tipo de banco para arquivos locais. | `SQLITE` |
| `LICENSE_WAIT_RETRIES` | Tentativas de conexão com o License Server. | `30` |
| `LICENSE_WAIT_INTERVAL` | Intervalo em segundos entre tentativas. | `2` |
| `DBACCESS_WAIT_RETRIES` | Tentativas de conexão com o DBAccess. | `30` |
| `DBACCESS_WAIT_INTERVAL` | Intervalo em segundos entre tentativas. | `2` |
| `DEBUG_SCRIPT` | Ativa o modo de depuração dos scripts (`true`/`false`). | `false` |
| `TZ` | Fuso horário do contêiner. | `America/Sao_Paulo` |