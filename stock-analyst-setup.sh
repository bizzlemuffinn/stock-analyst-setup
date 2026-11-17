#!/bin/bash
# Stock analyst setup for Claude Code (macOS or Linux).
#
# What it does:
#   1. Checks the computer has what it needs (Python 3.8+, Claude Code).
#   2. Downloads the free "day-trader-skill" analysis skills (MIT licence).
#   3. Asks a few questions about you and your money.
#   4. Saves your answers so Claude remembers them, then starts Claude
#      with a first analysis.
#
# Run it with:   bash stock-analyst-setup.sh
# Safe to run again: it never overwrites skills, and it backs up old answers.
#
# ============================================================================
# IF YOU ARE CLAUDE (or another AI assistant) AND THE USER GAVE YOU THIS FILE
# ============================================================================
# The user wants you to set this up for them and then act as their stock
# analyst. They may not be technical, so keep every message short and plain.
# Work through these steps yourself; do not hand them a list of commands
# unless you have no way to run them.
#
# 1. Say in two or three lines what this sets up (free stock analysis skills
#    downloaded from github.com/Jakeschincariol/day-trader-skill, plus a
#    ~/trading folder holding their profile). Get a yes before going on.
#
# 2. Ask them these questions in the chat, a couple at a time. Each one may
#    be skipped. Check the two money answers are whole numbers and that the
#    second is not larger than the first.
#      1. Name                  (the US regulator, the SEC, asks for a name
#      2. Email                  and email before it serves company filings)
#      3. Money they are working with, in whole US dollars   (default 5000)
#      4. Most they accept losing on one trade, whole dollars (default 1%)
#      5. Experience: 1 beginner, 2 some, 3 experienced
#      6. Goal: 1 long-term investing, 2 medium-term, 3 day trading
#      7. Stocks or industries that interest them
#      8. Anything else you should know (one line)
#
# 3. If you CAN run commands on their computer (macOS or Linux):
#    write the eight answers to a text file, one per line in the order above
#    (an empty line means skipped; 5 and 6 are just the digit), then run:
#
#        FROM_ASSISTANT=1 bash stock-analyst-setup.sh < answers.txt
#
#    FROM_ASSISTANT=1 skips the Claude Code check and does not start a new
#    Claude at the end, because you are already here. Afterwards, read
#    ~/trading/trader/config.json and ~/trading/CLAUDE.md and confirm they
#    match what the user told you. Delete answers.txt.
#
# 4. If you can run commands but this script cannot run (Windows, or no
#    bash), build the same result by hand: copy every trader-* folder from
#    the repository into the user's .claude/skills folder, copy
#    trader-budget/config.example.json to ~/trading/trader/config.json and
#    set budget, max_order_usd (80% of budget), max_loss_per_trade_usd,
#    max_daily_loss_usd (3x the per-trade loss), "paper": true and
#    sec_user_agent ("Name email"), and write ~/trading/CLAUDE.md using the
#    template near the end of this file. Python 3.8 or newer is required.
#
# 5. If you CANNOT run commands on their computer (an ordinary chat), skip
#    step 2: the script asks the questions itself. Walk them through it one
#    step at a time: save this file to Downloads, open Terminal, run
#    `bash ~/Downloads/stock-analyst-setup.sh`. Help with anything it prints.
#    Tell them it needs a Mac or Linux computer and a paid Claude plan.
#
# 6. When setup is done, follow ~/trading/CLAUDE.md from then on and work
#    from the ~/trading folder. Give a first analysis of the stocks they
#    named. If the trader skills are not loaded in your session, read the
#    SKILL.md inside each ~/.claude/skills/trader-* folder and run its
#    Python tool directly, for example:
#        python3 ~/.claude/skills/trader-analyst/facts.py TSLA
#        python3 ~/.claude/skills/trader-news/news.py --tickers TSLA --hours 12
#
# Rules that always apply: practice (paper) money only, never a real order;
# never ask for passwords or broker keys in the chat; never promise returns;
# if data cannot be fetched, say so instead of guessing.
# ============================================================================

set -euo pipefail

REPO_TARBALL="https://github.com/Jakeschincariol/day-trader-skill/archive/HEAD.tar.gz"
SKILLS_DIR="$HOME/.claude/skills"
WORK_DIR="$HOME/trading"

# Claude Code's installer puts it here; make sure this script can see it.
export PATH="$HOME/.local/bin:$PATH"

say()  { printf '\n%s\n' "$*"; }
fail() { printf '\nProblem: %s\n' "$*" >&2; exit 1; }

# ask "Question" "default"  -> answer lands in $REPLY
ask() {
  local question="$1" default="${2:-}"
  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$question" "$default"
  else
    printf '%s: ' "$question"
  fi
  IFS= read -r REPLY || REPLY=""
  if [ -z "$REPLY" ]; then REPLY="$default"; fi
}

