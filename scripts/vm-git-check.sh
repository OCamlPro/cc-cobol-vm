#!/bin/bash

# Fichier de log
LOG_FILE="${APP_HOME}/FSB/logs/git_update.log"

mkdir -p $(dirname $LOG_FILE)


${APP_HOME}/scripts/vm-build.sh >> $LOG_FILE 2>&1
pkill -HUP superkix

# Fonction principale
while true; do
  cd ${APP_HOME}/cobol_repo

  # Sauvegarder le SHA du dernier commit
  LAST_COMMIT=$(git rev-parse HEAD)

  # Faire un git pull
  echo "Pulling latest changes..." >> $LOG_FILE 2>&1
  git pull >> $LOG_FILE 2>&1

  # Vérifier si un nouveau commit est arrivé
  NEW_COMMIT=$(git rev-parse HEAD)
  if [ "$LAST_COMMIT" != "$NEW_COMMIT" ]; then
    echo "New commit detected: $NEW_COMMIT" >> $LOG_FILE 2>&1
    
    # Recompiler et installer
    echo "Running ./configure && make && make install" >> $LOG_FILE 2>&1
    ${APP_HOME}/scripts/vm-build.sh >> $LOG_FILE 2>&1
    
    if [ $? -eq 0 ]; then
      echo "Build and installation successful." >> $LOG_FILE 2>&1
      pkill -HUP superkix
    else
      echo "Build or installation failed." >> $LOG_FILE 2>&1
    fi
  fi

  # Attendre 10 secondes avant de recommencer
  sleep 10
done
