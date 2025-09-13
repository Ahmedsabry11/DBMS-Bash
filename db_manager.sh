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

    if touch $data_path && touch $schema_path 2>/dev/null; then
      display "created table ${table_name}!" "g"
    else
      display "Failed to create table $table_name files" "r"
    fi
  else
    display "Failed to create table $table_name directory" "r"
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
}

list_tables () {
	display "Tables List:"
  ls -l | grep '^d' | awk '{print $9}'  # list directories only
}

drop_table () {
	display "Drop Table:"
  read table_name
  if [ -d "$table_name" ]; then
    rm -r "$table_name"
    display "Table $table_name dropped successfully!" "g"
  else
    display "Table $table_name does not exist!" "r"
  fi
}

insert_into_table () {
	display "insert_into_table"
}
display_read_columns() {
	local -n cols=$1
	display "Columns:" "g"
	for i in "${!cols[@]}";do
		echo "$((i+1)) : ${cols[i]}"
	done
	display "Enter columns to select:"
	display "Use '*' for all columns, or comma-separated numbers"
	read selected
	return "$selected"
}

check_columns() {
	local -n cols=$1
	local total=$2  
	if [[ ${#cols[@]} == 1 ]]; then
		if [[ "${cols[0]}" == "*" ]]; then
			return 0
		elif [[ "${cols[0] =~ ^[0-9]+$}" ]] && (( cols[0] >= 1 && cols[0] <= total )); then
			return 0
		else
			return 1
		fi
	fi
	
	seen=()
	for col in "${cols[@]}"; do
		if [[ ! "$col" =~ ^[0-9]+$ ]]; then
			return 1
		fi
		
		if (( col < 1 || col > total )); then
			return 1
		fi
		
		if [[ " ${seen[*]} " =~ " $col " ]]; then
			return 1
		fi
		
		seen+=("$col")
	done
	
	return 0
}
select_from_table () {
	display "select_from_table"
	display "Enter the table name:" "g"
	read table_name
	display "you chosed"
	while [[ ! -d $table_name ]]; do
		display "Table '$table_name' does not exist." "r"
		display "Enter a valid table name:"
		read table_name
	done
	
	schema_file="$table_name/schema"
    	data_file="$table_name/data"
    	
	columns=($(cut -d, -f1 "$schema_file"))
	
	selected=$(display_read_columns columns)
	selected_cols=($(echo "$selected" | tr -d ' ' | tr ',' ' '))
	while ! check_columns selected_cols "${#columns[@]}"; do
		display "Wrong Selection" "r"
		selected=$(display_read_columns columns)
		selected_cols=($(echo "$selected" | tr -d ' ' | tr ',' ' '))
	done
	
	display "How many rows do you want to display? Enter a number or 'all'." "g"
	read rows
	
	total_rows=$(wc -l < "$data_file")
	
	display "============================================"
	printf "%-5s" "Row"
	for col in ${columns[@]}; do
		printf "%-10s" "$col"
	done
	display "============================================"
	
	if [[ "$rows" == 'all' ]]; then
		row_num=1
		while read -r line; do
			printf "%-5s" "$row_num"
		
			for val in $(echo "$line" | tr ',' ' '); do
				printf "%-10s" "$val"
			done
			
			echo
			((row_num++))
		done < "$data_file"
	fi
}



delete_from_table () {
	display "delete_from_table"
}

update_table () {
	display "update_table"
}

read_constraints() {

  read -p "Do you want to add a WHERE clause? (y/n): " ans
  if [ "$ans" = "y" ]; then
    read -p "Enter condition (e.g., age=20 AND name=Ali): " condition

    # read columns from schema 
    # IFS=',' read -r -a columns < "schema" 
    OLDIFS=$IFS   # Save current value
    columns=()   # column names
    types=() # column types
    keys=()  # column keys (constraints)
    
    schema_file="${table_name}_schema"
    # Read schema line by line
    while IFS=',' read -r cname ctype cconstraint; do
      columns+=("$cname")
      types+=("$ctype")

      # If no constraint → store empty string
      if [[ -z "$cconstraint" ]]; then
        keys+=("NONE")
      else
        keys+=("$cconstraint")
      fi
    done < "$schema_file"

    # print columns for debugging
    for col in "${columns[@]}"; do
      echo "Column: $col"
    done
    IFS=$OLDIFS   # Restore original value


    awk_expr=""
    tokens=($condition)   

    for token in "${tokens[@]}"; do
      if [ "$token" = "AND" ]; then
        awk_expr="$awk_expr &&"
      elif [ "$token" = "OR" ]; then
        awk_expr="$awk_expr ||"
      elif [[ "$token" == *=* ]]; then
        col=$(echo "$token" | cut -d'=' -f1) # column name
        val=$(echo "$token" | cut -d'=' -f2) # value

        # Find column index
        col_index=-1
        for i in "${!columns[@]}"; do
          cname=${columns[$i]}
          if [ "$cname" = "$col" ]; then
            col_index=$((i+1))
            break
          fi
        done

        if [ $col_index -eq -1 ]; then
          echo "Column '$col' not found!"
          return
        fi

        # Append condition to awk expression
        awk_expr="$awk_expr \$${col_index}==\"$val\""
      fi
    done


    # TODO: Print schema
    head -n1 "${table_name}_schema" | column -t -s','

    # use awk to filter rows based on the condition
    awk -F',' "($awk_expr)" "${table_name}_data" | column -t -s','

  else
    # Show all
    column -t -s',' "${table_name}_data" | less
  fi
}

# DB manager menu
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
