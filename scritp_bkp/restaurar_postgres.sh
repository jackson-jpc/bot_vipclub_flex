#!/bin/bash

# Solicita nome do banco
read -rp "Digite o nome do banco de dados a ser restaurado: " DATABASE

# Solicita caminho do backup
read -rp "Digite o caminho completo do arquivo de backup (.sql.gz): " BACKUP_FILE

# Verifica se o arquivo existe
if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ Arquivo '$BACKUP_FILE' não encontrado."
  exit 1
fi

# Cria banco se não existir
echo "Verificando existência do banco '$DATABASE'..."
su - postgres -c "psql -tc \"SELECT 1 FROM pg_database WHERE datname = '$DATABASE'\" | grep -q 1"
if [[ $? -ne 0 ]]; then
  echo "Banco não existe. Criando..."
  su - postgres -c "createdb $DATABASE"
fi

# Executa restauração
echo "Restaurando backup..."
su - postgres -c "gunzip -c '$BACKUP_FILE' | psql $DATABASE"

if [[ $? -eq 0 ]]; then
  echo "✅ Restauração concluída com sucesso!"
else
  echo "❌ Erro ao restaurar o backup."
  exit 1
fi
