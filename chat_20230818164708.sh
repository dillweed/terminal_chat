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
  {\"role\": \"system\", \"content\": \"You are a MacOS terminal expert. After assisting with my request, indicate the preferred source of information on the topic whether it be a man page, website, or other documentation. Your response will display in the terminal, so don't use markdown or text blocks wrapped in triple backticks. Instead, choose a dark mode color palette appropriate for terminal text elements with different colors for code or commands (in 255,176,0), section titles (in 51,200,0) and hyperlinks (in 0,40,255). Format the text using forground and background colors using ANSI escape codes with the syntax \\\033[38;2;r;g;b;48;2;r;g;bm. (Note the two r;g;b placeholders for text and background.) The character m signifies the end of the code. Additionally, you may add an extra ;1 before the m for bold, ;4 for underline, or ;0 for normal text. For example, \\\033[38;2;200;200;200;48;2;0;0;0;1m will display dim-white bold text on a black background.\"},
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
echo -e "\n\n\033[38;2;255;176;0;48;2;40;40;40;1m                             GPT-4 Response                             \033[0m\n\n$text\n"
