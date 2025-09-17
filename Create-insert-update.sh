#!/bin/bash

# -------------------------------
# Helper display with colors
display() {
    msg="$1"
    color="$2"
    if [ "$color" = "g" ]; then
        echo -e "\033[32m$msg\033[0m"
    elif [ "$color" = "r" ]; then
        echo -e "\033[31m$msg\033[0m"
    else
        echo "$msg"
    fi
}

# -------------------------------
# CREATE TABLE FUNCTIONS

validate_table_name() {
  while [ -e $table_name ]; do
    display "Can't have more than 1 table with the same name!" "r"
    display "Enter a valid table name. or -1 to exit" "g"
    read table_name
    if [ "$table_name" = "-1" ]; then
        return 1
    fi
  done
}

create_table_files() {
  if mkdir $table_name 2>/dev/null; then
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
  col_name_regex="^[a-zA-Z_]+$"
  if [ "$pk_flag" = "0" ]; then
    display "Enter the primary key column name" "g"
  else
    display "Enter the column name. or -1 to stop" "g"
  fi
  read cur_col_name

  while true; do
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

  while [[ ! $cur_col_name =~ $col_name_regex ]]; do
    if [ "$cur_col_name" = "-1" -a "$pk_flag" != "0" ]; then
        return 1
    fi
    display "Invalid column name. characters or underscores only allowed" "r"
    read cur_col_name
  done
}

validate_col_number() {
  while [ $cur_col_no != "1" -a $cur_col_no != "2" ]; do
    display "Invalid number. Enter 1, or 2" "r"
    read cur_col_no
  done
}

get_col_dt () {
  validate_col_number
  if [ $cur_col_no = "1" ]; then
    cur_col_dt="number"
  else
    cur_col_dt="string"
  fi
}

get_col_constraints() { 
  numbers_con=("gt" "ls")
  basic_con=("unique" "not null")

  if [ "$pk_flag" = "0" ]; then
    for con in "${basic_con[@]}"; do
      cur_col_con+="$con,"
    done
  else
    for con in "${basic_con[@]}"; do
      display "Apply ($con) constraint? (y/n)" "g"
      read user_choice
      if [ $user_choice = "y" ]; then
        cur_col_con+="$con,"
      fi
    done
  fi

  if [ $cur_col_dt = "number" ]; then
    for con in "${numbers_con[@]}"; do
      display "Apply '$con' constraint? (y/n)" "g"
      read user_choice
      if [ $user_choice = "y" ]; then
        display "Enter the value (integer)" "g"
        read con_value
        cur_col_con+="${con}-${con_value},"
      fi
    done
  fi
}

create_table () {
  display "Enter the table name" "g"
  read table_name
  if ! validate_table_name; then
    return
  fi
  create_table_files
  pk_flag=0
  display "Enter columns one by one" "g"
  prev_cols=()
  while true; do
    cur_col_name=""
    if ! set_col_name; then
      break
    fi
    display "Column type? 1=number, 2=string" "g"
    read cur_col_no
    cur_col_dt=""
    get_col_dt
    cur_col_con=""
    get_col_constraints
    if [ "$pk_flag" = "0" ]; then
      pk_flag=1
    fi
    if [ -n "$cur_col_con" ]; then
      cur_col_con=${cur_col_con::-1}
    fi
    record="$cur_col_name,$cur_col_dt,$cur_col_con"
    echo "$record" >> "$schema_path"
    display "Column saved!" "g"
  done
  display "Table created successfully" "g"
}

# -------------------------------
# SCHEMA + VALIDATION

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

# -------------------------------
# WHERE CONSTRAINTS (new version)

