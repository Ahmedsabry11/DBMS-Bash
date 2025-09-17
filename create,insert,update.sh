#!/bin/bash


# Utility Functions

# Show colored messages
show_msg() {
    msg="$1"
    color="$2"
    
    if [ "$color" = "green" ]; then
        echo -e "\033[32m$msg\033[0m"
    elif [ "$color" = "red" ]; then
        echo -e "\033[31m$msg\033[0m"
    else
        echo "$msg"
    fi
}

# Safe array printing
print_array() {
    label="$1"
    shift
    echo -n "$label: "
    printf "%s " "$@"
    echo ""
}

# Menu
show_menu() {
    echo ""
    echo "==== Database Manager Menu ===="
    echo "1. Create Table"
    echo "2. Insert Into Table"
    echo "3. Update Table"
    echo "4. Exit"
    echo ""
}

# Schema Handling
read_schema() {
    table_name="$1"
    schema_file="${table_name}/${table_name}_schema"
    
    if [ ! -f "$schema_file" ]; then
        show_msg "Schema file not found!" "red"
        return 1
    fi
    
    # Reset schema vars
    DB_COLUMNS=()
    DB_TYPES=()
    DB_UNIQUE_COLS=()
    DB_NOTNULL_COLS=()
    DB_PRIMARY_KEY=""
    
    # Extract schema lines
    COLUMNS_LINE=$(awk -F: '/^columns:/ {print $2}' "$schema_file" | tr -d '\r' | xargs)
    TYPES_LINE=$(awk -F: '/^types:/ {print $2}' "$schema_file" | tr -d '\r' | xargs)
    DB_PRIMARY_KEY=$(awk -F: '/^primary:/ {print $2}' "$schema_file" | tr -d '\r' | xargs)
    UNIQUE_LINE=$(awk -F: '/^unique:/ {print $2}' "$schema_file" | tr -d '\r' | xargs)
    NOTNULL_LINE=$(awk -F: '/^notnull:/ {print $2}' "$schema_file" | tr -d '\r' | xargs)
    
    # Convert to arrays
    [ -n "$COLUMNS_LINE" ] && IFS='|' read -ra DB_COLUMNS <<< "$COLUMNS_LINE"
    [ -n "$TYPES_LINE" ] && IFS='|' read -ra DB_TYPES <<< "$TYPES_LINE"
    [ -n "$UNIQUE_LINE" ] && IFS='|' read -ra DB_UNIQUE_COLS <<< "$UNIQUE_LINE"
    [ -n "$NOTNULL_LINE" ] && IFS='|' read -ra DB_NOTNULL_COLS <<< "$NOTNULL_LINE"
    IFS=$' \t\n'
    
    return 0
}

# Check uniqueness
check_unique_value() {
    table_name="$1"
    column_name="$2"
    value="$3"
    data_file="${table_name}/${table_name}_data"
    
    col_pos=1
    for i in "${!DB_COLUMNS[@]}"; do
        if [ "${DB_COLUMNS[$i]}" = "$column_name" ]; then
            col_pos=$((i + 1))
            break
        fi
    done
    
    if [ ! -f "$data_file" ] || [ ! -s "$data_file" ]; then
        return 0
    fi
    
    if cut -d',' -f"$col_pos" "$data_file" | grep -Fxq "$value"; then
        return 1
    else
        return 0
    fi
}

