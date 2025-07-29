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
  printf "${NC}"
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

# Continuação de processo
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
  echo -e "${CYAN}📂 Iniciando atualização...${NC}"
  read -p "Digite o caminho do diretório de deploy (ex: /home/deploy): " deploy_path
  cd "$deploy_path" || { echo -e "${RED}Caminho inválido.${NC}"; exit 1; }

  read -p "Nome da pasta atual do projeto: " old_folder
  [ -d "$old_folder" ] || { echo -e "${RED}Pasta não encontrada.${NC}"; exit 1; }

  new_old_folder="${old_folder}-old-$(date +%s)"
  mv "$old_folder" "$new_old_folder"

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
      echo -e "${RED}⚠ Arquivo $file está diferente ou ausente na nova versão.${NC}"
      echo -e "${YELLOW}Deseja continuar mesmo assim? [Y/N]: ${NC}"
      read -r confirma
      [[ ! "$confirma" =~ ^[Yy]$ ]] && exit 1
    fi
  done
  salvar_etapa "backend"
  etapa="backend"
fi

# Etapa: BACKEND
if [[ "$etapa" == "backend" ]]; then
  print_banner
  echo -e "${CYAN}🚧 Instalando dependências BACKEND...${NC}"
  cd "$deploy_path/$new_folder/backend" || exit 1
  npm install || { echo -e "${RED}Erro ao instalar backend.${NC}"; exit 1; }
  npm run build || { echo -e "${RED}Erro ao compilar backend.${NC}"; exit 1; }
  npx sequelize db:migrate || { echo -e "${RED}Erro ao migrar banco backend.${NC}"; exit 1; }

  salvar_etapa "frontend"
  etapa="frontend"
fi

# Etapa: FRONTEND
if [[ "$etapa" == "frontend" ]]; then
  print_banner
  echo -e "${CYAN}🚧 Instalando dependências FRONTEND...${NC}"
  cd "$deploy_path/$new_folder/frontend" || exit 1
  npm install || { echo -e "${RED}Erro ao instalar frontend.${NC}"; exit 1; }

  echo -e "${CYAN}🌐 Atualizando Browserslist...${NC}"
  npx update-browserslist-db@latest --update-db || echo -e "${YELLOW}⚠ Browserslist não pôde ser atualizado.${NC}"

  echo -e "${YELLOW}⏳ Criando build otimizado...${NC}"
  if ! npm run build > "$BUILD_LOG" 2>&1; then
    echo -e "${RED}❌ Erro ao criar build do frontend.${NC}"
    echo -e "${YELLOW}Veja logs em: $BUILD_LOG${NC}"
    exit 1
  fi

  # Verifica se build foi gerado
  if [[ ! -d "build" ]]; then
    echo -e "${RED}❌ Build não foi gerado.${NC}"
    exit 1
  fi

  salvar_etapa "pm2"
  etapa="pm2"
fi

# Etapa: PM2 e FINALIZAÇÃO
if [[ "$etapa" == "pm2" ]]; then
  print_banner
  echo -e "${CYAN}🔁 Reiniciando PM2...${NC}"
  if ! sudo su deploy -c "pm2 restart all"; then
    echo -e "${YELLOW}⚠ PM2 não reiniciado. Verifique permissões ou execute manualmente.${NC}"
  fi

  echo -e "${CYAN}📦 Movendo build do frontend para backend/public...${NC}"
  rm -rf "$deploy_path/$new_folder/backend/public"
  cp -r "$deploy_path/$new_folder/frontend/build" "$deploy_path/$new_folder/backend/public"

  echo -e "${GREEN}✅ Atualização finalizada com sucesso!${NC}"
  rm -f "$LOG_FILE" "$VARS_FILE" "$BUILD_LOG"
fi
