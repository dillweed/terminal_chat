#!/bin/bash
# FILEPATH: /usr/local/bin/chat.sh
# Version: 1.0
#
# Setup Instructions: 
# 1. Copy this script to a directory in your $PATH. For example, 'cp chat.sh /usr/local/bin/'
# 2. Make it executable. 'chmod +x /usr/local/bin/chat.sh'
# 3. Create an alias in your bash config such as ~/.zshrc. 'alias chat=/usr/local/bin/chat.sh'
# 4. Add your OpenAI API key as an environment variable. For example, add 'export OPENAI_API_KEY=<your-api-key>' in ~/.zshrc. 
# API key usage instructions: https://help.openai.com/en/articles/4936850-where-do-i-find-my-secret-api-key
# 5. Install jq for json parsing. 'brew install jq' More info: https://formulae.brew.sh/formula/jq 
# 
# Usage Description:
# This script is used to submit requests to OpenAI GPT-4 from the zsh terminal. It has no memory, so each interaction will be independent. 
# It can be prompted in two ways:
#
# 1. chat "Type your request here in single or double quotes." (press return)
#
# - Pros: Allows for quick questions. Allows use of the pipe '|' to chain commands. 
# - Cons: Placing the same quote type inside the prompt will break the submission. Use outer double quotes and inner single quotes or vice versa. 
#
# 2. chat (press return)
#    Type your request here.
#    Type or paste additional input on multiple lines, and then type 'END' on a new line when finished.
#    END (press return)
#
# - Pros: Allows you to paste long inputs with line breaks. Allows use of quotes inside the prompt.
# - Cons: Requires more typing. 
#
#
# Example:
# 1. chat "What's the rsync syntax to mirror directories on a remote server and log differences without making changes?" (press return)
#
# 2. chat
#    Debug this bash script.
#    !/bin/bash
#    file=$1
#    base=$(basename "$file")
#    ext="${base##*.}"
#    fname="${base%.*}"
#    timestamp=$(date +%Y%m%d%H%M%S)
#    cp file ${fname}_$timestamp.$ext
#    END (press return)
#
# Notes: 
# - The response will include ANSI text decorations that may or may not parse depending on terminal config. I'm still working that out. 
# - Customize the system message as desired. I change mine frequently.

# Check if OPENAI_API_KEY environment variable is set
if [ -z "$OPENAI_API_KEY" ]; then
  echo \ 
  echo "ERROR: The OPENAI_API_KEY environment variable is not set."
  echo \ 
  echo "Add your OpenAI API key as an environment variable. For example, add 'export OPENAI_API_KEY=<your-api-key>' in ~/.zshrc." 
  echo "API key usage instructions: https://help.openai.com/en/articles/4936850-where-do-i-find-my-secret-api-key"
  echo \ 
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo \ 
  echo "ERROR: jq is not installed."
  echo \ 
  echo "Please install jq from https://formulae.brew.sh/formula/jq before running this script."
  echo \ 
  exit 1
fi

# Check if arguments were provided
if [ "$#" -gt 0 ]; then
  user_content="$@"
else
  # If no argument is given, display instructions and prompt
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
  {\"role\": \"system\", \"content\": \"You are an expert teacher for Mac terminal, Windows command prompt and PowerShell. After assisting with my request, indicate the preferred source of information on the topic whether it be a man page, website, or other documentation. Your response will display in the terminal, so don't use markdown or text blocks wrapped in triple backticks. Instead, choose colors from the following dark mode 8-bit color palette as appropriate for terminal text. Choose colors other than white for hyperlinks, commands, variables, titles, etc. Use a black background for all code and terminal examples. Use 256 color syntax like this. \\\033[38;5;F;48;5;Bm. (Where F and B are placeholders for foreground and background color codes.) Palette codes: Default text color code (muted white) is 252. Bold text is 231 (bright white with added bold code ';1' before the closing 'm'). Code block background color is 0 (black). Comments color is 244 (bright gray). Text color options: Blue is 31. Green is 29. Pink is 162. Orange is 172. Additionally, you may add an extra ;1 before the m for bold, ;4 for underline, or ;0 for normal text. For example, \\\033[38;5;252;48;5;0m will display muted white text color on a black background (code block). \\\033[38;5;172;1m will display bold orange text on the default background.\"},
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
echo -e "\n\n\033[38;5;100;48;5;238;1m                             GPT-4 Response                             \033[0m\n\n$text\n"