# Create Table
create_table() {
    show_msg "=== CREATE TABLE ===" "green"
    
    echo "Enter table name:"
    read table_name
    table_name=$(echo "$table_name" | xargs)
    
    while [ -d "$table_name" ]; do
        show_msg "Table '$table_name' already exists!" "red"
        echo "Enter different table name (or 'quit' to cancel):"
        read table_name
        table_name=$(echo "$table_name" | xargs)
        [ "$table_name" = "quit" ] && return
    done
    
    mkdir -p "$table_name"
    touch "${table_name}/${table_name}_schema" "${table_name}/${table_name}_data"
    show_msg "Table directory created" "green"
    
    DB_COLUMNS=()
    DB_TYPES=()
    DB_UNIQUE_COLS=()
    DB_NOTNULL_COLS=()
    DB_PRIMARY_KEY=""
    
    echo "Enter PRIMARY KEY column name:"
    read pk_name
    
    while [[ ! $pk_name =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; do
        show_msg "Invalid name! Use letters and underscores only" "red"
        echo "Enter PRIMARY KEY column name:"
        read pk_name
    done
    
    echo "Primary key data type:"
    echo "1. Number"
    echo "2. String"
    read choice
    
    pk_type=$([ "$choice" = "1" ] && echo "number" || echo "string")
    
    DB_COLUMNS+=("$pk_name")
    DB_TYPES+=("$pk_type")
    DB_UNIQUE_COLS+=("$pk_name")
    DB_NOTNULL_COLS+=("$pk_name")
    DB_PRIMARY_KEY="$pk_name"
    
    show_msg "Primary key '$pk_name' added" "green"
    
    while true; do
        echo ""
        echo "Enter column name (or 'done' to finish):"
        read col_name
        [ "$col_name" = "done" ] && break
        
        [[ ! $col_name =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] && {
            show_msg "Invalid name! Use letters and underscores only" "red"
            continue
        }
        
        echo "Data type for '$col_name':"
        echo "1. Number"
        echo "2. String"
        read choice
        col_type=$([ "$choice" = "1" ] && echo "number" || echo "string")
        
        DB_COLUMNS+=("$col_name")
        DB_TYPES+=("$col_type")
        
        echo "Make '$col_name' UNIQUE? (y/n):"
        read answer
        [ "$answer" = "y" ] && DB_UNIQUE_COLS+=("$col_name")
        
        echo "Make '$col_name' NOT NULL? (y/n):"
        read answer
        [ "$answer" = "y" ] && DB_NOTNULL_COLS+=("$col_name")
        
        show_msg "Column '$col_name' added" "green"
    done
    
    schema_file="${table_name}/${table_name}_schema"
    {
        printf "columns:%s\n" "$(IFS='|'; echo "${DB_COLUMNS[*]}")"
        printf "types:%s\n" "$(IFS='|'; echo "${DB_TYPES[*]}")"
        echo "primary:$DB_PRIMARY_KEY"
        printf "unique:%s\n" "$(IFS='|'; echo "${DB_UNIQUE_COLS[*]}")"
        printf "notnull:%s\n" "$(IFS='|'; echo "${DB_NOTNULL_COLS[*]}")"
    } > "$schema_file"
    
    show_msg "Table '$table_name' created successfully!" "green"
    echo ""
    cat "$schema_file"
}

# Insert Data
insert_data() {
    show_msg "=== INSERT DATA ===" "green"
    
    echo "Enter table name:"
    read table_name
    table_name=$(echo "$table_name" | xargs)
    
    [ ! -d "$table_name" ] && { show_msg "Table not found!" "red"; return; }
    read_schema "$table_name" || return
    
    echo ""
    print_array "Columns" "${DB_COLUMNS[@]}"
    print_array "Types" "${DB_TYPES[@]}"
    echo "Primary Key: $DB_PRIMARY_KEY"
    echo ""
    
    values=()
    for i in "${!DB_COLUMNS[@]}"; do
        col_name="${DB_COLUMNS[$i]}"
        col_type="${DB_TYPES[$i]}"
        
        while true; do
            echo "Enter value for '$col_name' ($col_type):"
            read value
            
            is_notnull=false
            for ncol in "${DB_NOTNULL_COLS[@]}"; do
                [ "$ncol" = "$col_name" ] && is_notnull=true
            done
            $is_notnull && [ -z "$value" ] && { show_msg "Cannot be empty!" "red"; continue; }
            
            [ "$col_type" = "number" ] && [ -n "$value" ] && \
            ! [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] && { show_msg "Must be number!" "red"; continue; }
            
            is_unique=false
            for ucol in "${DB_UNIQUE_COLS[@]}"; do
                [ "$ucol" = "$col_name" ] && is_unique=true
            done
            $is_unique && ! check_unique_value "$table_name" "$col_name" "$value" && {
                show_msg "Value '$value' already exists!" "red"
                continue
            }
            break
        done
        
        values+=("$value")
    done
    
    row_data=$(IFS=,; echo "${values[*]}")
    echo "$row_data" >> "${table_name}/${table_name}_data"
    show_msg "Row inserted successfully!" "green"
}

# Update Data
update_data() {
    show_msg "=== UPDATE TABLE ===" "green"
    
    echo "Enter table name:"
    read table_name
    table_name=$(echo "$table_name" | xargs)
    
    [ ! -d "$table_name" ] && { show_msg "Table not found!" "red"; return; }
    read_schema "$table_name" || return
    
    data_file="${table_name}/${table_name}_data"
    [ ! -s "$data_file" ] && { show_msg "Table is empty!" "green"; return; }
    
    echo ""
    print_array "Columns" "${DB_COLUMNS[@]}"
    echo "Data:"
    cat "$data_file"
    echo ""
    
    # === WHERE condition ===
    echo "Enter WHERE condition (e.g. id=3, id<=2, name=Ahmed):"
    read cond

    # Parse condition into column, operator, value
    if [[ "$cond" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\ *(=|!=|>=|<=|>|<)\ *(.+)$ ]]; then
        where_col="${BASH_REMATCH[1]}"
        op="${BASH_REMATCH[2]}"
        where_val="${BASH_REMATCH[3]}"
    else
        show_msg "Invalid condition format!" "red"
        return
    fi

    # Validate column
    col_found=false
    for col in "${DB_COLUMNS[@]}"; do
        [ "$col" = "$where_col" ] && col_found=true
    done
    ! $col_found && { show_msg "Column '$where_col' not found!" "red"; return; }

    # Find WHERE column position
    where_pos=1
    for i in "${!DB_COLUMNS[@]}"; do
        [ "${DB_COLUMNS[$i]}" = "$where_col" ] && where_pos=$((i + 1))
    done
    
    # === SET column ===
    echo "Enter column to update:"
    read update_col
    [ "$update_col" = "$DB_PRIMARY_KEY" ] && { show_msg "Cannot update primary key!" "red"; return; }
    
    # Validate column
    col_found=false
    for col in "${DB_COLUMNS[@]}"; do
        [ "$col" = "$update_col" ] && col_found=true
    done
    ! $col_found && { show_msg "Column not found!" "red"; return; }
    
    # Find UPDATE column position
    update_pos=1
    for i in "${!DB_COLUMNS[@]}"; do
        [ "${DB_COLUMNS[$i]}" = "$update_col" ] && update_pos=$((i + 1))
    done
    
    echo "Enter new value (number, string, or +N / -N for increment):"
    read new_value
    
    temp_file="${data_file}.tmp"
    awk -F',' -v OFS=',' \
        -v where_pos="$where_pos" -v op="$op" -v val="$where_val" \
        -v update_pos="$update_pos" -v expr="$new_value" '
        function eval_condition(v) {
            if (op == "=")  return (v == val)
            if (op == "!=") return (v != val)
            if (op == ">")  return (v > val)
            if (op == "<")  return (v < val)
            if (op == ">=") return (v >= val)
            if (op == "<=") return (v <= val)
            return 0
        }
        function eval_update(old) {
            if (expr ~ /^\+?[0-9]+$/) return expr   # plain number
            if (expr ~ /^\+[0-9]+$/) return old + substr(expr,2)
            if (expr ~ /^-[0-9]+$/) return old - substr(expr,2)
            return expr
        }
        eval_condition($where_pos) { $update_pos = eval_update($update_pos) }
        { print }
    ' "$data_file" > "$temp_file"
    
    if [ $? -eq 0 ]; then
        mv "$temp_file" "$data_file"
        show_msg "Rows updated successfully!" "green"
        echo ""
        cat "$data_file"
    else
        show_msg "Update failed!" "red"
        rm -f "$temp_file"
    fi
}


# ================================
# Main Loop
# ================================
show_msg "Database Manager Started" "green"

while true; do
    show_menu
    echo "Enter your choice (1-4):"
    read choice
    
    case $choice in
        1) create_table ;;
        2) insert_data ;;
        3) update_data ;;
        4) show_msg "Thank you for using Database Manager!" "green"; exit 0 ;;
        *) show_msg "Invalid choice! Please enter 1-4" "red" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done