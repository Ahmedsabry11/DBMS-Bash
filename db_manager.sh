#!/bin/bash

display "Hi! (DB manager)" "g"

# helper functions
validate_table_name() {
  while [ -e $table_name ]; do
    display "Can't have more than 1 table with the same name!" "r"
    display "Enter a valid table name. or -1 to exit" "g"
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

  while true; do
    # flag to check if column name is repeated
    found=false

    for prev_name in "${prev_cols[@]}"; do
      if [ "$prev_name" = "$cur_col_name" ]; then
        found=true
        break
      fi
    done

    if [ "$found" = true ]; then
      display "This column name is used before. Enter another valid column name" "r"
      read cur_col_name
    else
      prev_cols+=("${cur_col_name}")
      break
    fi
  done

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
  numbers_con=("gt" "ls")
  basic_con=("unique" "not null")

  # apply basic constraints (if not pk => already unique + not null)
  if [ "$pk_flag" = "0" ]; then
    for con in "${basic_con[@]}"; do
      cur_col_con+="$con,"
    done
  else
    for con in "${basic_con[@]}"; do
      display "Enter lowercase (y or n) to apply ($con) constraint on the column" "g"
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
      read user_choice    # gt, le => must specify a value
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
  # after this call, we have access to 2 variable that represnet the path to table files ('$schema_path', '$data_path')
  create_table_files
  
  # 3. get columns and conditions (table structure)
  pk_flag=0   # false, not read yet
  display "Enter the columns and their conditions. one by one" "g"

  # store previous column names to make sure coming ones don't have the same name
  prev_cols=()
    
  while true; do
    cur_col_name=""


    # if -1 returned stop reading more columns
    if ! set_col_name; then
      break
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
    # if cur_col_con is empty, the slicing will cause an error (script crash and return)
    # so, we must check the len > 0
    if [ -n "$cur_col_con" ]; then    # also works ==> if [ ${#cur_col_con} -gt 0 ]
      cur_col_con=${cur_col_con::-1}
    fi

    record="$cur_col_name,$cur_col_dt,$cur_col_con"

    # try to append the table meta-date in the file
    if echo  "$record" >> "$schema_path"; then
      display "Column data saved successfully" "g"
    else
      display "Failed to column meta-data" "r"
    fi

  done

  display "Table created successfull" "g"
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

read_schema() {
    table_name="$1"
    schema_path="${table_name}/${table_name}_schema"
    if [ ! -f "$schema_path" ]; then
        display "Schema file not found!" "r"
        return 1
    fi
    DB_COLUMNS=()
    DB_TYPES=()
    DB_CONSTRAINTS=()
    while IFS=',' read -r col_name col_type rest; do
        [ -z "$col_name" ] && continue
        DB_COLUMNS+=("$col_name")
        DB_TYPES+=("$col_type")
        constraints="$(echo "$rest" | sed 's/^,//')"
        DB_CONSTRAINTS+=("$constraints")
    done < "$schema_path"
    return 0
}

check_unique_value() {
    table_name="$1"
    column_name="$2"
    value="$3"
    data_path="${table_name}/${table_name}_data"
    col_pos=1
    for i in "${!DB_COLUMNS[@]}"; do
        if [ "${DB_COLUMNS[$i]}" = "$column_name" ]; then
            col_pos=$((i + 1))
            break
        fi
    done
    if [ ! -f "$data_path" ] || [ ! -s "$data_path" ]; then
        return 0
    fi
    if cut -d',' -f"$col_pos" "$data_path" | grep -Fxq "$value"; then
        return 1
    else
        return 0
    fi
}


insert_data() {
    display "Enter the table name" "g"
    read table_name
    if [ ! -d "$table_name" ]; then
        display "Table not found!" "r"
        return
    fi
    if ! read_schema "$table_name"; then
        return
    fi

    values=()
    for i in "${!DB_COLUMNS[@]}"; do
        col_name="${DB_COLUMNS[$i]}"
        col_type="${DB_TYPES[$i]}"
        constraints="${DB_CONSTRAINTS[$i]}"

        while true; do
            display "Enter value for '$col_name' ($col_type):" "g"
            read value
            valid=true

            # Type validation
            case "$col_type" in
                int|number)
                    if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
                        valid=false
                        display "Invalid input: expected an integer" "r"
                        continue
                    fi
                    ;;
            esac

            # Constraints validation
            if [ -n "$constraints" ]; then
                IFS=',' read -ra constraint_list <<< "$constraints"
                for constraint in "${constraint_list[@]}"; do
                    case "$constraint" in
                        "not null") [ -z "$value" ] && valid=false && break ;;
                        "unique") if ! check_unique_value "$table_name" "$col_name" "$value"; then valid=false && break; fi ;;
                        gt-*) min_val="${constraint#gt-}"; [ "$value" -le "$min_val" ] && valid=false && break ;;
                        ls-*) max_val="${constraint#ls-}"; [ "$value" -ge "$max_val" ] && valid=false && break ;;
                    esac
                done
            fi

            if $valid; then
                break
            else
                display "Invalid value" "r"
            fi
        done

        values+=("$value")
    done

    data_path="${table_name}/${table_name}_data"
    row_data=$(IFS=','; echo "${values[*]}")
    echo "$row_data" >> "$data_path"
    display "Row inserted: $row_data" "g"
}


