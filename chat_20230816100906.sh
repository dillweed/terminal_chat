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
  {\"role\": \"system\", \"content\": \"You are a MacOS terminal expert. After assisting with my request, indicate where I can find more information about the topic. Use the preferred source whether it be a man page, website, documentation, etc. Since your response will display in the terminal, don't use markdown or text blocks wrapped in triple backticks. Instead, visually format with ANSI escape codes in the form backslash033[XXXm to format with colors, bold, and underline. Replace 'backslash' with its utf-8 character. Replace XXX with codes as follows. Bright green: 92. Bright yellow: 93. Bright blue: 94. Bright cyan: 96. Bold: 1. Underline: 4. Normal: 0. backslash033[97;45m is bright white text with a magenta background. Use dividers like '--- Title ---' and indention where relevant.\"},
  {\"role\": \"user\", \"content\": \"$user_content\"}
]"

# Function to display a loading spinner
loading_spinner() {
  local delay=0.1
  local spinstr='|/-\'
  while :; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
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
echo -e "\n\n\033[38;2;180;180;180;48;2;40;40;40m               GPT-4 Response               \033[0m\n\n$text\n"
