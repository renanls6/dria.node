#!/bin/bash

set -e

# ----------- 1. Install Dependencies ------------
echo "Atualizando e instalando pacotes necessários..."
sudo apt update && sudo apt upgrade -y
sudo apt install ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev curl git wget make jq build-essential pkg-config lsb-release libssl-dev libreadline-dev libffi-dev gcc screen unzip lz4 -y

# ----------- Docker Install ------------
echo "Instalando Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io -y
docker version

# ----------- Docker Compose Install ------------
echo "Instalando Docker Compose..."
VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
sudo curl -L "https://github.com/docker/compose/releases/download/${VER}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

# ----------- Docker Permissions ------------
echo "Adicionando permissão Docker ao usuário..."
sudo groupadd docker || true
sudo usermod -aG docker $USER

# ----------- Go Install ------------
echo "Instalando Go..."
sudo rm -rf /usr/local/go
curl -L https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bash_profile
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bash_profile
source ~/.bash_profile
go version

# ----------- EigenLayer CLI ------------
echo "Instalando CLI do EigenLayer..."
curl -sSfL https://raw.githubusercontent.com/layr-labs/eigenlayer-cli/master/scripts/install.sh | sh -s
export PATH=$PATH:~/bin
eigenlayer --version

# ----------- Clonar repositório AVS ------------
echo "Clonando repositório do Chainbase AVS..."
git clone https://github.com/chainbase-labs/chainbase-avs-setup
cd chainbase-avs-setup/holesky

# ----------- Criar Carteira ------------
echo "⚠️ Criação de carteira Eigenlayer (manual)"
echo "Use uma senha como ***123ABCabc123***"
echo "Pressione ENTER quando terminar a criação da chave para continuar..."
eigenlayer operator keys create --key-type ecdsa opr
read -p "Pressione ENTER para continuar..."

# ----------- Registrar Operador ------------
echo "Criando config de operador..."
eigenlayer operator config create

# ----------- Aguardando edição manual ------------
echo "⚠️ Edite agora os arquivos metadata.json e operator.yaml conforme documentação!"
read -p "Pressione ENTER depois de editar os arquivos corretamente..."

# ----------- Registro do operador ------------
eigenlayer operator register operator.yaml
eigenlayer operator status operator.yaml

# ----------- Config .env ------------
echo "Criando .env..."
cat <<EOF > .env
NODE_ECDSA_KEY_PASSWORD=***123ABCabc123***

# Imagens do AVS
MAIN_SERVICE_IMAGE=repository.chainbase.com/network/chainbase-node:testnet-v0.1.7
FLINK_TASKMANAGER_IMAGE=flink:latest
FLINK_JOBMANAGER_IMAGE=flink:latest
PROMETHEUS_IMAGE=prom/prometheus:latest

MAIN_SERVICE_NAME=chainbase-node
FLINK_TASKMANAGER_NAME=flink-taskmanager
FLINK_JOBMANAGER_NAME=flink-jobmanager
PROMETHEUS_NAME=prometheus

FLINK_CONNECT_ADDRESS=flink-jobmanager
FLINK_JOBMANAGER_PORT=8081
NODE_PROMETHEUS_PORT=9091
PROMETHEUS_CONFIG_PATH=./prometheus.yml

NODE_APP_PORT=8080
NODE_ECDSA_KEY_FILE=/app/operator_keys/ecdsa_key.json
NODE_LOG_DIR=/app/logs
NODE_LOG_LEVEL=debug
NODE_LOG_FORMAT=text

NODE_ENABLE_METRICS=true
NODE_METRICS_PORT=9092

AVS_CONTRACT_ADDRESS=0x5E78eFF26480A75E06cCdABe88Eb522D4D8e1C9d
AVS_DIR_CONTRACT_ADDRESS=0x055733000064333CaDDbC92763c58BF0192fFeBf

NODE_CHAIN_RPC=https://rpc.ankr.com/eth_holesky
NODE_CHAIN_ID=17000

USER_HOME=$HOME
EIGENLAYER_HOME=\${USER_HOME}/.eigenlayer
CHAINBASE_AVS_HOME=\${EIGENLAYER_HOME}/chainbase/holesky
NODE_LOG_PATH_HOST=\${CHAINBASE_AVS_HOME}/logs
NODE_ECDSA_KEY_FILE_HOST=\${EIGENLAYER_HOME}/operator_keys/opr.ecdsa.key.json
EOF

# ----------- docker-compose.yml ------------
echo "Criando docker-compose.yml..."
cat <<'EOF' > docker-compose.yml
version: "3.9"
services:
  prometheus:
    image: ${PROMETHEUS_IMAGE}
    container_name: ${PROMETHEUS_NAME}
    env_file: .env
    volumes:
      - "${PROMETHEUS_CONFIG_PATH}:/etc/prometheus/prometheus.yml"
    command:
      - "--enable-feature=expand-external-labels"
      - "--config.file=/etc/prometheus/prometheus.yml"
    ports:
      - "9091:9090"
    networks:
      - chainbase
    restart: unless-stopped

  flink-jobmanager:
    image: ${FLINK_JOBMANAGER_IMAGE}
    container_name: ${FLINK_JOBMANAGER_NAME}
    env_file: .env
    ports:
      - "8081:8081"
    command: jobmanager
    networks:
      - chainbase
    restart: unless-stopped

  flink-taskmanager:
    image: ${FLINK_TASKMANAGER_IMAGE}
    container_name: ${FLINK_TASKMANAGER_NAME}
    env_file: .env
    depends_on:
      - flink-jobmanager
    command: taskmanager
    networks:
      - chainbase
    restart: unless-stopped

  chainbase-node:
    image: ${MAIN_SERVICE_IMAGE}
    container_name: ${MAIN_SERVICE_NAME}
    command: ["run"]
    env_file: .env
    ports:
      - "8080:8080"
      - "9092:9092"
    volumes:
      - "${NODE_ECDSA_KEY_FILE_HOST}:${NODE_ECDSA_KEY_FILE}"
      - "${NODE_LOG_PATH_HOST}:${NODE_LOG_DIR}:rw"
    depends_on:
      - prometheus
      - flink-jobmanager
      - flink-taskmanager
    networks:
      - chainbase
    restart: unless-stopped

networks:
  chainbase:
    driver: bridge
EOF

# ----------- Criar pastas necessárias ------------
echo "Criando diretórios para logs..."
source .env
mkdir -pv ${EIGENLAYER_HOME} ${CHAINBASE_AVS_HOME} ${NODE_LOG_PATH_HOST}

echo "⚠️ Atualize agora o prometheus.yml com o nome do seu operador"
read -p "Pressione ENTER quando terminar..."

# ----------- Finalizando ------------
echo "🚀 Pronto! Agora você pode rodar:"
echo "./chainbase-avs.sh register"
echo "./chainbase-avs.sh run"
