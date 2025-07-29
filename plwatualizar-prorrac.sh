#!/bin/bash

# Cores
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
CYAN="\033[36m"
NC="\033[0m"

# Arquivos de controle
LOG_FILE="/tmp/atualizacao_prorrac.log"
VARS_FILE="/tmp/atualizacao_prorrac.vars"
BUILD_LOG="/tmp/build_frontend.log"

# Banner visual
print_banner() {
  clear
  echo -e "${GREEN}============================================="
  echo "            ATUALIZAÇÃO PRORRAC              "
  echo -e "=============================================${NC}"
  printf "${GREEN}"
  printf "░▒▓███████▓▒░░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓███████▓▒░░▒▓███████▓▒░ ░▒▓██████▓▒░ ░▒▓██████▓▒░\n"
  printf "░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░\n"
  printf "░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░        \n"
  printf "░▒▓███████▓▒░░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░░▒▓███████▓▒░░▒▓████████▓▒░▒▓█▓▒░        \n"
  printf "░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░        \n"
  printf "░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░\n"
  printf "░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░\n"
  printf "${NC}"
  echo -e "${GREEN}=============================================${NC}"
}

salvar_etapa() {
  echo "$1" > "$LOG_FILE"
}

salvar_variaveis() {
  {
    echo "deploy_path=\"$deploy_path\""
    echo "old_folder=\"$old_folder\""
    echo "new_old_folder=\"$new_old_folder\""
    echo "new_folder=\"$new_folder\""
  } > "$VARS_FILE"
}

get_incremented_folder_name() {
  base="$1-old"
  count=1
  new_name="$base"
  while [[ -d "$new_name" ]]; do
    new_name="${base}-${count}"
    ((count++))
  done
  echo "$new_name"
}

# Verificação de etapa anterior
if [[ -f "$LOG_FILE" ]]; then
  print_banner
  echo -e "${YELLOW}⚠ Uma atualização anterior foi iniciada.${NC}"
  read -p "Deseja continuar de onde parou? [Y/N]: " continuar
  if [[ "$continuar" =~ ^[Yy]$ ]]; then
    if [[ -f "$VARS_FILE" ]]; then
      source "$VARS_FILE"
      etapa=$(cat "$LOG_FILE")
    else
      echo -e "${RED}Arquivo de variáveis não encontrado. Cancelando.${NC}"
      exit 1
    fi
  else
    rm -f "$LOG_FILE" "$VARS_FILE" "$BUILD_LOG"
    etapa="inicio"
  fi
else
  etapa="inicio"
fi

# Etapa: INÍCIO
if [[ "$etapa" == "inicio" ]]; then
  print_banner
  echo -e "${YELLOW}⚠ IMPORTANTE: Faça um backup ou snapshot da VPS antes de continuar.${NC}"
  read -p "Deseja continuar? [Y/N]: " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { echo -e "${RED}Operação cancelada.${NC}"; exit 1; }

  echo -e "${CYAN}📂 Iniciando atualização...${NC}"
  read -p "Digite o caminho do diretório de deploy (ex: /home/deploy): " deploy_path
  cd "$deploy_path" || { echo -e "${RED}Caminho inválido.${NC}"; exit 1; }

  read -p "Nome da pasta atual do projeto: " old_folder
  [ -d "$old_folder" ] || { echo -e "${RED}Pasta não encontrada.${NC}"; exit 1; }

  env_file="$deploy_path/$old_folder/backend/.env"
  if [[ -f "$env_file" ]]; then
    DB_NAME=$(grep -E '^DB_NAME=' "$env_file" | cut -d '=' -f2)
    DB_NAME="${DB_NAME//[$'\r\n']}"
  fi
  [[ -z "$DB_NAME" ]] && read -p "Nome do banco (não encontrado no .env): " DB_NAME

  echo -e "${CYAN}📦 Backup do banco: $DB_NAME...${NC}"
  BACKUP_FILE="${DB_NAME}_backup_$(date +%Y%m%d_%H%M%S).sql"
  sudo -u postgres pg_dump "$DB_NAME" > "$BACKUP_FILE"

  echo -e "${CYAN}📦 Compactando pasta $old_folder...${NC}"
  ZIP_FILE="${old_folder}_backup_$(date +%Y%m%d_%H%M%S).zip"
  zip -r "$ZIP_FILE" "$old_folder" -x "*node_modules/*" "*build/*" "*dist/*" "*public/*"

  echo -e "${CYAN}🚚 Movendo arquivos para /root...${NC}"
  sudo mv "$BACKUP_FILE" "$ZIP_FILE" /root/

  new_old_folder=$(get_incremented_folder_name "$old_folder")
  mv "$old_folder" "$new_old_folder"

  echo -e "${GREEN}Parando PM2...${NC}"
  sudo su deploy -c "pm2 stop all"

  read -p "Nome da nova pasta (ex: prorrac-v2): " new_folder
  read -p "Caminho da pasta com os arquivos atualizados (com frontend/ e backend/): " source_folder
  [ -d "$source_folder/backend" ] && [ -d "$source_folder/frontend" ] || {
    echo -e "${RED}Pasta frontend/backend não encontrada.${NC}"
    exit 1
  }

  mkdir "$new_folder"
  if command -v rsync &>/dev/null; then
    rsync -a "$source_folder/" "$new_folder/"
  else
    cp -r "$source_folder/"* "$new_folder"
  fi

  salvar_variaveis
  salvar_etapa "copiar_arquivos"
  etapa="copiar_arquivos"
