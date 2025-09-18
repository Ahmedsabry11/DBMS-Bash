# Bash DBMS

This is a simple file-based Database Management System implemented in Bash.

## Features

- Create, list, connect, and drop databases.
- Create, list, drop tables inside databases.
- Insert, select, update, and delete rows.
- Column-level constraints: primary key, unique, not null, gt/ls for numbers.
- WHERE clause support in SELECT, DELETE, and UPDATE.

## Installation

1. Clone or download the repository.
2. Make scripts executable:
   ```bash
   chmod +x dbms.sh db_manager.sh

## Architecture Design
   ```
          +--------------------+
          |      dbms.sh       |
          |  (Main Script)     |
          +--------------------+
                    |
                    v
          +--------------------+
          |   Select DB        |
          |  (change directory)|
          +--------------------+
                    |
                    v
          +--------------------+
          |  db_manager.sh     |
          |  (Table Manager)   |
          +--------------------+
                    |
    +---------------+---------------+
    |       |       |       |       |
    v       v       v       v       v
+-------+ +-------+ +-------+ +-------+ +-------+
|Create | |List   | |Drop   | |Insert | |Select |
|Table  | |Tables | |Table  | |Rows   | |Rows   |
+-------+ +-------+ +-------+ +-------+ +-------+
    |       |       |       |       |
    v       v       v       v       v
+-------+ +-------+ +-------+
|Delete | |Update | |Exit   |
|Rows   | |Rows   | |Return |
+-------+ +-------+ +-------+
   ```
