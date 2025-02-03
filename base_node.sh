#!/bin/bash
# install_base_node.sh
# Скрипт для установки ноды Base с выбором различных вариантов установки

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

# Функция для запуска ноды через Docker (предполагается наличие docker-compose.yml)
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

# Главное меню
while true; do
    echo "-----------------------------------------"
    echo "Меню установки ноды Base"
    echo "1. Установить Docker и Docker Compose"
    echo "2. Установить зависимости для сборки"
    echo "3. Клонировать репозиторий Base"
    echo "4. Собрать ноду из исходников"
    echo "5. Запустить ноду через Docker Compose"
    echo "6. Запустить ноду из собранного бинарника"
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
