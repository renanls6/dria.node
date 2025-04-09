#!/bin/bash

# Funções para exibir mensagens
info_message() {
    echo -e "\033[0;36m[INFO] $1\033[0m"
}

success_message() {
    echo -e "\033[0;32m[SUCCESS] $1\033[0m"
}

error_message() {
    echo -e "\033[0;31m[ERROR] $1\033[0m"
}

# Função para atualizar o sistema
update_system() {
    info_message "Atualizando o sistema..."
    sudo apt update && sudo apt upgrade -y || error_message "Falha ao atualizar o sistema."
}

# Função para instalar o screen
install_screen() {
    info_message "Instalando o screen..."
    sudo apt install -y screen || error_message "Falha ao instalar o screen."
}

# Função para baixar o arquivo do node Dria
download_node() {
    info_message "Baixando o instalador do Dria..."
    curl -fsSL https://dria.co/launcher | bash || error_message "Falha ao baixar o arquivo do node."
}

# Função para configurar o shell
update_shell() {
    info_message "Atualizando o shell..."
    source ~/.bash_profile
    source ~/.bashrc || error_message "Falha ao atualizar o shell."
}

# Função para criar uma nova sessão no screen
create_screen_session() {
    info_message "Criando uma nova sessão 'dria' no screen..."
    screen -S dria -d -m || error_message "Falha ao criar a sessão no screen."
}

# Função para iniciar o nó Dria
start_node() {
    info_message "Iniciando o nó Dria..."
    screen -S dria -X stuff $'dkn-compute-launcher start\n' || error_message "Falha ao iniciar o nó."
}

# Função para selecionar modelos e configurar a chave de API
configure_models_and_api() {
    info_message "Configurando modelos e chave de API..."
    screen -S dria -X stuff $'right\n'  # Seleciona todos os modelos
    sleep 1
    screen -S dria -X stuff $'enter\n'  # Deselect gemini-1.5-flash (modelo pago)
    sleep 1
    screen -S dria -X stuff $'back\n'  # Volta para a seleção de modelos
    sleep 1
    screen -S dria -X stuff $'YOUR_GEMINI_API_KEY\n' || error_message "Falha ao inserir a chave da API."
    sleep 5
}

# Função para registrar código de referência
register_referral() {
    info_message "Registrando código de referência..."
    screen -S dria -X stuff $'dkn-compute-launcher referrals\n' || error_message "Falha ao registrar o código de referência."
    sleep 1
    screen -S dria -X stuff $'enter referral code\n' || error_message "Falha ao inserir o código de referência."
    sleep 1
    screen -S dria -X stuff $'lHJdNhI35KySDJJrd51D\n' || error_message "Falha ao inserir o código de referência."
    success_message "Código de referência registrado com sucesso."
}

# Função para exibir o menu principal
print_menu() {
    clear
    echo -e "\033[1;34m========================= MENU DE INSTALAÇÃO =========================\033[0m"
    echo -e "\033[1;32m1. Atualizar o sistema\033[0m"
    echo -e "\033[1;32m2. Instalar o Screen\033[0m"
    echo -e "\033[1;32m3. Baixar e instalar o nó Dria\033[0m"
    echo -e "\033[1;32m4. Atualizar o shell\033[0m"
    echo -e "\033[1;32m5. Criar sessão Screen e iniciar nó\033[0m"
    echo -e "\033[1;32m6. Configurar modelos e chave de API\033[0m"
    echo -e "\033[1;32m7. Registrar código de referência\033[0m"
    echo -e "\033[1;32m8. Sair\033[0m"
    echo -e "\033[1;34m======================================================================\033[0m"
}

# Função principal para o menu interativo
menu_loop() {
    while true; do
        print_menu
        echo -e "\033[1;33mEscolha uma opção (1-8):\033[0m"
        read -p "Escolha: " choice

        case $choice in
            1) update_system ;;
            2) install_screen ;;
            3) download_node ;;
            4) update_shell ;;
            5) create_screen_session && start_node ;;
            6) configure_models_and_api ;;
            7) register_referral ;;
            8)
                echo -e "\033[1;32mSaindo... Até logo!\033[0m"
                exit 0
                ;;
            *)
                echo -e "\033[0;31mOpção inválida! Por favor, escolha um número de 1 a 8.\033[0m"
                ;;
        esac

        # Espera o usuário pressionar Enter antes de retornar ao menu
        echo -e "\nPressione Enter para voltar ao menu..."
        read
    done
}

# Iniciar o menu interativo
menu_loop
