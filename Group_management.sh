#!/bin/bash

PROJECT_DIR="/home/$USER/Desktop/ST3 Project"
LOG_FILE="$PROJECT_DIR/group_management.log"
VIRTUAL_USERS="$PROJECT_DIR/virtual_users.txt"
GROUP_MEMBERS="$PROJECT_DIR/virtual_group_memberships.txt"

mkdir -p "$PROJECT_DIR"
touch "$LOG_FILE" "$VIRTUAL_USERS" "$GROUP_MEMBERS"

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> "$LOG_FILE"
}

while true; do
    choice=$(dialog --clear --backtitle "Group Management Tool" \
        --title "Main Menu" \
        --menu "Choose an option:" 20 60 9 \
        1 "View Groups with Members" \
        2 "Add Group" \
        3 "Delete Group" \
        4 "Modify Group Name" \
        5 "Add/Remove User to/from Group" \
        6 "View All Users (Real + Virtual)" \
        7 "Create User (Virtual or Real)" \
        8 "Exit" \
        3>&1 1>&2 2>&3)

    case $choice in
        1)
            output=""
            while IFS=: read -r group _ gid members; do
                if [ "$gid" -ge 1000 ]; then
                    output+="\nGroup: $group\n"
                    all_users="$members"
                    virtual_users=$(grep ":$group$" "$GROUP_MEMBERS" | cut -d: -f1 | xargs)
                    all_users="$all_users $virtual_users"
                    output+="  Users: ${all_users:-None}\n"
                fi
            done < /etc/group

            if [[ -z "$output" ]]; then
                output="No user-defined groups found."
            fi

            dialog --title "Groups with Members" --msgbox "$output" 25 80
            ;;

        2)
            groupname=$(dialog --inputbox "Enter new group name:" 8 40 3>&1 1>&2 2>&3)
            if [[ -z "$groupname" ]]; then
                dialog --msgbox "Group name cannot be empty!" 6 40
            elif getent group "$groupname" > /dev/null; then
                dialog --msgbox "Group already exists!" 6 40
            else
                sudo groupadd "$groupname"
                dialog --msgbox "Group '$groupname' added." 6 40
                log_action "Created group: $groupname"
            fi
            ;;

        3)
            groupname=$(dialog --inputbox "Enter group name to delete:" 8 40 3>&1 1>&2 2>&3)
            if ! getent group "$groupname" > /dev/null; then
                dialog --msgbox "Group does not exist!" 6 40
            else
                sudo groupdel "$groupname"
                dialog --msgbox "Group '$groupname' deleted." 6 40
                log_action "Deleted group: $groupname"
            fi
            ;;

        4)
            oldgroup=$(dialog --inputbox "Enter existing group name:" 8 40 3>&1 1>&2 2>&3)
            newgroup=$(dialog --inputbox "Enter new group name:" 8 40 3>&1 1>&2 2>&3)
            if ! getent group "$oldgroup" > /dev/null; then
                dialog --msgbox "Original group does not exist!" 6 40
            elif getent group "$newgroup" > /dev/null; then
                dialog --msgbox "New group name already exists!" 6 40
            else
                sudo groupmod -n "$newgroup" "$oldgroup"
                dialog --msgbox "Group renamed to '$newgroup'." 6 40
                log_action "Renamed group $oldgroup to $newgroup"
            fi
            ;;

                5)
            user=$(dialog --clear --title "Add/Remove User" \
                   --inputbox "Enter username:" 8 50 3>&1 1>&2 2>&3)
            group=$(dialog --clear --title "Add/Remove User" \
                    --inputbox "Enter group name:" 8 50 3>&1 1>&2 2>&3)

            if ! grep -qw "$user" "$VIRTUAL_USERS" && ! id "$user" &>/dev/null; then
                dialog --title "Error" --msgbox "User does not exist!" 6 50
            elif ! getent group "$group" > /dev/null; then
                dialog --title "Error" --msgbox "Group does not exist!" 6 50
            else
                action=$(dialog --clear --title "Select Action" \
                    --menu "What would you like to do?" 10 50 2 \
                    1 "Add User to Group" \
                    2 "Remove User from Group" \
                    3>&1 1>&2 2>&3)

                case $action in
                    1)
                        if grep -qw "$user" "$VIRTUAL_USERS"; then
                            if grep -qw "^$user:$group$" "$GROUP_MEMBERS"; then
                                dialog --title "Info" --msgbox "User is already in the group." 6 50
                            else
                                echo "$user:$group" >> "$GROUP_MEMBERS"
                                dialog --title "Success" --msgbox "Virtual user added to group." 6 50
                                log_action "Added virtual user $user to group $group"
                            fi
                        else
                            if id -nG "$user" | grep -qw "$group"; then
                                dialog --title "Info" --msgbox "User is already in the group." 6 50
                            else
                                sudo usermod -a -G "$group" "$user"
                                dialog --title "Success" --msgbox "Real user added to group." 6 50
                                log_action "Added real user $user to group $group"
                            fi
                        fi
                        ;;
                    2)
                        if grep -qw "$user" "$VIRTUAL_USERS"; then
                            if grep -qw "^$user:$group$" "$GROUP_MEMBERS"; then
                                sed -i "/^$user:$group$/d" "$GROUP_MEMBERS"
                                dialog --title "Success" --msgbox "Virtual user removed from group." 6 50
                                log_action "Removed virtual user $user from group $group"
                            else
                                dialog --title "Info" --msgbox "User is not in this group." 6 50
                            fi
                        else
                            if id -nG "$user" | grep -qw "$group"; then
                                sudo gpasswd -d "$user" "$group"
                                dialog --title "Success" --msgbox "Real user removed from group." 6 50
                                log_action "Removed real user $user from group $group"
                            else
                                dialog --title "Info" --msgbox "User is not in this group." 6 50
                            fi
                        fi
                        ;;
                esac
            fi
            ;;



        6)
            real_users=$(cut -d: -f1 /etc/passwd | sort)
            virtual_users=$(cat "$VIRTUAL_USERS" 2>/dev/null || echo "None")
            dialog --msgbox "🔸 Real Users:\n$real_users\n\n🔸 Virtual Users:\n$virtual_users" 25 60
            ;;

        7)
            user_type=$(dialog --clear --title "Create User" \
                --menu "Select user type to create:" 10 50 2 \
                1 "Virtual User" \
                2 "Real User" \
                3>&1 1>&2 2>&3)

            username=$(dialog --clear --title "Create User" \
                --inputbox "Enter username:" 8 50 3>&1 1>&2 2>&3)

            if [[ -z "$username" ]]; then
                dialog --title "Error" --msgbox "Username cannot be empty!" 6 50
            elif id "$username" &>/dev/null || grep -qw "$username" "$VIRTUAL_USERS"; then
                dialog --title "Error" --msgbox "User already exists!" 6 50
            else
                if [[ $user_type == 1 ]]; then
                    echo "$username" >> "$VIRTUAL_USERS"
                    dialog --title "Success" --msgbox "Virtual user '$username' created." 6 50
                    log_action "Created virtual user: $username"
                elif [[ $user_type == 2 ]]; then
                    sudo useradd --no-user-group "$username"
                    dialog --title "Success" --msgbox "Real user '$username' created." 6 50
                    log_action "Created real user: $username"

                    (
                        sleep 500
                        sudo userdel "$username" &>/dev/null
                        log_action "Auto-deleted real user after 5 min: $username"
                    ) &
                fi
            fi
            ;;

        8)
            clear
            echo "Exiting Group Management Tool. Bye!"
            exit 0
            ;;
    esac
done
