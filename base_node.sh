#!/bin/bash
# base_node.sh
# Скрипт для установки и управления нодой Base с текстовым меню

# Функция для установки Docker и Docker Compose
install_docker() {
    echo "Обновление пакетов и установка Docker и Docker Compose..."
    sudo apt update
    sudo apt install -y docker.io docker-compose
    sudo systemctl enable --now docker
    echo "Docker и Docker Compose успешно установлены."
}

# Функция для установки зависимостей для сборки ноды
install_build_dependencies() {
    echo "Установка необходимых зависимостей для сборки ноды..."
    sudo apt update
    sudo apt install -y git build-essential curl
    echo "Зависимости успешно установлены."
}

# Функция для клонирования репозитория Base
clone_repository() {
    if [ -d "base" ]; then
        echo "Каталог 'base' уже существует. Пропускаем клонирование."
    else
        echo "Клонирование репозитория Base..."
        git clone https://github.com/base-org/base.git
    fi
}

# Функция для сборки ноды из исходников
build_from_source() {
    if [ ! -d "base" ]; then
        echo "Каталог 'base' не найден. Сначала выполните клонирование репозитория."
        return
    fi
    cd base || exit
    echo "Запуск сборки ноды (make build)..."
    make build
    echo "Сборка завершена."
    cd ..
}

# Функция для запуска ноды через Docker Compose
run_docker() {
    echo "Запуск ноды через Docker Compose..."
    if [ -f "docker-compose.yml" ]; then
        docker-compose up -d
    else
        echo "Файл docker-compose.yml не найден в текущем каталоге."
        echo "Убедитесь, что вы находитесь в каталоге с файлом или используйте другой вариант запуска."
    fi
}

# Функция для запуска ноды из собранного бинарного файла
run_node() {
    if [ ! -d "base" ]; then
        echo "Каталог 'base' не найден. Сначала выполните клонирование репозитория и сборку."
        return
    fi
    cd base || exit
    if [ -f "./base-node" ]; then
        echo "Запуск ноды с использованием конфигурационного файла config/config.toml..."
        ./base-node --config config/config.toml
    else
        echo "Исполняемый файл 'base-node' не найден. Сначала выполните сборку ноды."
    fi
    cd ..
}

# Функция для просмотра логов
view_logs() {
    echo "Попытка просмотреть логи ноды Base."
    # Если нода запущена через Docker
    if docker ps | grep -q "base-node"; then
        echo "Просмотр логов Docker контейнера 'base-node'. Нажмите Ctrl+C для выхода."
        docker logs -f base-node
    else
        # Если запущена как бинарный процесс и логи записываются в файл (пример: base/logs/base.log)
        if [ -f "base/logs/base.log" ]; then
            echo "Просмотр логов из файла base/logs/base.log. Нажмите Ctrl+C для выхода."
            tail -f base/logs/base.log
        else
            echo "Логи не найдены. Убедитесь, что нода запущена и логи доступны."
        fi
    fi
}

# Функция для запуска синхронизации (пересинхронизации) ноды
start_sync() {
    echo "Начало процесса синхронизации ноды Base."
    echo "ВНИМАНИЕ: Эта операция удалит локальные данные ноды и перезапустит её."
    read -rp "Вы уверены, что хотите продолжить? (y/N): " confirm_sync
    if [[ ! "$confirm_sync" =~ ^[Yy]$ ]]; then
        echo "Операция отменена."
        return
    fi

    # Если используется Docker
    if docker ps -a | grep -q "base-node"; then
        echo "Останавливаем Docker контейнер 'base-node'..."
        docker stop base-node
        echo "Для пересинхронизации необходимо удалить данные ноды."
        read -rp "Введите путь к каталогу данных, который нужно очистить (например, /path/to/data): " data_path
        if [ -d "$data_path" ]; then
            rm -rf "$data_path"/*
            echo "Данные удалены."
        else
            echo "Каталог данных не найден. Пропускаем удаление."
        fi
        echo "Перезапуск Docker контейнера 'base-node'..."
        docker start base-node
    else
        # Если нода запущена как бинарный процесс
        echo "Если нода запущена как бинарный процесс, убедитесь, что она остановлена."
        if [ -d "base/data" ]; then
            rm -rf base/data/*
            echo "Данные ноды удалены."
        else
            echo "Каталог данных не найден. Пропускаем удаление."
        fi
        echo "Запуск ноды для синхронизации..."
        cd base || exit
        ./base-node --config config/config.toml
        cd ..
    fi
}

# Функция для удаления ноды (все файлы, Docker-контейнер и исходный код)
delete_node() {
    echo "Внимание! Эта операция удалит ноду Base и все связанные файлы."
    read -rp "Вы уверены, что хотите продолжить? Это действие нельзя отменить! (y/N): " confirm_delete
    if [[ "$confirm_delete" =~ ^[Yy]$ ]]; then
        # Если используется Docker, остановить и удалить контейнер
        if docker ps -a | grep -q "base-node"; then
            echo "Останавливаем и удаляем Docker контейнер 'base-node'..."
            docker stop base-node
            docker rm base-node
        fi
        # Удаляем каталог с исходным кодом и данными
        if [ -d "base" ]; then
            rm -rf base
            echo "Каталог 'base' удалён."
        else
            echo "Каталог 'base' не найден."
        fi
        echo "Операция удаления завершена."
    else
        echo "Операция отменена."
    fi
}

# Главное меню
while true; do
    echo "-----------------------------------------"
    echo "Меню управления нодой Base"
    echo "1. Установить Docker и Docker Compose"
    echo "2. Установить зависимости для сборки"
    echo "3. Клонировать репозиторий Base"
    echo "4. Собрать ноду из исходников"
    echo "5. Запустить ноду через Docker Compose"
    echo "6. Запустить ноду из собранного бинарника"
    echo "7. Просмотреть логи ноды"
    echo "8. Начать синхронизацию (пересинхронизацию) ноды"
    echo "9. Удалить ноду (со всеми её файлами)"
    echo "0. Выход"
    echo "-----------------------------------------"
    read -rp "Выберите опцию: " choice

    case $choice in
        1)
            install_docker
            ;;
        2)
            install_build_dependencies
            ;;
        3)
            clone_repository
            ;;
        4)
            build_from_source
            ;;
        5)
            run_docker
            ;;
        6)
            run_node
            ;;
        7)
            view_logs
            ;;
        8)
            start_sync
            ;;
        9)
            delete_node
            ;;
        0)
            echo "Выход из программы..."
            exit 0
            ;;
        *)
            echo "Неверный выбор! Пожалуйста, введите корректный номер опции."
            ;;
    esac
    echo ""
done
