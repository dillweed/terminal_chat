#!/bin/bash
# FILEPATH: $HOME/bin/chat.sh
# Version: 1.0
#
# Setup Instructions: 
# 1. Copy this script to a directory in your $PATH (for example, '$HOME/bin').
# 2. Make it executable. 'chmod +x $HOME/bin/chat.sh'
# 3. Create an alias in your bash config such as ~/.zshrc. "alias chat='noglob \"$HOME/bin/chat.sh\"'"
#    Using 'noglob' here stops zsh from treating '?', '*', or '[]' inside your prompt as filename globs.
#    (If you omit noglob, you must either escape those characters or wrap the whole prompt in quotes.)
# 4. Add your OpenAI API key as an environment variable. For example, add 'export OPENAI_API_KEY=<your-api-key>' in ~/.zshrc. 
# API key usage instructions: https://help.openai.com/en/articles/4936850-where-do-i-find-my-secret-api-key
# 5. Install jq for json parsing. 'brew install jq' More info: https://formulae.brew.sh/formula/jq 
# 
# Usage Description:
# This script submits one-off prompts to OpenAI from the shell (no conversation memory). You can drive it three ways:
#
# 1. Inline argument: chat "Prompt here" — wrap the prompt in quotes (or rely on the noglob alias) when it contains spaces or shell metacharacters.
#    Pros: Fast, works with command substitution, keeps stdin free for other tasks. Cons: You must respect your shell's quoting rules.
#
# 2. Interactive single line: run chat with no arguments, then type at the > prompt and press Return. Anything typed on that first line is taken verbatim (quotes, spaces, etc.).
#    Pros: No quoting headaches for short prompts, behaves like a readline input. Cons: Only one line; press Return on a blank line to switch to multi-line mode.
#
# 3. Multi-line or piped input: after starting chat with no args, press Return on the blank prompt and end your input with END on its own line. Alternatively, pipe or redirect into chat (e.g., `cat notes.txt | chat` or `chat <<'EOF' ... EOF`).
#    Pros: Ideal for long snippets, pasted logs, or scripted workflows. Cons: Remember that piping only works when you pass zero CLI arguments.
#
# Example invocations:
# - chat "What's the rsync syntax to mirror directories on a remote server and log differences without making changes?"
# - chat   # press Return at the > prompt, type your question, hit Return again to send
# - cat script.sh | chat  # send a full file; terminate with Ctrl+D
#
# Notes: 
# - Customize the system message as desired. I change mine frequently.

# Check if OPENAI_API_KEY environment variable is set
if [ -z "$OPENAI_API_KEY" ]; then
  echo
  echo "ERROR: The OPENAI_API_KEY environment variable is not set."
  echo
  echo "Add your OpenAI API key as an environment variable. For example, add 'export OPENAI_API_KEY=<your-api-key>' in ~/.zshrc." 
  echo "API key usage instructions: https://help.openai.com/en/articles/4936850-where-do-i-find-my-secret-api-key"
  echo
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo
  echo "ERROR: jq is not installed."
  echo
  echo "Please install jq from https://formulae.brew.sh/formula/jq before running this script."
  echo
  exit 1
fi

# Check if arguments were provided
read_prompt_until_end() {
  local buffer=""
  local line line_upper
  local interactive=1
  if [ ! -t 0 ]; then
    interactive=0
  fi

  while IFS= read -r line; do
    if [ "$interactive" -eq 1 ]; then
      line_upper=$(printf '%s' "$line" | tr '[:lower:]' '[:upper:]')
      [ "$line_upper" = "END" ] && break
    fi
    buffer+="$line"$'\n'
  done
  printf '%s' "${buffer%$'\n'}"
}

if [ "$#" -gt 0 ]; then
  user_content="$@"
else
  if [ -t 0 ]; then
    echo
    echo "You can use this script in three ways:"
    echo "1. Provide the prompt inline: ./chat.sh \"Your prompt\" (quotes recommended if the prompt contains ', ?, *, or [])."
    echo "   Tip for zsh: alias chat='noglob \"$HOME/bin/chat.sh\"' so question marks stay literal."
    echo "2. Run ./chat.sh, type a single-line prompt at the > prompt, and press Return to send."
    echo "3. For multi-line input, press Return on a blank first line to enter multi-line mode and finish by typing 'END' on its own line."
    echo
    echo "Single-line prompt (press Return to send). Leave blank and press Return to switch to multi-line mode:"
    echo "If your text includes literal single quotes, either enter it here or wrap the inline command in double quotes."
    echo

    read -r -p "> " first_line
    if [ -z "$first_line" ]; then
      echo
      echo "Multi-line mode: type your prompt and enter 'END' on a new line when finished."
      echo
      user_content=$(read_prompt_until_end)
    else
      user_content="$first_line"
    fi
  else
    user_content=$(read_prompt_until_end)
  fi
fi

# System prompt describing expected assistant persona & formatting
system_prompt_template() {
  cat <<'EOF'
You are an expert teacher for Mac terminal, Windows command prompt, and PowerShell. Answer in plain text suitable for a terminal: no markdown fences, emojis, ANSI codes, heredocs, or shell commands. Use natural newlines between paragraphs. If you present a list, insert exactly one blank line before it and ensure every bullet begins on a new line with "- "; there must be a blank line between separate lists. Mention a preferred source when helpful.
EOF
}

system_prompt=$(system_prompt_template)
escaped_system_prompt=$(printf '%s' "$system_prompt" | jq -Rs '.')
escaped_user_content=$(printf '%s' "$user_content" | jq -Rs '.')