fi

# Etapa: VERIFICAÇÃO DOS ARQUIVOS
if [[ "$etapa" == "copiar_arquivos" ]]; then
  print_banner
  echo -e "${CYAN}🔍 Verificando integridade dos arquivos...${NC}"
  for file in backend/.env frontend/.env frontend/server.js; do
    if ! cmp -s "$new_old_folder/$file" "$new_folder/$file"; then
      echo -e "${RED}⚠ Arquivo $file está diferente ou ausente.${NC}"
      read -p "Deseja continuar mesmo assim? [Y/N]: " confirma
      [[ ! "$confirma" =~ ^[Yy]$ ]] && exit 1
    fi
  done
  salvar_etapa "backend"
  etapa="backend"
fi

# Etapa: BACKEND
if [[ "$etapa" == "backend" ]]; then
  print_banner
  echo -e "${CYAN}🚧 Instalando BACKEND...${NC}"
  cd "$deploy_path/$new_folder/backend" || exit 1
  npm install || { echo -e "${RED}Erro ao instalar dependências.${NC}"; exit 1; }
  npm run build || { echo -e "${RED}Erro ao compilar backend.${NC}"; exit 1; }
  npx sequelize db:migrate || { echo -e "${RED}Erro ao migrar banco.${NC}"; exit 1; }

  salvar_etapa "frontend"
  etapa="frontend"
fi

# Etapa: FRONTEND
if [[ "$etapa" == "frontend" ]]; then
  print_banner
  echo -e "${CYAN}🚧 Instalando FRONTEND...${NC}"
  cd "$deploy_path/$new_folder/frontend" || exit 1
  npm install || { echo -e "${RED}Erro ao instalar dependências.${NC}"; exit 1; }

  echo -e "${CYAN}🌐 Atualizando Browserslist...${NC}"
  npx update-browserslist-db@latest --update-db || echo -e "${YELLOW}⚠ Não foi possível atualizar Browserslist.${NC}"

  echo -e "${YELLOW}⏳ Criando build otimizado...${NC}"
  if ! npm run build > "$BUILD_LOG" 2>&1; then
    echo -e "${RED}❌ Erro ao criar build do frontend.${NC}"
    echo -e "${YELLOW}Veja o log: $BUILD_LOG${NC}"
    exit 1
  fi

  [[ ! -d "build" ]] && { echo -e "${RED}❌ Build não foi gerado.${NC}"; exit 1; }

  salvar_etapa "pm2"
  etapa="pm2"
fi

# Etapa: FINALIZAÇÃO
if [[ "$etapa" == "pm2" ]]; then
  print_banner
  echo -e "${CYAN}🔁 Reiniciando PM2...${NC}"
  sudo su deploy -c "pm2 restart all" || echo -e "${YELLOW}⚠ PM2 não reiniciado. Verifique permissões.${NC}"

  echo -e "${CYAN}📦 Movendo build para backend/public...${NC}"
  rm -rf "$deploy_path/$new_folder/backend/public"
  cp -r "$deploy_path/$new_folder/frontend/build" "$deploy_path/$new_folder/backend/public"

  echo -e "${GREEN}✅ Atualização concluída com sucesso!${NC}"
  echo
  echo -e "${CYAN}📋 Checklist pós-atualização:${NC}"
  echo -e "${CYAN}- Verifique funcionamento do sistema"
  echo -e "${CYAN}- Verifique logs com: pm2 logs"
  echo -e "${CYAN}- Acesse: http://<seu-servidor>"
  echo
  echo -e "${GREEN}💡 Suporte: www.plwdesign.online${NC}"

  rm -f "$LOG_FILE" "$VARS_FILE" "$BUILD_LOG"
fi