check_columns() {
    local -n cols="$1"
  
    total=$2          # total number of schema columns
    

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

	display "Do you want to add a WHERE clause? (y/n):"
  read ans
  if [[ "$ans" == "y" ]]; then
    display "Enter condition (e.g., age=20 AND name=Ali): "
    read condition

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
      if [[ "$token" =~ ^(AND|and)$ ]]; then
        awk_expr="$awk_expr &&"
      elif [[ "$token" =~ ^(OR|or)$ ]]; then
        awk_expr="$awk_expr ||"
      elif [[ "$token" == *">="* ]]; then
        col=$(echo "$token" | cut -d'>' -f1 ) # column name
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
        awk_expr="$awk_expr \$${col_index}>=$val"
      elif [[ "$token" == *"<="* ]]; then
        col=$(echo "$token" | cut -d'<' -f1) # column name
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
        awk_expr="$awk_expr \$${col_index}<=$val"
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
      elif [[ "$token" == *">"* ]]; then
        col=$(echo "$token" | cut -d'>' -f1) # column name
        val=$(echo "$token" | cut -d'>' -f2) # value

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
        awk_expr="$awk_expr \$${col_index}>$val"
      elif [[ "$token" == *"<"* ]]; then
        col=$(echo "$token" | cut -d'<' -f1) # column name
        val=$(echo "$token" | cut -d'<' -f2) # value

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
        awk_expr="$awk_expr \$${col_index}<$val"
      
      else
        echo "Invalid token: $token"
        return
      fi
    done


    # return awk_expr to caller to use it in filtering
    echo "AWK expression: $awk_expr"
    export awk_expr

    # # TODO: Print schema
    # head -n1 "${table_name}/${table_name}_schema" | column -t -s','

    # # use awk to filter rows based on the condition
    # awk -F',' "($awk_expr)" "${table_name}/${table_name}_data" | column -t -s','

  else
    awk_expr="1"  # no filtering, select all rows
    export awk_expr
  fi
}

select_from_table() {
    display "select_from_table"
    display "Enter the table name:" "g"
    read table_name

    while [[ ! -d $table_name ]]; do
        display "Table '$table_name' does not exist." "r"
        display "Enter a valid table name:" "g"
        read table_name
    done

    local schema_file="${table_name}/${table_name}_schema"
    local data_file="${table_name}/${table_name}_data"

    # Read column names from schema
    columns=($(cut -d',' -f1 "$schema_file"))
    

    display "Columns:" "g"
    for i in "${!columns[@]}"; do
        echo "$((i+1)) : ${columns[i]}"
    done

    display "Enter columns to select:"
    display "Use '*' for all columns, or comma-separated numbers"
    read selected
    
    selected="${selected// /}"

    IFS=',' read -a selected_cols <<< "$selected" 

    while ! check_columns selected_cols "${#columns[@]}"; do
        display "Wrong Selection" "r"
        display "Enter columns to select:" "g"
        read selected
        selected="${selected// /}"
        IFS=',' read -a selected_cols <<< "$selected"
    done

    # Use a unique temporary file
    tmp_file="/tmp/filtered_rows.txt"
    read_constraints
    awk -F',' "($awk_expr)" "$data_file" > "$tmp_file"
    display "How many rows do you want to display? Enter a number or 'all'." "g"
    read rows

    display "============================================"
    printf "%-5s" "Row"
    if [[ "${selected_cols[0]}" == "*" ]]; then
        for col in "${columns[@]}"; do
            printf "%-10s" "$col"
        done
    else
        for idx in "${selected_cols[@]}"; do
            printf "%-10s" "${columns[idx-1]}"
        done
    fi
    echo
    display "============================================"

    # Print rows
    row_num=1
    if [[ "$rows" == "all" ]]; then
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
        done < "$tmp_file"
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
        done < "$tmp_file"
    fi

    rm -f "$tmp_file"
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
  # read_constraints will fill awk_expr variable
  export awk_expr=""
  read_constraints
  echo "AWK expression received: $awk_expr"

  echo "preform delete "
  # use awk to delete rows based on the condition
  awk -F',' "!($awk_expr)" "${data_file}" > "${data_file}.tmp" && mv "${data_file}.tmp" "${data_file}"

  # delete the temp file if it exists
  [ -f "${data_file}.tmp" ] && rm "${data_file}.tmp"
  display "Records deleted successfully." "g"
}

