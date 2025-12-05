# Terminal Chat (OpenAI from your shell)

Tiny bash script to send one-off prompts to OpenAI and stream the reply directly in the terminal. No conversation history; every call is stateless.

## Requirements
- Bash, curl
- `jq`
- OpenAI API key set as `OPENAI_API_KEY`

## Install
1) Copy `chat.sh` somewhere on your `PATH` (suggested: `$HOME/bin`).
2) Make it executable: `chmod +x $HOME/bin/chat.sh`.
3) (zsh) Add an alias that disables globbing so `*` and `?` pass through: `alias chat='noglob "$HOME/bin/chat.sh"'`.

Update later with a single command (no git checkout needed):
```sh
curl -fsSLo "$HOME/bin/chat.sh" https://raw.githubusercontent.com/dillweed/terminal_chat/main/chat.sh && chmod +x "$HOME/bin/chat.sh"
```

## Usage
- **Inline**: `chat "Prompt here"`
- **Interactive single line**: run `chat`, type at `>`, press Return.
- **Multiline / piped**:
  - Run `chat`, press Return on the blank prompt, type text, finish with `END` on its own line.
  - Or pipe/redirect: `cat notes.txt | chat`

Tips
- If you skip the alias, wrap prompts that contain shell metacharacters (`* ? [ ]`) in quotes.
- When piping, pass zero CLI arguments; stdin is ignored if args are present. To include an instruction, put it as the first line of stdin (see examples).

## Configuration
- `OPENAI_CHAT_MODEL` (default `gpt-5.1-codex-mini`)
- System message is defined near the bottom of the script; edit to taste.

## What it prints/keeps
- Streams the model output as it arrives.
- Saves the last response to `/tmp/chat_last_output.txt`.
- On API errors, writes the raw payload to `/tmp/chat_error.json`.

## Troubleshooting
- "OPENAI_API_KEY is not set" → export it in your shell rc file.
- "jq is not installed" → `brew install jq` (macOS) or `apt-get install jq`.
- Nothing printed? Ensure the model name is valid and network egress to `api.openai.com` is allowed.

## Examples
- Inline: `chat "What's the rsync syntax to mirror directories on a remote server and log differences without making changes?"`
- Interactive single line: `chat` → at the prompt type `Give me a one-line ffmpeg to downsample audio to 64k mono` → Return
- Interactive multiline: `chat` → press Return on the blank prompt → paste or type multiple lines, e.g.:
  ```
  I need a Bash loop that retries curl up to 5 times with exponential backoff.
  Show me the loop and explain the backoff math.
  END
  ```
- Piped file with instruction (stdin only):
  ```
  { echo "Explain what this script does and point out any obvious bugs."; cat script.sh; } | chat
  ```

## Changelog (recent)
- Switched to streaming Responses API; removed spinner.
- Cleaned prompts/alias instructions; no stray backslash lines.
- Stopped rewriting model output (no automatic bullet insertion).
