#!/bin/bash
set -euo pipefail

command_exists() { command -v "$1" &>/dev/null; }

assign_package_manager() {
    case "$(uname)" in
        Darwin) PACKAGE_MANAGER=brew ;;
        Linux)
            if   command_exists apt;    then PACKAGE_MANAGER=apt
            elif command_exists dnf;    then PACKAGE_MANAGER=dnf
            elif command_exists yum;    then PACKAGE_MANAGER=yum
            elif command_exists pacman; then PACKAGE_MANAGER=pacman
            else echo "$(uname -srm) is unsupported" >&2; exit 1
            fi ;;
        *) echo "$(uname) is unsupported" >&2; exit 1 ;;
    esac
}
assign_package_manager

assign_install_cmd() {
    case "$PACKAGE_MANAGER" in
        brew)   INSTALL_CMD=(brew install) ;;
        pacman) INSTALL_CMD=(sudo pacman -S --noconfirm) ;;
        *)      INSTALL_CMD=(sudo "$PACKAGE_MANAGER" install -y) ;;
    esac
}
assign_install_cmd

get_package() {
    command_exists "$1" && return
    "${INSTALL_CMD[@]}" "$1"
}

update_package_lists() {
    case "$PACKAGE_MANAGER" in
        brew)       brew update ;;
        pacman)     sudo pacman -Syu --noconfirm ;;
        *)          sudo "$PACKAGE_MANAGER" update -y ;;
    esac
}
update_package_lists

get_docker() {
    if ! command_exists docker; then 
        case "$PACKAGE_MANAGER" in
            pacman|brew)    get_package docker ;;
            *)              curl -fsSL https://get.docker.com | sudo sh ;;
        esac
        if [ "$(uname)" != Darwin ]; then
            sudo systemctl enable --now docker
        fi
    fi
}

get_package_dependencies() {
    # ----------------------------------------------------------------------
    if [ "$(uname)" == "Darwin" ]; then
        if ! command_exists brew; then 
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
    fi
    # ----------------------------------------------------------------------
    for pkg in git curl pv; do
        get_package "$pkg"
    done
    # ----------------------------------------------------------------------
    get_docker
}
get_package_dependencies

initialize_submodules() {
    # Traverse submodules // recursively update URLs in '.git/config' 
    # with '.gitmodules' // then initialize missing submodules //
    echo "Downloading game files..."
    git submodule sync --recursive && \
    git submodule update --init --recursive && \
    echo "Finished downloading game files"
}
initialize_submodules

