#!/bin/bash

# Solicita nome do banco
read -rp "Digite o nome do banco de dados para backup: " DATABASE

# Solicita diretório de destino
read -rp "Digite o diretório onde salvar o backup (pressione Enter para usar /tmp): " BACKUP_DIR
BACKUP_DIR=${BACKUP_DIR:-/tmp}

# Verifica permissão de escrita
if [ ! -w "$BACKUP_DIR" ]; then
  echo "Sem permissão para gravar em '$BACKUP_DIR'. Usando /tmp."
  BACKUP_DIR="/tmp"
fi

# Gera nome do arquivo
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DATABASE}_backup_${TIMESTAMP}.sql.gz"

# Executa backup como postgres
echo "Iniciando backup para $BACKUP_FILE ..."
su - postgres -c "pg_dump $DATABASE | gzip > '$BACKUP_FILE'"

if [[ $? -eq 0 ]]; then
  echo "✅ Backup concluído com sucesso: $BACKUP_FILE"
else
  echo "❌ Erro ao realizar o backup."
  exit 1
fi
