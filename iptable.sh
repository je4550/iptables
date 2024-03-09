
#!/bin/bash

# Function to create a backup of current iptables rules
backup_iptables_rules() {
    local backup_dir="/var/backups/iptables"
    local backup_file="${backup_dir}/iptables-backup-$(date +%Y%m%d-%H%M%S).v4"

    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"

    # Save current iptables rules to the backup file
    iptables-save > "$backup_file"
    echo "iptables rules have been backed up to $backup_file"
}

# Function to check if iptables-persistent is installed
check_iptables_persistent() {
    if ! dpkg -l | grep -qw iptables-persistent; then
        echo "Warning: iptables-persistent does not seem to be installed."
        echo "This means changes won't persist across reboots automatically."
        echo "You can install iptables-persistent using your package manager."
        read -p "Do you want to continue without iptables-persistent? (y/N): " confirm
        [[ "$confirm" == [yY] ]] || exit 1
    fi
}

# Backup iptables rules at the start of the script
backup_iptables_rules
# Ensure iptables-persistent is checked for
check_iptables_persistent

# Function to display existing port forwarding rules
display_port_forwarding_rules() {
    echo "Existing PREROUTING Port Forwarding Rules:"
    iptables -t nat -L PREROUTING --line-numbers -n
    echo "Existing POSTROUTING Port Forwarding Rules:"
    iptables -t nat -L POSTROUTING --line-numbers -n
}

# Function to add a port forwarding rule
add_port_forwarding_rule() {
    read -p "Enter the port to forward: " port
    read -p "Enter the destination IP address (for PREROUTING only): " dest_ip
    read -p "Enter the protocol (tcp/udp/both) [both]: " protocol
    protocol=${protocol:-both}

    # PREROUTING for DNAT
    if [[ $protocol == "tcp" ]] || [[ $protocol == "both" ]]; then
        iptables -t nat -A PREROUTING -p tcp --dport $port -j DNAT --to-destination $dest_ip:$port
    fi
    if [[ $protocol == "udp" ]] || [[ $protocol == "both" ]]; then
        iptables -t nat -A PREROUTING -p udp --dport $port -j DNAT --to-destination $dest_ip:$port
    fi

    # POSTROUTING for SNAT (masquerade)
    iptables -t nat -A POSTROUTING -p tcp --dport $port -j MASQUERADE
    iptables -t nat -A POSTROUTING -p udp --dport $port -j MASQUERADE

    # Save iptables rules to ensure they persist after reboot
    iptables-save > /etc/iptables/rules.v4
    echo "Port forwarding rule for $protocol added."
}

# Function for Removing a Port Forwarding Rule with Chain Selection
remove_port_forwarding_rule() {
    echo "1) PREROUTING"
    echo "2) POSTROUTING"
    read -p "Select the chain from which to remove a rule [1-2]: " chain_choice

    case $chain_choice in
        1) chain="PREROUTING";;
        2) chain="POSTROUTING";;
        *) echo "Invalid choice. Returning to menu..."; return;;
    esac

    echo "Current $chain DNAT/SNAT Port Forwarding Rules:"
    iptables -t nat -L $chain --line-numbers -n
    read -p "Enter the line number of the rule you wish to remove: " line_number

    if [[ -z "$line_number" ]]; then
        echo "No input entered. Returning to menu..."
    elif ! [[ "$line_number" =~ ^[0-9]+$ ]]; then
        echo "Invalid input. Please enter a numeric line number."
    else
        iptables -t nat -D $chain $line_number 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "Rule removed successfully from $chain."
            iptables-save > /etc/iptables/rules.v4
        else
            echo "Failed to remove the rule from $chain. Please check the line number and try again."
        fi
    fi
}

# Main menu function
show_menu() {
    echo "1) Add port forwarding rule"
    echo "2) Remove port forwarding rule"
    echo "3) Display all port forwarding rules"
    echo "4) Exit"
    read -p "Enter your choice [1-4]: " choice

    case $choice in
        1) add_port_forwarding_rule ;;
        2) remove_port_forwarding_rule ;;
        3) display_port_forwarding_rules ;;
        4) exit 0 ;;
        *) echo "Invalid option. Please enter 1, 2, 3, or 4." ;;
    esac
}

# Loop the menu
while true; do
    show_menu
done