update_data() {
    display "Enter the table name" "g"
    read table_name
    if [ ! -d "$table_name" ]; then
        display "Table not found!" "r"
        return
    fi
    if ! read_schema "$table_name"; then
        return
    fi

    data_path="${table_name}/${table_name}_data"
    if [ ! -s "$data_path" ]; then
        display "Table is empty!" "g"
        return
    fi

    read_constraints

    display "Enter column to update:" "g"
    read update_col
    update_pos=-1
    for i in "${!DB_COLUMNS[@]}"; do
        if [ "${DB_COLUMNS[$i]}" = "$update_col" ]; then
            update_pos=$((i+1))
            # Block update if it's the first column (primary key)
            if [ "$i" -eq 0 ]; then
                display "Error: Cannot update the primary key column!" "r"
                return
            fi
            break
        fi
    done
    [ "$update_pos" -eq -1 ] && display "Column not found!" "r" && return

    # Ask for new value with validation
    valid=false
    while [ "$valid" = false ]; do
        display "Enter new value for '$update_col':" "g"
        read new_value
        valid=true

        # --- Type check ---
        if [ "${DB_TYPES[$((update_pos-1))]}" = "number" ]; then
            if ! [[ "$new_value" =~ ^-?[0-9]+$ ]]; then
                display "Invalid input: expected a number" "r"
                valid=false
                continue
            fi
        fi

        # --- Constraint checks ---
        constraints="${DB_CONSTRAINTS[$((update_pos-1))]}"
        IFS=',' read -ra constraint_list <<< "$constraints"
        for constraint in "${constraint_list[@]}"; do
            case "$constraint" in
                "not null")
                    if [ -z "$new_value" ]; then
                        display "Constraint failed: value cannot be null" "r"
                        valid=false
                        break
                    fi
                    ;;
                "unique")
                    # Ensure value is not duplicated (ignore rows being updated by awk_expr)
                    if awk -F',' -v col="$update_pos" -v val="$new_value" \
                        -v cond="$awk_expr" '
                        $col == val && !(cond) {exit 1}' "$data_path"
                    then
                        : # ok
                    else
                        display "Constraint failed: '$new_value' already exists" "r"
                        valid=false
                        break
                    fi
                    ;;
                gt-*)
                    min_val="${constraint#gt-}"
                    if [ "$new_value" -le "$min_val" ]; then
                        display "Constraint failed: must be greater than $min_val" "r"
                        valid=false
                        break
                    fi
                    ;;
                ls-*)
                    max_val="${constraint#ls-}"
                    if [ "$new_value" -ge "$max_val" ]; then
                        display "Constraint failed: must be less than $max_val" "r"
                        valid=false
                        break
                    fi
                    ;;
            esac
        done
    done

    # Safe update with tmp file
    tmp="${data_path}.tmp"
    awk -F',' -v OFS=',' -v upos="$update_pos" -v nval="$new_value" \
        "($awk_expr){\$upos=nval} {print}" "$data_path" > "$tmp" && mv "$tmp" "$data_path"

    display "Update complete" "g"
    cat "$data_path"
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
      insert_data
      ;;

    5)
			select_from_table
			;;
		
		6)
			delete_from_table
			;;

		7)
			update_data
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