show_prompts() {
    clear && echo '
    __          __     _   _ _____
    \ \        / /\   | \ | |  __ \
    \ \  /\  / /  \  |  \| | |  | |
    \ \/  \/ / /\ \ | . ` | |  | |
        \  /\  / ____ \| |\  | |__| |
        \/  \/_/    \_\_| \_|_____/

        Wand Installation Script
    '

    if [[ -d .data && -f .env ]]; then
        dbpass=$(grep 'POSTGRES_PASSWORD=' .env | cut -d= -f2 | xargs)
        echo "Existing database found. Using existing password."
    else
        read -rsp "Enter password: " dbpass; echo
        if [[ -z $dbpass ]]; then
            dbpass=$(openssl rand -base64 12)
            echo "$dbpass"
            echo
        fi
    fi

    read -rp "Enter hostname: " hostname
    if [[ -z $hostname ]]; then
        hostname=localhost
        echo "$hostname"
        echo
    fi

    read -rp "Enter IP address: " ipadd
    if [[ -z $ipadd ]]; then
        ipadd=127.0.0.1
        echo "$ipadd"
        echo
    fi
}
show_prompts

write_dotenv() {
    /bin/cat > .env <<- SHELL
        ###################################################################################################
        # DATABASE (PostgreSQL)
        # https://github.com/solero/wand/blob/master/docker-compose.yml
        # https://github.com/solero/houdini/blob/master/bootstrap.py
        ###################################################################################################

        POSTGRES_USER=postgres
        POSTGRES_PASSWORD=$dbpass
        REDIS_PASSWORD=redis

        ####################################################################################################
        # WEB (Nginx)
        # https://github.com/jwilder/dockerize#using-templates
        # https://github.com/solero/wand/blob/master/templates/sites/vanilla.conf.template
        # https://github.com/solero/wand/blob/master/templates/vanilla-media/play/index.html.template
        ####################################################################################################

        WEB_PORT=80
        HTTPS_PORT=443

        WEB_HOSTNAME=$hostname

        WEB_VANILLA_PLAY=http://play.$hostname
        WEB_VANILLA_MEDIA=http://media.$hostname

        WEB_LEGACY_PLAY=http://old.$hostname
        WEB_LEGACY_MEDIA=http://legacy.$hostname

        ###################################################################################################
        # RUFFLE (cdn | self-hosted)
        # https://github.com/ruffle-rs/ruffle/tree/master/
        # https://github.com/Walainski/wand/blob/main/templates/vanilla-media/play/index.html.template
        ###################################################################################################

        RUFFLE_MODE=cdn
        RUFFLE_LOG_LEVEL=info

        ###################################################################################################
        # Google reCAPTCHA
        # https://developers.google.com/recaptcha/
        # https://github.com/solero/dash/blob/master/config.sample.py
        ###################################################################################################

        WEB_RECAPTCHA_SITE=
        WEB_RECAPTCHA_SECRET=

        ###################################################################################################
        # EMAIL/ACTIVATION
        # https://github.com/solero/dash/blob/master/config.sample.py
        ###################################################################################################

        EMAIL_METHOD= # SENDGRID or SMTP or empty (auto-activate accounts)
        EMAIL_FROM_ADDRESS=no-reply@example.com
        EMAIL_SENDGRID_KEY=
        EMAIL_SMTP_HOST=
        EMAIL_SMTP_PORT=
        EMAIL_SMTP_USER=
        EMAIL_SMTP_PASS=
        EMAIL_SMTP_SSL=FALSE

        ###################################################################################################
        # GAME SERVER
        # https://github.com/solero/houdini/blob/master/bootstrap.py
        # https://github.com/Lekuruu/houdini-websockets
        ###################################################################################################

        GAME_ADDRESS=$ipadd
        GAME_LOGIN_PORT=6112
        GAME_LOGIN_WEBSOCKET=7112
        SERVER_LOG_LEVEL=INFO

        ###################################################################################################
        # TLS/HTTPS
        # https://github.com/Lekuruu/houdini-websockets/blob/main/__init__.py
        # https://github.com/Walainski/wand/blob/main/templates/vanilla-media/play/index.html.template
        # https://github.com/Lekuruu/snowflake/blob/main/.env_example
        ###################################################################################################

        TLS_ENABLED=False
        SSL_KEYS_DIR=/etc/nginx/ssl
        KEY_FILE_PEM=
        CERT_FILE_PEM=

        ###################################################################################################
        # SNOWFLAKE (CJSnow)
        # https://github.com/Lekuruu/snowflake/blob/main/.env_example
        ###################################################################################################

        SNOWFLAKE_LOGGING_ENABLED=False
        SNOWFLAKE_HOST=$ipadd
        SNOWFLAKE_PORT=7002
        SNOWFLAKE_WS_PORT=8002
        APPLY_WINDOWMANAGER_OFFSET=True
        ALLOW_FORCESTART_SNOW=False
        ALLOW_FORCESTART_TUSK=False
        MATCHMAKING_TIMEOUT=30
SHELL
}
write_dotenv

# ----------------------------------------------------------------------
read -rp "Run the game? (Y/n): " run_game
if [[ "$run_game" =~ ^[Yy]$ ]]; then
    sudo docker compose up
fi
