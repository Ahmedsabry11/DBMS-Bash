#!/bin/bash

# setup prompt & colors
# PS3=":: "
NC='\033[0m' # no-color (dafault)
RED='\033[0;31m'
GREEN='\033[0;32m'

# helper functions
display() {
  # no. of args and behavior:
    # 1 arg:   'statement' to print
    # 2 arg:   'statement' and 'color' (either 'r' for red, 'g' for green)

  if [ $# -gt 2 ] || [ $# -eq 0 ]; then
    echo "Invalid no. of arguments"
    return
  fi

  if [ $# -eq 1 ]; then
    # print statement
    echo "$1"
  fi

  if [ $# -eq 2 ]; then
    case $2 in
      "r")
        echo -e "${RED}$1${NC}"
        ;;
      "g")
        echo -e "${GREEN}$1${NC}"
        ;;
      *)
        echo "Invalid color option"
        break
        ;;
    esac
  fi
}

display_menu() {
  # accepts only one argument: an array of menu options
  if [ $# -ne 1 ]; then
    display "Invalid no. of arguments" "r"
    return
  fi
  
  local -n menu=$1  # refence to the passed array

  # print menu options (loop over indices)
  for i in "${!menu[@]}"; do
    display "$((i+1)). ${menu[$i]}"
  done
}

# ---------------------------------------------------------------------
# functions
create_db() {
  display "Enter the DB name" "g"
  read db_name

  while [ -e $db_name ]; do
    display "A database with this name already exists!" "r"
    display "Enter the DB name" "g"
    read db_name
  done

  if mkdir $db_name 2>/dev/null; then
    display "Database created successfully" "g"
  else
    display "Failed to create database '$db_name'" "r"
  fi
}

list_dbs() {
  display "List of databases:" "g"
  # -d: list directories only, not their contents
  # '*/': match only directories
  if ! ls -d */ 2>/dev/null; then
    display "No databases found" "r"
  fi
}

connect_db() {
  display "Enter the DB name" "g"
  read db_name

  # check if db exists 
  while [ ! -e $db_name ]; do
    display "A database with this name does not exist!" "r"
    display "Enter the DB name" "g"
    read db_name
  done

	
  # connect to the db (change directory)
  if cd $db_name 2>/dev/null; then
    # call the table menu script. for (DDL and DML) operations
    # 'source' to run in the same shell to access its variables & functions
    display "Connecting to database..." "g"

		# we must use '../' because source looks for db_manager.sh in cur directory (which is changed after 'cd db_name/')
    if source ../db_manager.sh 2>/dev/null; then
      display "Disconnected from database '$db_name'" "g"
      display "🔁 back to 'dbms' script" "g"
      cd ..   # go out after cd (cause error -> create db in db)
    else
      display "Failed to run db_manager" "r"
    fi
  else
    display "Failed to connect to database '$db_name'" "r"
  fi
}

drop_db() {
  display "Enter the DB name" "g"
  read db_name

  # check if db exists 
  while [ ! -e $db_name ]; do
    display "A database with this name does not exist!" "r"
    display "Enter a valid DB name. or -1 to exit" "g"
    read db_name

		# i don't want to drop a db
    if [ "$db_name" = "-1" ]; then
			return
		fi

  done

  if rm -r $db_name 2>/dev/null; then
    display "Database '$db_name' dropped successfully" "g"
  else
    display "Failed to drop database '$db_name'" "r"
  fi
}


# --------------------------------- start ----------------------------------
display "Welcome to our DBMS, wish you have a nice experience" "g"

# main menu
main_menu=("Create DB" "List DBs" "Connect to DB" "Drop DB" "Exit")

while true; do
  display_menu main_menu
  read -p "Enter your choice: " choice

  case $choice in
    1)
			create_db
			;;

    2)
      list_dbs
      ;;

    3)
      connect_db
      ;;

    4)
      drop_db
      ;;

    5)
      display "Thank you for using our DBMS :)" "g"
      exit
      ;;

    *)
      display "Invalid Choice" "r"
      ;;
  esac

  display ""
done