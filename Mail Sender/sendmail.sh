#!/bin/bash

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Initialize variables
from=""
recipients_csv=""
subject=""
body_file=""

# Function to display the help message
show_help() {
  echo "Usage: $0 -f FROM_EMAIL -t RECIPIENTS_CSV -u SUBJECT -m BODY_FILE"
  echo "  -f   Email address to send from"
  echo "  -t   CSV file containing names, email addresses of recipients, and their SMTP details"
  echo "  -u   Email subject"
  echo "  -m   File containing email body"
  echo "  -h   Display this help and exit"
}

# Parse command-line options
while getopts ":hf:t:u:m:" opt; do
  case ${opt} in
    f ) from=$OPTARG ;;
    t ) recipients_csv=$OPTARG ;;
    u ) subject=$OPTARG ;;
    m ) body_file=$OPTARG ;;
    h ) show_help; exit 0 ;;
    \? ) echo "Invalid option: -$OPTARG" >&2; show_help; exit 1 ;;
    : ) echo "Option -$OPTARG requires an argument." >&2; show_help; exit 1 ;;
  esac
done

# Check if required arguments are provided
if [ -z "$from" ] || [ -z "$recipients_csv" ] || [ -z "$subject" ] || [ -z "$body_file" ]; then
  echo "All arguments are required."
  show_help
  exit 1
fi

# Check if body file exists
if [ ! -f "$body_file" ]; then
  echo "Body file does not exist."
  exit 1
fi
body=$(<"$body_file")

email_count=0

# Loop through recipients and their SMTP details
while IFS=, read -r name email smtp_server smtp_user smtp_password; do
  personalized_body=${body//"{name}"/$name}
  
  success=false
  attempt=0
  
  while [ "$success" = false ]; do
    echo "Sending email to $email using SMTP Server: $smtp_server..."
    output=$(sendEmail -f "$from" -t "$email" -u "$subject" -m "$personalized_body" -s "$smtp_server" -xu "$smtp_user" -xp "$smtp_password" 2>&1)
    echo "$output"
    
    # Check if sendEmail was successful
    if echo "$output" | grep -q 'successfully'; then
      echo "Email sent successfully to $email."
      success=true
    else
      echo "Failed to send email to $email. Retrying..."
      ((attempt++))
      if [ "$attempt" -ge 3 ]; then
        echo "Failed to send email to $email after 3 attempts."
        break
      fi
      sleep 10 # wait a bit before retrying
    fi
  done

  ((email_count++))
  if [ "$email_count" -eq 4 ]; then
    echo "Waiting 30 minutes before sending the next batch of emails..."
    sleep 1800
    email_count=0
  fi

done < "$recipients_csv"
