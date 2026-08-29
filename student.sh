#!/bin/bash

DATA_FILE="students.txt"

# Ensure database file exists
touch "$DATA_FILE"

add_student() {
    echo "--- Add Student ---"
    read -p "Enter Student ID: " id
    
    # Check if ID already exists
    if grep -q "^$id:" "$DATA_FILE"; then
        echo "Error: Student ID '$id' already exists!"
        return
    fi

    read -p "Enter Name: " name
    read -p "Enter Course: " course
    read -p "Enter GPA/Marks: " gpa

    # Format: ID:Name:Course:GPA
    echo "$id:$name:$course:$gpa" >> "$DATA_FILE"
    echo "Student added successfully!"
}

view_students() {
    echo "--- Student Records ---"
    if [ ! -s "$DATA_FILE" ]; then
        echo "No records found."
        return
    fi

    printf "%-10s %-20s %-15s %-10s\n" "ID" "Name" "Course" "GPA"
    echo "---------------------------------------------------------"
    while IFS=":" read -r id name course gpa; do
        printf "%-10s %-20s %-15s %-10s\n" "$id" "$name" "$course" "$gpa"
    done < "$DATA_FILE"
}

search_student() {
    echo "--- Search Student ---"
    read -p "Enter Student ID to search: " id
    
    record=$(grep "^$id:" "$DATA_FILE")
    if [ -n "$record" ]; then
        IFS=":" read -r s_id name course gpa <<< "$record"
        echo "Record Found:"
        echo "ID: $s_id | Name: $name | Course: $course | GPA: $gpa"
    else
        echo "Error: Student ID '$id' not found."
    fi
}

update_student() {
    echo "--- Update Student ---"
    read -p "Enter Student ID to update: " id

    if ! grep -q "^$id:" "$DATA_FILE"; then
        echo "Error: Student ID '$id' not found."
        return
    fi

    read -p "Enter New Name: " name
    read -p "Enter New Course: " course
    read -p "Enter New GPA: " gpa

    # Replace line in database
    sed -i "/^$id:/c\\$id:$name:$course:$gpa" "$DATA_FILE"
    echo "Student record updated successfully!"
}

delete_student() {
    echo "--- Delete Student ---"
    read -p "Enter Student ID to delete: " id

    if ! grep -q "^$id:" "$DATA_FILE"; then
        echo "Error: Student ID '$id' not found."
        return
    fi

    # Remove matching line from database
    sed -i "/^$id:/d" "$DATA_FILE"
    echo "Student record deleted successfully!"
}

main_menu() {
    while true; do
        echo ""
        echo "Student Management"
        echo "------------------"
        echo "1. Add Student"
        echo "2. View Students"
        echo "3. Search Student"
        echo "4. Update Student"
        echo "5. Delete Student"
        echo "6. Exit / Back"
        read -p "Enter choice [1-6]: " choice

        case $choice in
            1) add_student ;;
            2) view_students ;;
            3) search_student ;;
            4) update_student ;;
            5) delete_student ;;
            6) echo "Exiting application."; exit 0 ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Run program
main_menu