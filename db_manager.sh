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

check_columns() {
    array_name="$1"   # name of the array (e.g. "selected_cols")
    total=$2          # total number of schema columns
    eval "cols=( \"\${${array_name}[@]}\" )"

    # case 1: single selection
    if [[ ${#cols[@]} -eq 1 ]]; then
        if [[ "${cols[0]}" == "*" ]]; then
            return 0
        elif [[ "${cols[0]}" =~ ^[0-9]+$ ]] && (( cols[0] >= 1 && cols[0] <= total )); then
            return 0
        else
            return 1
        fi
    fi

    # case 2: multiple selections
    seen=()
    for col in "${cols[@]}"; do
        # 🔹 fix: allow '*' if user mistakenly typed it with others
        if [[ "$col" == "*" ]]; then
            return 1   # '*' is only valid when it's the only input
        fi

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

read_constraints() {

  read -p "Do you want to add a WHERE clause? (y/n): " ans
  if [[ "$ans" == "y" ]]; then
    read -p "Enter condition (e.g., age=20 AND name=Ali): " condition

    # read columns from schema 
    # IFS=',' read -r -a columns < "schema" 
    OLDIFS=$IFS   # Save current value
    columns=()   # column names
    types=() # column types
    keys=()  # column keys (constraints)
    
    schema_file="${table_name}/${table_name}_schema"
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
    head -n1 "${table_name}/${table_name}_schema" | column -t -s','

    # use awk to filter rows based on the condition
    awk -F',' "($awk_expr)" "${table_name}/${table_name}_data" | column -t -s','

  else
    # Show all
    column -t -s',' "${table_name}/${table_name}_data" | less
  fi
}

select_from_table () {
	display "select_from_table"
	display "Enter the table name:" "g"
	read table_name
	
	while [[ ! -d $table_name ]]; do
		display "Table '$table_name' does not exist." "r"
		display "Enter a valid table name:"
		read table_name
	done
	
	schema_file="${table_name}/${table_name}_schema"
    data_file="${table_name}/${table_name}_data"
    	
	columns=($(cut -d, -f1 "$schema_file"))
	
	display "Columns:" "g"
    	for i in "${!columns[@]}"; do
        	echo "$((i+1)) : ${columns[i]}"
    	done
    	
    	echo "Enter columns to select:"
    	echo "Use '*' for all columns, or comma-separated numbers"
    	read selected
	#selected_cols=($(echo "$selected" | tr -d ' ' | tr ',' ' '))
	# normalize input: remove CR (Windows) and spaces
	selected="${selected//$'\r'/}"
	selected="${selected// /}"

	# split into array on commas (safe)
	IFS=',' read -r -a selected_cols <<< "$selected"
	
	while ! check_columns selected_cols "${#columns[@]}"; do
		display "Wrong Selection" "r"
		echo "Enter columns to select:"
        	echo "Use '*' for all columns, or comma-separated numbers"
        	read selected
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
	echo
	display "============================================"
	row_num=1
	if [[ "$rows" == 'all' ]]; then
		
		while read -r line; do
			printf "%-5s" "$row_num"
		
			vals=($(echo "$line" | tr ',' ' '))
            		if [[ "${selected_cols[0]}" == "*" ]]; then
                		for val in "${vals[@]}"; do
                    			printf "%-10s" "$val"
                		done
            		else
                		for idx in "${selected_cols[@]}"; do
                    			printf "%-10s" "${vals[$((idx-1))]}"
                		done
            		fi

            		echo
            		((row_num++))
        	done < "$data_file"
	
	elif [[ "$rows" =~ ^[0-9]+$ ]]; then
        	while read -r line && (( row_num <= rows )); do
            		printf "%-5s" "$row_num"

            		vals=($(echo "$line" | tr ',' ' '))
            		if [[ "${selected_cols[0]}" == "*" ]]; then
                		for val in "${vals[@]}"; do
                    			printf "%-10s" "$val"
                		done
            		else
                		for idx in "${selected_cols[@]}"; do
                    			printf "%-10s" "${vals[$((idx-1))]}"
                		done
            		fi

            		echo
            		((row_num++))
        	done < "$data_file"
    	fi
}


delete_from_table () {
	display "Delete Record"
  display "Enter the table name:" "g"
  read table_name

  while [[ ! -d $table_name ]]; do
    display "Table '$table_name' does not exist." "r"
    display "Enter a valid table name or -1 to exit:"
    read 
    if [[ "$table_name" == "-1" ]]; then
      return
    fi
  done

  echo $table_name ;
  schema_file="${table_name}/${table_name}_schema"
  data_file="${table_name}/${table_name}_data"

  echo "call read constrains"
  # delete records with conditions
  read_constraints

  echo "preform delete "
  # use awk to delete rows based on the condition
  awk -F',' "!($awk_expr)" "${data_file}" > "${data_file}.tmp" && mv "${data_file}.tmp" "${data_file}"

  display "Records deleted successfully." "g"
}

update_table () {
	display "update_table"
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