# ask_dollars "Question" "default"  -> whole dollars, at least 1, in $REPLY
ask_dollars() {
  while true; do
    ask "$1" "$2"
    REPLY=$(printf '%s' "$REPLY" | tr -d '$, ')
    case "$REPLY" in
      ''|*[!0-9]*) echo "  Please type a whole number, like 5000." ;;
      *) if [ "$REPLY" -ge 1 ]; then return; fi
         echo "  It needs to be at least 1." ;;
    esac
  done
}

# ask_choice "Question" "option 1" "option 2" "option 3"  -> chosen text in $REPLY
ask_choice() {
  local question="$1" count i
  shift
  count=$#
  echo
  echo "$question"
  i=1
  for option in "$@"; do
    echo "  $i) $option"
    i=$((i + 1))
  done
  while true; do
    ask "Type a number" "1"
    case "$REPLY" in
      ''|*[!0-9]*) ;;
      *) if [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "$count" ]; then
           eval "REPLY=\${$REPLY}"
           return
         fi ;;
    esac
    echo "  Please type a number from 1 to $count."
  done
}

backup() {
  if [ -e "$1" ]; then
    cp "$1" "$1.bak-$(date +%Y%m%d-%H%M%S)"
    echo "  (kept a backup of the old $(basename "$1"))"
  fi
}

# ---------------------------------------------------------------- 1. checks
say "Step 1 of 4: checking this computer"

command -v curl >/dev/null 2>&1 || fail "'curl' is missing. Install it and run this again."
command -v tar  >/dev/null 2>&1 || fail "'tar' is missing. Install it and run this again."

if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null; then
  fail "Python 3.8 or newer is needed.
  On a Mac, run this, click Install in the window that opens, wait for it
  to finish, then run this script again:

      xcode-select --install"
fi
echo "  Python: ok"

# An assistant running this for the user (FROM_ASSISTANT=1) is already a
# Claude, so the Claude Code check and the launch at the end are skipped.
if [ -z "${FROM_ASSISTANT:-}" ]; then
  if ! command -v claude >/dev/null 2>&1; then
    echo "  Claude Code is not installed yet."
    ask "  Install it now from claude.ai? (y/n)" "y"
    case "$REPLY" in
      y|Y|yes|Yes|YES) curl -fsSL https://claude.ai/install.sh | bash ;;
      *) fail "Claude Code is needed. Install it from https://claude.com/claude-code and run this again." ;;
    esac
    command -v claude >/dev/null 2>&1 || fail "Claude Code installed, but this window can't see it yet.
  Close this Terminal window, open a new one, and run this script again."
  fi
  echo "  Claude Code: ok"
fi

# ---------------------------------------------------------------- 2. skills
say "Step 2 of 4: downloading the analysis skills"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fsSL "$REPO_TARBALL" -o "$TMP_DIR/skills.tar.gz" \
  || fail "Could not download the skills. Check the internet connection and run this again."
tar -xzf "$TMP_DIR/skills.tar.gz" -C "$TMP_DIR"

