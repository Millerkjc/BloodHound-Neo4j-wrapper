#!/bin/bash

# https://itecnote.com/tecnote/error-occurs-when-creating-a-new-database-under-neo4j-4-0/

dbDataPath="/usr/share/neo4j/data/databases"
transationPath="/usr/share/neo4j/data/transactions"
configPath="/etc/neo4j"

toolName=$(basename "$0")
# toolPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
toolPath="$(realpath "$toolName" | rev | cut -d "/" -f 2- | rev)"
configFile="$configPath/neo4j.conf"
configString="dbms.default_database"
stateFile="$toolPath/db.json"
ACTION="$1"

function showHelp() {
    cat <<END

Setup tool:
    ./$(basename "$0") setup
Show this menu:
    bh-neo4j-wrapper.sh help
List DB:
    bh-neo4j-wrapper.sh list
Use a DB:
    bh-neo4j-wrapper.sh run dbname (will create one if doesn't exist)
Remove DB:
    bh-neo4j-wrapper.sh rm dbname
Import JSON files or ZIP:
    bh-neo4j-wrapper.sh import <neo4j_user> <neo4j_password> /path/to/bhoutput json (will import the data to the current DB)
    bh-neo4j-wrapper.sh import <neo4j_user> <neo4j_password> /path/to/bhoutput zip sudo (will import the data to the current DB using docker with sudo)

Ex: bh-neo4j-wrapper.sh run neo4j

END
}

function checkSudo() {
  if groups | grep "\<sudo\>" &> /dev/null; then
   echo "User is in sudo group, we can continue" &> /dev/null
  else
   echo "[x] This script must be run using a user with sudo privileges"
   exit 1
  fi
}

function setupTool() {
  checkSudo
  if [[ -f "/usr/local/bin/$toolName" ]]; then
    echo "Already set"
    exit 1
  else
    fullPath=$(realpath "$toolName")
    sudo ln -s "$fullPath" "/usr/local/bin/$toolName"
    echo "[*] Tool is set"
  fi
}

function checkRequirements() {
  if ! [ -x "$(command -v jq)" ]; then
    echo "jq is not installed"
    exit 1
  fi
  if ! [ -x "$(command -v sponge)" ]; then
    echo "moreutils is not installed"
    exit 1
  fi
  if ! [ -x "$(command -v tmux)" ]; then
    echo "tmux is not installed"
    exit 1
  fi
  if ! [ -x "$(command -v neo4j)" ]; then
    echo "neo4j is not installed"
    exit 1
  fi
  if ! [ -x "$(command -v bloodhound)" ]; then
    echo "bloodhound is not installed"
    exit 1
  fi
}

function checkDocker() {
  # if action is import
  if ! [ -x "$(command -v docker)" ]; then
    echo "Docker is not installed. Please install docker to use the import feature."
    exit 1
  fi
}

function checkBHdata() {
  if [[ -d "bhdata" ]]; then
    rm -rf bhdata
    mkdir bhdata
  else
    mkdir bhdata
  fi
}

function importBHdata() {
  echo "Import BH data using https://github.com/som3canadian/bloodhound-import"
  checkBHdata
  imageName="ghcr.io/som3canadian/bloodhound-import:master"
  if [[ -z "$2" ]]; then
    echo "Please provide the neo4j user"
    exit 1
  fi
  if [[ -z "$3" ]]; then
    echo "Please provide the neo4j password"
    exit 1
  fi
  if [[ -z "$4" ]]; then
    echo "Please provide the path to the BH output"
    exit 1
  fi
  if [[ -z "$5" ]]; then
    echo "Please provide the file extension (json or zip)"
    exit 1
  fi
  if [[ "$5" != "json" && "$5" != "zip" ]]; then
    echo "Please provide the file extension (json or zip)"
    exit 1
  fi
  # copy the data to the bhdata folder
  if [[ "$4" != $(pwd)/bhdata ]]; then
    cp -r "$4"/*."$5" bhdata/
  fi

  if [[ "$6" == "sudo" ]]; then
    echo "Importing data to the current DB using sudo"
    sudo docker pull "$imageName"
    sudo docker run -v $(pwd)/bhdata:/app/bloodhound-import/bhdata --network host -it $(sudo docker images --no-trunc | grep ghcr.io/som3canadian/bloodhound-import | cut -d ':' -f2 | cut -d " " -f1 | head -n 1) -du "$2" -dp "$3" --database "127.0.0.1" bhdata/*.$5
  else
    echo "Importing data to the current DB"
    docker pull "$imageName"
    docker run -v $(pwd)/bhdata:/app/bloodhound-import/bhdata --network host -it $(docker images --no-trunc | grep ghcr.io/som3canadian/bloodhound-import | cut -d ':' -f2 | cut -d " " -f1 | head -n 1) -du "$2" -dp "$3" --database "127.0.0.1" bhdata/*.$5
  fi
}

function checkNeo4j() {
  checkStatusCMD=$(sudo neo4j status)
  if [[ $checkStatusCMD != "Neo4j is not running." ]]; then
    echo "Neo4j is running. Stopping it!"
    sudo neo4j stop
    # more drastic way:
    # neo4jPID=$(echo "$checkStatusCMD" | tr ' ' '\n' | tail -n1)
    # sudo kill -9 "$neo4jPID"
  else
    echo 'Everything is good, neo4j not running' &> /dev/null
  fi
}

function listDB() {
  echo ""
  COUNTER=0
  echo "{\"databases\":[" > "$stateFile"
  for d in "$dbDataPath"/*; do
    dataName=$(echo "$d" | rev | cut -d'/' -f 1 | rev)
    if [[ "$dataName" == "system" ]]; then
      continue
    elif [[ "$dataName" == "store_lock" ]]; then
      continue
    fi
    echo "\"$dataName\"," >> "$stateFile"
    echo "[$COUNTER] $dataName"
    #moving to the next one
    COUNTER=$((COUNTER + 1))
  done
  echo "]}" >> "$stateFile"
  cat  "$stateFile" | tr '\n' ' ' | sed "s/, ]}/ ]}/g" > dbtemp.json
  rm "$stateFile" && mv dbtemp.json "$stateFile"
  jq '.' "$stateFile" | sponge "$stateFile"
}

function settingDB() {
  if [[ -z "$2" ]]; then
    dbName="neo4j"
  else
    dbName="$2"
  fi
  #echo "setting db"
  lastLine=$(tail -n1 "$configFile")
  #echo "$lastLine"
  if [[ "$lastLine" =~ $configString ]]; then
    sudo sed '$d' -i "$configFile"
    echo "$configString=$dbName" | sudo tee -a "$configFile"
  else
    echo "$configString=$dbName" | sudo tee -a "$configFile"
  fi
}

function restartService() {
  echo ""
  sudo neo4j start
  # echo "Waiting 10sec before launching bloodhound"
  # sleep 12
  # tmux new -d -s bloodhound 'bloodhound'
  # tmux ls
  # echo "tmux a -t bloodhound"
  echo ""
  echo "You can now run start bloodhound"
}

function deleteDB() {
  dbName="$2"
  if [[ -d "$dbDataPath/$dbName" ]]; then
    sudo rm -rf "${dbDataPath:?}/${dbName:?}"
    sudo rm -rf "${transationPath}/${dbName:?}"
  else
    echo "DB doesn't exist !"
  fi
  echo "[*] DB delete ! Listing current DB"
}

function cleanFile() {
  if [[ -f "$stateFile" ]]; then
    rm "$stateFile"
  fi
}

case $ACTION in
setup)
  checkSudo
  checkRequirements
  setupTool
  ;;
help)
  showHelp
  ;;
import)
  checkSudo
  checkDocker
  importBHdata "$@"
  cleanFile
  ;;
list)
  listDB
  cleanFile
  ;;
run)
  checkSudo
  checkNeo4j
  listDB
  settingDB "$@"
  restartService
  cleanFile
  ;;
rm)
  checkSudo
  checkNeo4j
  deleteDB "$@"
  listDB
  cleanFile
  ;;
*)
  showHelp
  ;;

esac