# Build input array for Responses API
input_payload="[
  {\"role\": \"system\", \"content\": [{\"type\": \"input_text\", \"text\": $escaped_system_prompt}]},
  {\"role\": \"user\", \"content\": [{\"type\": \"input_text\", \"text\": $escaped_user_content}]}
]"

# Allow overriding the default model via OPENAI_CHAT_MODEL env var
MODEL="${OPENAI_CHAT_MODEL:-gpt-5.1-codex-mini}"

# Allow overriding verbosity (low, medium, high) via OPENAI_CHAT_VERBOSITY
TEXT_VERBOSITY="${OPENAI_CHAT_VERBOSITY:-medium}"

print_stream_header() {
  if [ "$header_printed" = false ]; then
    printf "\n🤖 %s\n\n" "$MODEL"
    header_printed=true
  fi
}

handle_stream_event() {
  local event="$1"
  local payload="$2"

  case "$event" in
    "response.output_text.delta")
      local delta=""
      local sentinel=$'\x1f'
      local delta_with_marker
      # Append a non-newline sentinel so command substitution doesn't drop newline-only chunks
      delta_with_marker=$(printf '%s' "$payload" | jq -r '.delta // empty | . + "\u001f"' 2>/dev/null)
      if [ -n "$delta_with_marker" ]; then
        if [[ "$delta_with_marker" == *"$sentinel" ]]; then
          delta=${delta_with_marker%"$sentinel"}
        else
          delta="$delta_with_marker"
        fi
      fi
      if [ -n "$delta" ]; then
        delta=${delta//\\n/$'\n'}
        delta=${delta//\\t/$'\t'}
        delta=${delta//\\r/}
        local prev_char=$'\n'
        if [ -n "$collected_text" ]; then
          prev_char=${collected_text: -1}
        fi
        if [[ "$delta" == -* && "$prev_char" != $'\n' ]]; then
          printf "\n"
          collected_text+=$'\n'
        fi
        print_stream_header
        printf "%s" "$delta"
        collected_text+="$delta"
      fi
      ;;
    "response.error"|"error")
      response_error=$(printf '%s' "$payload" | jq -r '.error.message // .message // empty' 2>/dev/null)
      if [ -z "$response_error" ]; then
        response_error=$(printf '%s' "$payload" | jq -r '.error // empty' 2>/dev/null)
      fi
      [ -z "$response_error" ] && response_error="$payload"
      should_stop_stream=1
      ;;
    "response.done"|"response.completed")
      response_metadata="$payload"
      should_stop_stream=1
      ;;
    *)
      # No-op for other event types like response.created, etc.
      ;;
  esac
}

# Record the start time
start_time=$(date +%s)

# Prepare streaming request body
request_body=$(cat <<EOF
{
  "model": "$MODEL",
  "text": {"verbosity": "$TEXT_VERBOSITY"},
  "input": $input_payload,
  "stream": true
}
EOF
)

header_printed=false
collected_text=""
response_error=""
response_metadata=""
raw_error_payload=""
should_stop_stream=0
current_event=""

while IFS= read -r line; do
  line=${line%$'\r'}
  [ -z "$line" ] && continue

  if [[ "$line" == event:* ]]; then
    current_event=${line#event:}
    current_event=${current_event# }
    continue
  fi

  if [[ "$line" == data:* ]]; then
    payload=${line#data:}
    payload=${payload# }

    if [ "$payload" = "[DONE]" ]; then
      break
    fi

    if [ -z "$current_event" ]; then
      inferred_event=$(printf '%s' "$payload" | jq -r '.type // empty' 2>/dev/null)
      [ -n "$inferred_event" ] && current_event=$inferred_event
    fi

    handle_stream_event "$current_event" "$payload"
    current_event=""
    if [ "$should_stop_stream" -eq 1 ]; then
      should_stop_stream=0
      break
    fi
    continue
  fi

  raw_error_payload+="$line"$'\n'
done < <(curl -sS -N https://api.openai.com/v1/responses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$request_body")

# Record the end time
end_time=$(date +%s)

# Calculate elapsed_time
elapsed_time=$((end_time - start_time))

if [ -z "$response_error" ] && [ -n "$raw_error_payload" ]; then
  open_braces=$(printf '%s\n' "$raw_error_payload" | tr -cd '{' | wc -c | tr -d ' ')
  close_braces=$(printf '%s\n' "$raw_error_payload" | tr -cd '}' | wc -c | tr -d ' ')
  if [ "$close_braces" -lt "$open_braces" ]; then
    diff=$((open_braces - close_braces))
    raw_error_payload="${raw_error_payload}$(printf '%0.s}' $(seq 1 $diff))"
  fi

  response_error=$(printf '%s\n' "$raw_error_payload" | jq -r '.error.message // .message // empty' 2>/dev/null)
  if [ -z "$response_error" ]; then
    response_error="$raw_error_payload"
  fi
  printf '%s\n' "$raw_error_payload" > /tmp/chat_error.json 2>/dev/null
fi

if [ -n "$response_error" ]; then
  printf "\nOpenAI API Error: %s\n" "$response_error"
  exit 1
fi

if [ -z "$collected_text" ]; then
  echo -e "\nOpenAI API Response: No text returned."
  if [ -n "$response_metadata" ]; then
    printf '%s' "$response_metadata" > /tmp/chat_response.json
    echo "Raw payload saved to /tmp/chat_response.json"
  fi
  exit 1
fi

printf '%s' "$collected_text" > /tmp/chat_last_output.txt 2>/dev/null

printf "\n\n⌛️ %ss\n\n" "$elapsed_time"
