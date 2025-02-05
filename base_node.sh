#!/bin/bash

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

REPO_URL="https://github.com/base-org/node"
NODE_DIR="$HOME/base-node"
DOCKER_COMPOSE_FILE="$NODE_DIR/docker-compose.yml"

download_latest_snapshot() {
    echo "Загрузка последнего снепшота Base ноды..."
    wget https://mainnet-reth-archive-snapshots.base.org/$(curl -s https://mainnet-reth-archive-snapshots.base.org/latest)
    echo "Снепшот загружен!"
}

prepare_server() {
    echo "Обновление системы и установка необходимых пакетов..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y docker.io docker-compose git jq
    sudo systemctl enable --now docker
    echo "Сервер подготовлен!"
}

fix_docker_compose() {
    echo "Проверка и исправление docker-compose.yml..."
    if grep -q "env_file:" "$DOCKER_COMPOSE_FILE"; then
        sed -i 's|env_file:.*|env_file: "\.env\.mainnet"|' "$DOCKER_COMPOSE_FILE"
        echo "Выбран mainnet в docker-compose.yml"
    fi
}

install_node() {
    echo "Введите значение OP_NODE_L1_ETH_RPC: "
    read OP_NODE_L1_ETH_RPC
    echo "Введите значение OP_NODE_L1_BEACON: "
    read OP_NODE_L1_BEACON

    echo "Клонирование репозитория..."
    git clone $REPO_URL $NODE_DIR || { echo "Ошибка клонирования"; exit 1; }
    cd $NODE_DIR || exit
    
    echo "Проверка наличия .env файла..."
    cat > .env.mainnet <<EOL
# Укажите нужные переменные окружения
EXECUTION_ENGINE_ENDPOINT="http://127.0.0.1:8551"
JWT_SECRET_PATH="/path/to/jwt.hex"
OP_NODE_L1_ETH_RPC="$OP_NODE_L1_ETH_RPC"
OP_NODE_L1_BEACON="$OP_NODE_L1_BEACON"
EOL
    
    fix_docker_compose
    
    echo "Сборка ноды..."
    docker-compose up -d || { echo "Ошибка запуска Docker Compose"; exit 1; }
    echo "Нода установлена и запущена!"
}

view_logs() {
    echo "Открытие логов ноды..."
    cd $NODE_DIR || exit
    docker-compose logs -f
}

sync_node() {
    echo "Проверка статуса синхронизации..."
    command -v jq &> /dev/null || { echo "jq is not installed" 1>&2; return; }
    
    RESPONSE=$(curl -s -d '{"id":0,"jsonrpc":"2.0","method":"optimism_syncStatus"}' \
        -H "Content-Type: application/json" http://localhost:7545)
    
    TIMESTAMP=$(echo "$RESPONSE" | jq -r .result.unsafe_l2.timestamp)
    
    if ! [[ "$TIMESTAMP" =~ ^[0-9]+$ ]]; then
        echo "Ошибка: получены некорректные данные. Проверьте, работает ли нода и RPC."
        return
    fi
    
    LATEST_SYNCED=$((($(date +%s) - TIMESTAMP) / 60))
    echo "Последний синхронизированный блок отстает на: $LATEST_SYNCED минут"
}

restart_node() {
    echo "Перезапуск ноды..."
    cd $NODE_DIR || exit
    docker-compose down && docker-compose up -d
    echo "Нода перезапущена!"
}

delete_node() {
    read -p "Для подтверждения удаления введите 'delete': " confirm
    if [[ "$confirm" == "delete" ]]; then
        echo "Удаление ноды..."
        cd $NODE_DIR || exit
        docker-compose down
        cd $HOME
        rm -rf $NODE_DIR
        echo "Нода удалена полностью!"
    else
        echo "Удаление отменено."
    fi
}

while true; do
    echo -e "\nМеню управления нодой Base Mainnet:"
    echo "1. Подготовить сервер"
    echo "2. Установить ноду"
    echo "3. Скачать последний снепшот ноды"
    echo "4. Посмотреть логи ноды"
    echo "5. Проверить статус синхронизации"
    echo "6. Перезапустить ноду"
    echo "7. Удалить ноду"
    echo "8. Выход"
    read -p "Выберите действие: " choice

    case $choice in
        1) prepare_server ;;
        2) install_node ;;
        3) download_latest_snapshot ;;
        4) view_logs ;;
        5) sync_node ;;
        6) restart_node ;;
        7) delete_node ;;
        8) echo "Выход..."; exit 0 ;;
        *) echo "Неверный выбор!" ;;
    esac

done
