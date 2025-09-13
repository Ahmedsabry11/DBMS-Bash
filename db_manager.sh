#!/bin/bash

display "Hi! (DB manager)" "g"

# helper functions
validate_table_name() {
  while [ -e $table_name ]; do
    display "Can't have more than 1 table with the same name!" "r"
    display "Enter a valid DB name. or -1 to exit" "g"
    read table_name

    # i don't want to create the table
		if [ "$table_name" = "-1" ]; then
			return 1    # the the caller we want to exit
		fi
  done
}

create_table_files() {
  # create the table directory
  if mkdir $table_name 2>/dev/null; then
    # create the data & schema files
    schema_path="${table_name}/${table_name}_schema"
    data_path="${table_name}/${table_name}_data"

    if touch "$data_path" "$schema_path" 2>/dev/null; then
      display "created table ${table_name}!" "g"
    else
      display "Failed to create table $table_name files" "r"
    fi
  else
    display "Failed to create table $table_name directory" "r"
  fi
}

set_col_name() {
  # make sure the column name is valid (only ^[a-zA-Z_]+$)
  col_name_regex="^[a-zA-Z_]+$"

  # to avoid making more than 1 pk, we take it first
  if [ "$pk_flag" = "0" ]; then
    display "Enter the primary key column name" "g"
  else
    display "Enter the column name. or -1 to stop" "g"
  fi

  display "Characters and underscores only allowed" "g"
  read cur_col_name

  # while it doesn't match the regex
  while [[ ! $cur_col_name =~ $col_name_regex ]]; do
    # i don't want to create the table
    # avoid entering -1 in pk col => create empty table
    if [ "$cur_col_name" = "-1" -a "$pk_flag" != "0" ]; then
			return 1    # the the caller we want to exit
		fi

    display "Name is invalid. characters or underscores only allowed" "r"
    display "Enter a valid column name. or -1 to stop" "g"
    read cur_col_name
  done
}

validate_col_number() {
  # we can use [ -a ] or [[ && ]] to express and logical operation
  while [ $cur_col_no != "1" -a $cur_col_no != "2" ]; do
    display "Invalid number. Enter 1, or 2" "r"
    read cur_col_no
  done
}

get_col_dt () {
  # after this call cur_col_no is "1", or "2"
  validate_col_number    

  # set real column data type
  if [ $cur_col_no = "1" ]; then
    cur_col_dt="number"
  else
    cur_col_dt="string"
  fi
}

get_col_constraints() { 
  # this function fills "cur_col_con" with cur_col_dt constraints
  while [ "$cur_col_dt" != "number" -a "$cur_col_dt" != "string" ]; do
    display "Invalid column data type. can't make constraints" "r"
    read cur_col_dt
  done

  # fill column
  numbers_con=("gt" "ls" "eq")
  basic_con=("unique" "not null")

  # apply basic constraints (if not pk => already unique + not null)
  if [ "$pk_flag" = "0" ]; then
    for con in "${basic_con[@]}"; do
      cur_col_con+="$con,"
    done
  else
    for con in "${basic_con[@]}"; do
      display "Enter lowercase (y or n) to apply make the column $con" "g"
      read user_choice
      if [ $user_choice = "y" ]; then
        cur_col_con+="$con,"
      fi
    done
  fi

  # apply specific number data type constraints
  if [ $cur_col_dt = "number" ]; then
    for con in "${numbers_con[@]}"; do
      display "Enter lowercase (y or n) to apply '$con' constraint on the column" "g"
      read user_choice    # gt, le, eq => must specify a value
      if [ $user_choice = "y" ]; then
        display "Enter the value (integer)" "g"
        read con_value
        cur_col_con+="${con}-${con_value},"
      fi
    done
  fi
}

# ------------------------------------------------------------------------------------------------------
# functions 
create_table () {
	# 1. get the table name and verify no other tables with the same name
  display "Enter the table name" "g"
  read table_name

  # avoid having 2 tables with the same name
  if ! validate_table_name; then
    return
  fi

  # 2. create a dir for the table with 2 files (schema, data)
  create_table_files
  
  # 3. get columns and conditions (table structure)
  pk_flag=0   # false, not read yet
  display "Enter the columns and their conditions. one by one" "g"
  while true; do
    cur_col_name=""
    
    # TODO: make sure name is not repeated
    # if -1 returned stop reading more columns
    if ! set_col_name; then
      return
    fi
    

    # read the cur_col_name data type (number, or str)
    display "Enter a number to choose column data type" "g"
    display "1. number" "g"
    display "2. string" "g"

    read cur_col_no

    cur_col_dt=""   # filled with the data type

    # given cur_col_no. the following function will make sure it's
    # valid, then set cur_col_dt to "number" or "string"
    get_col_dt   

    # display specific data type constraints
    cur_col_con=""
    get_col_constraints;

    # if it's the pk
    if [ "$pk_flag" = "0" ]; then
      pk_flag=1
    fi

    # remove trailing ',' from cur_col_con
    cur_col_con=${cur_col_con::-1}
    record="$cur_col_name,$cur_col_dt,$cur_col_con"
    display "$record" "r"

    # TODO: append to schema file "col_name,col_dt,col_con"

  done
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