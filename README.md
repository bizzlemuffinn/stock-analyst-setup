# Stock analyst setup for Claude

One script that turns Claude into a personal stock analyst. It installs a set
of free analysis skills, asks a few questions about you and your money, and
saves the answers so Claude remembers them every time.

## What you need

- A Mac or Linux computer
- A paid Claude plan
- Python 3.8 or newer (on a Mac, the script tells you how to get it)

## Two ways to use it

**Give it to Claude.** Download `stock-analyst-setup.sh`, attach it in Claude
and say "set this up for me". The top of the file tells Claude what to do. It
works best in Claude Code, which can run the setup itself.

**Run it yourself.** Open Terminal and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/bizzlemuffinn/stock-analyst-setup/main/stock-analyst-setup.sh -o ~/Downloads/stock-analyst-setup.sh
bash ~/Downloads/stock-analyst-setup.sh
```

The script asks eight questions (each can be skipped), then starts Claude with
a first analysis. Next time, open Terminal and type `cd ~/trading && claude`.

## What it sets up

| Where | What |
|---|---|
| `~/.claude/skills/trader-*` | 11 analysis skills: company earnings, news, chart scanning, trade planning and risk checks |
| `~/trading/trader/config.json` | Your budget and safety limits |
| `~/trading/CLAUDE.md` | Your profile and the rules Claude follows |

Running the script again is safe. It leaves installed skills alone and backs
up your old answers.

## Good to know

- The skills cover US-listed stocks only, and amounts are in US dollars.
- Prices come from free sources and are delayed.
- Trading is set to practice (paper) money. The script never connects a broker.
- This is analysis to help you decide, not financial advice. Nothing here
  promises a return.

## Credit

The skills come from
[Jakeschincariol/day-trader-skill](https://github.com/Jakeschincariol/day-trader-skill)
(MIT licence). The script downloads the latest version from that repository
each time it runs.