read_constraints() {
    display "Do you want to add a WHERE clause? (y/n):" "g"
    read ans
    if [[ "$ans" == "y" ]]; then
        display "Enter condition (e.g., age>=20 AND name=Ali): " "g"
        read condition
        schema_file="${table_name}/${table_name}_schema"
        columns=()
        while IFS=',' read -r cname _ _; do
          columns+=("$cname")
        done < "$schema_file"

        awk_expr=""
        tokens=($condition)

        for token in "${tokens[@]}"; do
          if [[ "$token" =~ ^(AND|and)$ ]]; then
            awk_expr="$awk_expr &&"
          elif [[ "$token" =~ ^(OR|or)$ ]]; then
            awk_expr="$awk_expr ||"
          elif [[ "$token" == *">="* ]]; then
            col=$(echo "$token" | cut -d'>' -f1)
            val=$(echo "$token" | cut -d'=' -f2)
            col_index=-1
            for i in "${!columns[@]}"; do
              if [ "${columns[$i]}" = "$col" ]; then col_index=$((i+1)); break; fi
            done
            awk_expr="$awk_expr \$${col_index}>=$val"
          elif [[ "$token" == *"<="* ]]; then
            col=$(echo "$token" | cut -d'<' -f1)
            val=$(echo "$token" | cut -d'=' -f2)
            col_index=-1
            for i in "${!columns[@]}"; do
              if [ "${columns[$i]}" = "$col" ]; then col_index=$((i+1)); break; fi
            done
            awk_expr="$awk_expr \$${col_index}<=$val"
          elif [[ "$token" == *">"* ]]; then
            col=$(echo "$token" | cut -d'>' -f1)
            val=$(echo "$token" | cut -d'>' -f2)
            col_index=-1
            for i in "${!columns[@]}"; do
              if [ "${columns[$i]}" = "$col" ]; then col_index=$((i+1)); break; fi
            done
            awk_expr="$awk_expr \$${col_index}>$val"
          elif [[ "$token" == *"<"* ]]; then
            col=$(echo "$token" | cut -d'<' -f1)
            val=$(echo "$token" | cut -d'<' -f2)
            col_index=-1
            for i in "${!columns[@]}"; do
              if [ "${columns[$i]}" = "$col" ]; then col_index=$((i+1)); break; fi
            done
            awk_expr="$awk_expr \$${col_index}<$val"
          elif [[ "$token" == *"="* ]]; then
            col=$(echo "$token" | cut -d'=' -f1)
            val=$(echo "$token" | cut -d'=' -f2)
            col_index=-1
            for i in "${!columns[@]}"; do
              if [ "${columns[$i]}" = "$col" ]; then col_index=$((i+1)); break; fi
            done
            awk_expr="$awk_expr \$${col_index}==\"$val\""
          else
            echo "Invalid token: $token"
            return
          fi
        done

        export awk_expr
    else
        awk_expr="1"
        export awk_expr
    fi
}

# -------------------------------
# INSERT DATA

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
            if $valid; then break; else display "Invalid value" "r"; fi
        done
        values+=("$value")
    done
    data_path="${table_name}/${table_name}_data"
    row_data=$(IFS=','; echo "${values[*]}")
    echo "$row_data" >> "$data_path"
    display "Row inserted: $row_data" "g"
}

# -------------------------------
# UPDATE DATA

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
            break
        fi
    done
    [ "$update_pos" -eq -1 ] && display "Column not found!" "r" && return
    display "Enter new value:" "g"
    read new_value
    tmp="${data_path}.tmp"
    awk -F',' -v OFS=',' -v upos="$update_pos" -v nval="$new_value" \
        "($awk_expr){\$upos=nval} {print}" "$data_path" > "$tmp" && mv "$tmp" "$data_path"
    display "Update complete" "g"
    cat "$data_path"
}

# -------------------------------
# MAIN MENU

show_menu() {
  echo ""
  display "==== DATABASE MANAGER ====" "g"
  echo "1. Create Table"
  echo "2. Insert Data"
  echo "3. Update Data"
  echo "4. Exit"
}

display "Hi! (DB manager)" "g"
while true; do
  show_menu
  display "Enter choice:" "g"
  read choice
  case $choice in
    1) create_table ;;
    2) insert_data ;;
    3) update_data ;;
    4) display "Bye!" "g"; exit 0 ;;
    *) display "Invalid choice!" "r" ;;
  esac
done
