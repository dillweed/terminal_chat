#!/bin/bash

# Check if arguments were provided
if [ "$#" -gt 0 ]; then
  user_content="$@"
else
  # If input is from a terminal, display instructions and prompt
  if [ -t 0 ]; then
    echo \ 
    echo "You can use this script in two ways:"
    echo "1. Execute the script (./chat.sh) and then enter your prompt. Type 'END' on a new line when finished."
    echo "2. Enter the prompt in quotes as an argument while executing the script (./chat.sh \"Your Prompt Here\")."
    echo \ 
    echo "Enter your prompt. Type 'END' on a new line when finished:"
    echo \ 
  fi

  user_content=""
  while IFS= read -r line; do
    [[ "$line" == "END" ]] && break
    user_content+="$line\n"
  done
  # Remove trailing newline character
  user_content=${user_content%\\n}
fi

# Escape special characters and encode newline characters as literal \n
user_content=$(echo -n "$user_content" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')

# Construct messages JSON
messages="[
  {\"role\": \"system\", \"content\": \"You are an expert teacher for Mac terminal, Windows command prompt and PowerShell. After assisting with my help request, indicate the preferred source of information on the topic whether it be a man page, website, or other documentation. Your response will display in the terminal, so don't use markdown or text blocks wrapped in triple backticks. Instead, choose a dark mode color palette appropriate for terminal text elements with different colors for code or commands, section titles, and hyperlinks. Format the text using forground and background colors using the XTerm 256 color standard. For example, 'This is normal text. %F{3}%K{235}%BThis is bold, Olive text on dark grey background.%f%k%b %UUnderlined.%u %IItalicized.%i Back to normal.'\"},
  {\"role\": \"user\", \"content\": \"$user_content\"}
]"

# Function to display a loading spinner
loading_spinner() {
  local delay=0.1
  local spinstr='|/-\'
  while :; do
    local temp=${spinstr#?}
    printf "Waiting for API response %c" "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\r"
  done
}

# Start the loading spinner in the background
loading_spinner &
pid_spinner=$!

# Send request to OpenAI API
response=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "{
    \"model\": \"gpt-4\",
    \"temperature\": 0,
    \"messages\": $messages
  }")

# Kill the loading spinner
kill $pid_spinner
wait $pid_spinner 2>/dev/null

# Extract and print the response text
text=$(echo $response | jq -r '.choices[0].message.content')
echo -e "print -P '\n\n%F{3}%K{235}%B                             GPT-4 Response                             %f%k%b'" | zsh
echo -e "\n\n$text\n"
