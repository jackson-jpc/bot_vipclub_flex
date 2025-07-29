#!/bin/bash
set -e  # Interrompe o script se qualquer comando falhar

# Define cores
GREEN="\033[32m"
RED="\033[31m"
NC="\033[0m" # No Color

# Função para imprimir um banner com ASCII Art
function print_banner {
  clear
  echo -e "${GREEN}"
  echo "============================================="
  echo "            ATUALIZAÇÃO PRORRAC              "
  echo "============================================="
  echo -e "${NC}"

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

# Função para criar nome de backup sem sobrescrever
function get_incremented_folder_name {
  base_name="$1-old"
  increment=1
  new_folder_name="$base_name"
  while [ -d "$new_folder_name" ]; do
    new_folder_name="${base_name}-${increment}"
    increment=$((increment + 1))
  done
  echo "$new_folder_name"
}

print_banner

echo -e "${GREEN}AVISO IMPORTANTE: Faça um backup e snapshot da sua VPS antes de continuar.${NC}"
read -p "Deseja continuar? [Y/N]: " choice
[[ "$choice" =~ ^[Yy]$ ]] || { echo -e "${RED}Operação cancelada.${NC}"; exit 1; }

print_banner

# Parar PM2
echo -e "${GREEN}Parando aplicações do PM2...${NC}"
sudo su deploy -c "pm2 stop all"

print_banner

# Caminho do deploy
echo -e "${GREEN}Digite o caminho do diretório de deploy (ex: /home/deploy):${NC}"
read deploy_path
[ -d "$deploy_path" ] || { echo -e "${RED}Diretório inválido.${NC}"; exit 1; }
cd "$deploy_path"

print_banner

# Nome da pasta atual
echo -e "${GREEN}Digite o nome da pasta atual do projeto:${NC}"
read old_folder_name
[ -d "$old_folder_name" ] || { echo -e "${RED}Pasta não encontrada.${NC}"; exit 1; }

# Backup da pasta
new_old_folder_name=$(get_incremented_folder_name "$old_folder_name")
mv "$old_folder_name" "$new_old_folder_name"

# Novo nome
echo -e "${GREEN}Digite o novo nome para a pasta (ex: prorrac-v2):${NC}"
read new_folder_name

# Fonte local
echo -e "${GREEN}Digite o caminho da pasta com os arquivos-fonte atualizados:${NC}"
read source_folder
[ -d "$source_folder" ] || { echo -e "${RED}Fonte não encontrada.${NC}"; exit 1; }

# Copiar novo projeto
mkdir "$new_folder_name"
cp -r "$source_folder/"* "$new_folder_name"

print_banner

# Copiar arquivos de configuração
cp "$new_old_folder_name/backend/.env" "$new_folder_name/backend/.env"
cp "$new_old_folder_name/frontend/.env" "$new_folder_name/frontend/.env"
cp "$new_old_folder_name/frontend/server.js" "$new_folder_name/frontend/server.js"

print_banner

# Backend
echo -e "${GREEN}Instalando e buildando backend...${NC}"
cd "$deploy_path/$new_folder_name/backend"
npm install
npm run build
npx sequelize db:migrate

print_banner

# Frontend
echo -e "${GREEN}Instalando e buildando frontend...${NC}"
cd "$deploy_path/$new_folder_name/frontend"
npm install
npm run build

print_banner

# Edição manual (opcional)
echo -e "${GREEN}Abrindo arquivos para edição opcional:${NC}"
nano package.json
nano public/index.html

print_banner

# Reiniciar PM2
echo -e "${GREEN}Reiniciando o PM2...${NC}"
sudo su deploy -c "pm2 restart all"

print_banner

echo -e "${RED}Se necessário, mova a pasta 'public' manualmente.${NC}"

print_banner

echo -e "${GREEN}✅ Script finalizado com sucesso!${NC}"
echo -e "${GREEN}
📌 Comandos úteis pós-deploy:

npm install (backend)
npm run build (backend)
npx sequelize db:migrate

npm install (frontend)
npm run build

pm2 restart all
${NC}"

# Contato
echo -e "${GREEN}Sites e Suporte:${NC}"
echo -e "${GREEN}🌐 www.prorrac.online${NC}"
echo -e "${GREEN}🌐 vip.prorrac.online${NC}"
echo -e "${GREEN}📞 Suporte disponível no site.${NC}"
