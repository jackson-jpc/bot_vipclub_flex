#!/bin/bash

# Define cores
GREEN="\033[32m"
RED="\033[31m"
NC="\033[0m"

# Função para imprimir banner
function print_banner {
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

# Início do script
print_banner
echo -e "${GREEN}AVISO IMPORTANTE: Faça backup e snapshot antes de continuar.${NC}"
read -p "Deseja continuar? [Y/N]: " choice
[[ "$choice" != "Y" && "$choice" != "y" ]] && echo -e "${RED}Operação cancelada.${NC}" && exit 1

print_banner
echo -e "${GREEN}Parando todas as tarefas do PM2...${NC}"
sudo su deploy -c "pm2 stop all"

print_banner
read -p $'\033[32mDigite o caminho do diretório de deploy (ex: /home/deploy):\033[0m ' deploy_path
[ ! -d "$deploy_path" ] && echo -e "${RED}Caminho inválido.${NC}" && exit 1
cd "$deploy_path" || exit 1

print_banner
read -p $'\033[32mDigite o nome da pasta que deseja renomear:\033[0m ' old_folder_name
[ ! -d "$old_folder_name" ] && echo -e "${RED}Pasta não existe.${NC}" && exit 1

print_banner
new_old_folder_name=$(get_incremented_folder_name "$old_folder_name")
mv "$old_folder_name" "$new_old_folder_name"

read -p $'\033[32mDigite o novo nome da pasta:\033[0m ' new_folder_name

print_banner
echo -e "${GREEN}Deseja usar um repositório remoto (Git) ou um caminho local?${NC}"
select option in "Git (repositório público)" "Local (caminho local)"; do
  case $REPLY in
    1)
      read -p $'\033[32mDigite a URL do repositório Git (público):\033[0m ' git_url
      git clone "$git_url" "$new_folder_name" || { echo -e "${RED}Erro ao clonar o repositório.${NC}"; exit 1; }
      break
      ;;
    2)
      read -p $'\033[32mDigite o caminho local do novo projeto:\033[0m ' local_path
      [ ! -d "$local_path" ] && echo -e "${RED}Caminho local inválido.${NC}" && exit 1
      cp -r "$local_path" "$new_folder_name"
      break
      ;;
    *)
      echo -e "${RED}Opção inválida.${NC}"
      ;;
  esac
done

print_banner
cp "$new_old_folder_name/backend/.env" "$new_folder_name/backend/.env"
cp "$new_old_folder_name/frontend/.env" "$new_folder_name/frontend/.env"
cp "$new_old_folder_name/frontend/server.js" "$new_folder_name/frontend/server.js"

# Backend
print_banner
echo -e "${GREEN}Rodando comandos no backend...${NC}"
cd "$deploy_path/$new_folder_name/backend" || exit 1
npm install
npm run build
npx sequelize db:migrate

# Frontend
print_banner
echo -e "${GREEN}Rodando comandos no frontend...${NC}"
cd "$deploy_path/$new_folder_name/frontend" || exit 1
npm install
npm run build

print_banner
echo -e "${GREEN}Abrindo o package.json para edição...${NC}"
nano "$deploy_path/$new_folder_name/frontend/package.json"

print_banner
echo -e "${GREEN}Abrindo index.html para edição...${NC}"
nano "$deploy_path/$new_folder_name/frontend/public/index.html"

print_banner
echo -e "${GREEN}Rodando novamente build do frontend...${NC}"
npm install
npm run build

# PM2
print_banner
echo -e "${GREEN}Reiniciando PM2...${NC}"
sudo su deploy -c "pm2 restart all"

# Final
print_banner
echo -e "${RED}Mova a pasta 'public' para o novo diretório, se necessário.${NC}"
print_banner

echo -e "${GREEN}Script finalizado. Se aconteceu algum erro, entre em contato com o suporte!${NC}"
echo -e "${GREEN}
npm install (No backend)
npm run build (No backend)
npx sequelize db:migrate (No backend)

npm install (No frontend)
npm run build (No frontend)

sudo su deploy
pm2 restart all
${NC}"
echo -e "${GREEN}Sites e Contatos:${NC}"
echo -e "${GREEN}Site: www.plwdesign.online${NC}"
echo -e "${GREEN}Site: vip.plwdesign.online${NC}"

