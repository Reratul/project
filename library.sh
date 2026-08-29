#!/bin/bash

DATA_FILE="books.txt"

# Ensure database file exists
touch "$DATA_FILE"

add_book() {
    echo "--- Add New Book ---"
    read -p "Enter ISBN / Book ID: " id
    
    if grep -q "^$id:" "$DATA_FILE"; then
        echo "Error: Book ID '$id' already exists!"
        return
    fi

    read -p "Enter Title: " title
    read -p "Enter Author: " author

    # Format: ID:Title:Author:Status
    # Status defaults to 'Available'
    echo "$id:$title:$author:Available" >> "$DATA_FILE"
    echo "Book added successfully!"
}

view_books() {
    echo "--- Library Inventory ---"
    if [ ! -s "$DATA_FILE" ]; then
        echo "No books found in system."
        return
    fi

    printf "%-10s %-25s %-20s %-12s\n" "ID" "Title" "Author" "Status"
    echo "-------------------------------------------------------------------"
    while IFS=":" read -r id title author status; do
        printf "%-10s %-25s %-20s %-12s\n" "$id" "$title" "$author" "$status"
    done < "$DATA_FILE"
}

search_book() {
    echo "--- Search Book ---"
    read -p "Enter Title or Author keyword: " query

    results=$(grep -i "$query" "$DATA_FILE")
    if [ -n "$results" ]; then
        echo ""
        printf "%-10s %-25s %-20s %-12s\n" "ID" "Title" "Author" "Status"
        echo "-------------------------------------------------------------------"
        while IFS=":" read -r id title author status; do
            printf "%-10s %-25s %-20s %-12s\n" "$id" "$title" "$author" "$status"
        done <<< "$results"
    else
        echo "No matching books found."
    fi
}

toggle_checkout() {
    echo "--- Issue / Return Book ---"
    read -p "Enter Book ID: " id

    record=$(grep "^$id:" "$DATA_FILE")
    if [ -z "$record" ]; then
        echo "Error: Book ID '$id' not found."
        return
    fi

    IFS=":" read -r b_id title author status <<< "$record"

    if [ "$status" == "Available" ]; then
        sed -i "/^$id:/c\\$id:$title:$author:Issued" "$DATA_FILE"
        echo "Book '$title' has been successfully ISSUED."
    else
        sed -i "/^$id:/c\\$id:$title:$author:Available" "$DATA_FILE"
        echo "Book '$title' has been successfully RETURNED."
    fi
}

delete_book() {
    echo "--- Remove Book ---"
    read -p "Enter Book ID to remove: " id

    if ! grep -q "^$id:" "$DATA_FILE"; then
        echo "Error: Book ID '$id' not found."
        return
    fi

    sed -i "/^$id:/d" "$DATA_FILE"
    echo "Book record removed from system!"
}

main_menu() {
    while true; do
        echo ""
        echo "Library Management"
        echo "------------------"
        echo "1. Add Book"
        echo "2. View All Books"
        echo "3. Search Book (by Title/Author)"
        echo "4. Issue / Return Book"
        echo "5. Delete Book"
        echo "6. Exit / Back"
        read -p "Enter choice [1-6]: " choice

        case $choice in
            1) add_book ;;
            2) view_books ;;
            3) search_book ;;
            4) toggle_checkout ;;
            5) delete_book ;;
            6) echo "Exiting application."; exit 0 ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

main_menu