#!/bin/bash

display "Hi! (DB manager)" "g"

# Functions ------------------------------------------------------------------------------------------------------
create_table () {
	display "create_table"
}

list_tables () {
	display "list_tables"
}

drop_table () {
	display "drop_table"
}

insert_into_table () {
	display "insert_into_table"
}

select_from_table () {
	display "select_from_table"
}

delete_from_table () {
	display "delete_from_table"
}

update_table () {
	display "update_table"
}

# DB mangaer menu
db_manager_menu=("Create Table" "List Tables" "Drop Table" "Insert Into Table" "Select From Table" "Delete From Table" "Update Table" "Exit")

while true; do
  display_menu db_manager_menu
  read -p "Enter your choice: " choice

  case $choice in
    1)
			create_table
			;;

    2)
      list_tables
      ;;

    3)
      drop_table
      ;;

    4)
      insert_into_table
      ;;

    5)
			select_from_table
			;;
		
		6)
			delete_from_table
			;;

		7)
			update_table
			;;

		8)
      display "Thank you! (DB manager)" "g"
      return		# don't exit (return to main script)
      ;;

    *)
      display "Invalid Choice" "r"
      ;;
  esac

  display ""
done