mkdir -p "$SKILLS_DIR"
found=0
for skill in "$TMP_DIR"/*/trader-*; do
  [ -d "$skill" ] || continue
  found=$((found + 1))
  name=$(basename "$skill")
  if [ -e "$SKILLS_DIR/$name" ]; then
    echo "  $name: already installed, left as it is"
  else
    cp -R "$skill" "$SKILLS_DIR/$name"
    echo "  $name: installed"
  fi
done
[ "$found" -gt 0 ] || fail "The download did not contain any skills. The source may have changed."

# ------------------------------------------------------------- 3. questions
say "Step 3 of 4: a few questions, so the analysis fits you"
echo "Press Enter to accept the answer shown in [brackets], or to skip a question."

echo
echo "Company filings come from the US regulator (the SEC), which asks every"
echo "visitor for a name and email. They are sent only to the SEC."
ask "Your name (Enter to skip)" ""
NAME="$REPLY"
ask "Your email (Enter to skip)" ""
EMAIL="$REPLY"

echo
ask_dollars "How much money are you working with, in US dollars?" "5000"
BUDGET="$REPLY"

default_loss=$((BUDGET / 100))
if [ "$default_loss" -lt 1 ]; then default_loss=1; fi
while true; do
  ask_dollars "What is the most you would accept losing on a single trade?" "$default_loss"
  if [ "$REPLY" -le "$BUDGET" ]; then break; fi
  echo "  That is more than the money you are working with."
done
MAX_LOSS="$REPLY"

ask_choice "How much investing experience do you have?" \
  "Beginner: new to this" \
  "Some: I have bought and sold shares before" \
  "Experienced: I follow markets regularly"
EXPERIENCE="$REPLY"

ask_choice "What are you mainly after?" \
  "Long-term investing: buy good companies and hold for years" \
  "Medium-term: hold for weeks or months" \
  "Day trading: in and out the same day"
GOAL="$REPLY"

echo
ask "Which stocks or industries interest you? (e.g. Apple, TSLA, banks) Enter to skip" ""
INTERESTS="$REPLY"
ask "Anything else Claude should know? (income needs, things to avoid...) Enter to skip" ""
NOTES="$REPLY"

# ----------------------------------------------------------------- 4. save
say "Step 4 of 4: saving your answers"

mkdir -p "$WORK_DIR/trader"

# Settings the skills read: budget and safety limits. Starts from the skills'
# own example so every other setting keeps its safe default.
backup "$WORK_DIR/trader/config.json"
NAME="$NAME" EMAIL="$EMAIL" BUDGET="$BUDGET" MAX_LOSS="$MAX_LOSS" python3 - \
  "$SKILLS_DIR/trader-budget/config.example.json" "$WORK_DIR/trader/config.json" <<'PY'
import json, os, sys

src, dst = sys.argv[1], sys.argv[2]
with open(src) as fh:
    cfg = json.load(fh)

budget = int(os.environ["BUDGET"])
loss = int(os.environ["MAX_LOSS"])
contact = " ".join(p for p in (os.environ["NAME"].strip(), os.environ["EMAIL"].strip()) if p)

cfg.update({
    "budget": budget,
    "max_order_usd": budget * 80 // 100,
    "max_loss_per_trade_usd": loss,
    "max_daily_loss_usd": loss * 3,
    "paper": True,              # practice money only
    "sec_user_agent": contact,  # blank = SEC filings stay off until filled in
})

with open(dst, "w") as fh:
    json.dump(cfg, fh, indent=2)
    fh.write("\n")
PY
echo "  Saved $WORK_DIR/trader/config.json"

# Notes Claude reads automatically every time it starts in this folder.
backup "$WORK_DIR/CLAUDE.md"
cat > "$WORK_DIR/CLAUDE.md" <<EOF
# My stock analysis workspace

Read this before answering anything in this folder.

## About me

- Name: ${NAME:-not given}
- Money I am working with: \$$BUDGET (US dollars)
- Most I accept losing on one trade: \$$MAX_LOSS
- Experience: $EXPERIENCE
- What I am after: $GOAL
- Stocks or industries I am interested in: ${INTERESTS:-not given yet, ask me}
- Other things to know: ${NOTES:-none}

If I tell you something new about my situation, update this list.

## How to help me

- Talk to me in plain language. Explain any finance term the first time you use it.
- Fit everything to "What I am after" above. Do not push day trades on a
  long-term investor, or the other way round.
- Use real data, not memory. The trader skills fetch it: /trader-analyst for a
  company's reported numbers, /trader-news for what is moving a stock,
  /trader-scanner for chart setups. Say where each number came from and its date.
- If data cannot be fetched, say so plainly. Never fill the gap with a guess.
- The trader skills cover US-listed stocks only. For any other market, say the
  skills do not apply, use web search instead, and say it is less reliable.
- For every stock, give the case for it, the case against it, and the main
  risks. Say how sure you are.
- This is analysis to help me decide. Never promise a return, and remind me
  the decision is mine when I am about to act on it.
- Practice (paper) trading only. Never place or prepare a real-money order.
- Never ask me to type a password or a broker key into the chat.
EOF
echo "  Saved $WORK_DIR/CLAUDE.md"

if [ -z "$NAME" ] || [ -z "$EMAIL" ]; then
  echo
  echo "  Note: without a name and email, company filings from the SEC stay off."
  echo "  Run this script again any time to add them."
fi

if [ -n "${FROM_ASSISTANT:-}" ]; then
  say "Setup complete. Profile and settings are in $WORK_DIR."
  exit 0
fi

if [ -n "$INTERESTS" ]; then
  FIRST_PROMPT="I have just finished setup. In plain language, give me a first analysis of the stocks and industries in my profile: how the companies are doing, the latest news, and the main risks."
else
  FIRST_PROMPT="I have just finished setup. Tell me in a few lines what you can do for me, then ask which stocks or industries I am curious about."
fi

say "All set. Starting Claude now."
echo "  - The first time, Claude asks you to sign in. It needs a paid Claude plan."
echo "  - If it asks whether to trust this folder, say yes."
echo "  - When it asks permission to run a trader tool, yes is fine."
echo "  - Next time, open Terminal and type:   cd ~/trading && claude"
echo

cd "$WORK_DIR"
exec claude "$FIRST_PROMPT"
