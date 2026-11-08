# Switchboard

A Claude Code provider switcher for macOS. Choose which cloud Claude Code talks to: Anthropic (API key or subscription login), Google Vertex AI, Amazon Bedrock, Azure AI Foundry, or your own gateway such as LiteLLM. Switchboard is a native Mac app (SwiftUI) plus a small command-line tool, `ccp`, that does the work.

- Keep several providers side by side and switch Claude Code between them with one click.
- The switch applies everywhere Claude Code starts: Terminal, iTerm, VS Code and other editors.
- Keep API keys and tokens in the macOS Keychain, not in files.
- Launch one session with a different provider without switching.
- See how much each provider has been used.

<p align="center">
  <img src="https://github.com/joinalahmed/claude-switchboard/releases/download/v1.1.0/shot-vertex.jpg" alt="A provider page: Vertex AI, with a blue banner, launch and test buttons" width="880">
</p>

<table>
  <tr>
    <td width="50%"><img src="https://github.com/joinalahmed/claude-switchboard/releases/download/v1.1.0/shot-add.jpg" alt="Choosing a provider type: each type has its own color and mark"></td>
    <td width="50%"><img src="https://github.com/joinalahmed/claude-switchboard/releases/download/v1.1.0/shot-litellm.jpg" alt="The same page for a LiteLLM provider, in green"></td>
  </tr>
  <tr>
    <td width="50%"><img src="https://github.com/joinalahmed/claude-switchboard/releases/download/v1.1.0/shot-usage.jpg" alt="Usage: requests and tokens per provider, per day and per model"></td>
    <td width="50%"><img src="https://github.com/joinalahmed/claude-switchboard/releases/download/v1.1.0/shot-terminal.jpg" alt="Terminal: which provider plain claude uses"></td>
  </tr>
</table>

Every provider type has its own colors, mark and banner pattern, so you can tell at a glance which cloud you are about to use. The screenshots are hosted with the release, not in the repository.

## Install

### Download (easiest)

1. Get **Switchboard-x.y.z-macos.zip** from the [latest release](https://github.com/joinalahmed/claude-switchboard/releases/latest), unzip it, and move **Switchboard.app** to your Applications folder.
2. The app isn't notarized, so macOS blocks the first launch. Clear the block once:
   ```sh
   xattr -dr com.apple.quarantine /Applications/Switchboard.app
   ```
   Or open System Settings > Privacy & Security and choose Open Anyway.
3. Open it. On first launch it installs the `ccp` command to `~/bin` and the provider templates to `~/.claude-providers`.

The download runs natively on Apple silicon and Intel. Each release lists SHA-256 checksums.

### From source

```sh
git clone https://github.com/joinalahmed/claude-switchboard.git
cd claude-switchboard
./install.sh
```

This installs `ccp` to `~/bin`, the provider templates to `~/.claude-providers/templates`, and the app to `~/Applications/Switchboard.app`. The app compiles itself the first time you open it, which takes about a minute and needs Xcode or the Command Line Tools (`xcode-select --install`).

### Requirements

macOS 14 or later, and [Claude Code](https://docs.claude.com/en/docs/claude-code) already installed. `ccp` alone also works on Linux apart from Keychain storage: `./install.sh --no-app`.

## The app

| | |
|---|---|
| **Switch** | Click the provider every new `claude` session should use. Shows what Claude Code is set to right now, spots settings that were changed by hand, and can keep those as a provider of their own. |
| **Providers** | One page per provider: switch to it, launch one session with it in Terminal or iTerm, test the connection, edit settings, see exactly which variables Claude Code will get. |
| **Add provider** | Choose a type (Anthropic API, Anthropic login, Vertex AI, Bedrock, Foundry, gateway, LiteLLM, custom) and fill in a short form. Keys go to the Keychain. |
| **Usage** | Requests, sessions and tokens per provider, per day and per model. |
| **Health check** | Looks for anything that would stop Claude Code from using the provider you chose. |

## The command line

```sh
ccp use bedrock           # switch: every new claude session uses bedrock
ccp status                # what claude is set to, and whether the settings still match
ccp                       # Claude Code with the active provider
ccp vertex -c             # one session with another provider, extra arguments go to claude
ccp add                   # create a provider (asks for each value)
ccp import corp           # keep the settings now in ~/.claude/settings.json as a provider
ccp list                  # providers, * marks the active one
ccp test vertex           # one real request through a provider
ccp doctor                # things that could override your choice
ccp shell install         # optional: count plain `claude` launches in Usage
ccp overrides [--fix]     # find, or remove, provider variables in settings.json that ccp did not write
```

`ccp help` shows everything.

## How it works

Each provider is a small shell file in `~/.claude-providers/NAME.env` that exports the variables Claude Code reads for that provider (`CLAUDE_CODE_USE_VERTEX`, `ANTHROPIC_BASE_URL`, `AWS_REGION`, and so on). `ccp` clears every variable any provider uses, loads the one you chose, and runs `claude`. Nothing leaks from one provider into the next.

Secrets are stored in the Keychain under `ccp-NAME-VARIABLE`, and the provider file reads them with `ccp_secret`. A provider file never contains the key itself.

### Adding a provider type

Drop a `TYPE.tpl` into `~/.claude-providers/templates/`. It appears in both `ccp add` and the app.

```sh
# description: Claude Code through my gateway
# var: ANTHROPIC_BASE_URL | Gateway URL | https://gateway.example.com | required
# secret: ANTHROPIC_AUTH_TOKEN | Gateway key | | required
# var: ANTHROPIC_MODEL | Model name (blank = Claude Code's default) |
export ANTHROPIC_BASE_URL={{ANTHROPIC_BASE_URL}}
export ANTHROPIC_AUTH_TOKEN={{ANTHROPIC_AUTH_TOKEN}}
?export ANTHROPIC_MODEL={{ANTHROPIC_MODEL}}
```

`# var:` lines are plain questions (`name | prompt | default | required`), `# secret:` lines are answers that go to the Keychain, and `{{NAME}}` marks where an answer is placed. A leading `?` drops a line when its answer is blank. See `templates/` for the built-in ones.

## How switching works

Claude Code reads the `env` block of `~/.claude/settings.json` at the start of every session and applies it over your shell's environment, wherever the session starts. `ccp use NAME` (or a click in the app) writes the provider's variables into that block, so the switch reaches Terminal windows, iTerm, VS Code and other editors alike. Sessions already running keep their provider until restarted.

Keys and tokens are not written to the file. Claude Code's `apiKeyHelper` setting is pointed at `ccp auth`, which reads the active provider's key from the Keychain when Claude Code asks for it. The two exceptions are Bedrock API keys and Foundry API keys, which Claude Code can only take from a variable; `ccp use` says so when it writes one.

`ccp NAME` runs one session with another provider without switching: the session gets the provider's variables and a one-session settings override, so the active provider's entries don't apply to it.

Before the first switch, `ccp status` tells you if `~/.claude/settings.json` already holds provider variables typed by hand. `ccp import NAME` keeps them as a provider (secrets move to the Keychain), after which you can switch between it and the others. The file is written as plain JSON, so key order and formatting may change; the previous version is kept next to it as `settings.json.ccp-backup`, and the very first version as `settings.json.ccp-original`.

The optional shell hook (`ccp shell install`, or the Usage switch on the Switch page) makes plain `claude` run through `ccp run`, so launches are recorded for the Usage page. Switching never needs it.

## Usage tracking

Every launch through `ccp` is recorded in `~/.claude-providers/usage/runs.log` with the time, provider and folder. The app reads Claude Code's own session files in `~/.claude/projects` and credits each message to the provider that was running in that folder at that moment.

- Sessions not started through `ccp` show up as "Not via ccp".
- It counts requests and tokens. It does not estimate cost, because prices differ by provider and model.
- The attribution matches by time and folder, so two sessions running in the same folder at once can be mixed up.

## Uninstall

```sh
ccp shell remove
rm -rf ~/Applications/Switchboard.app ~/bin/ccp
# optional: your providers and usage log
rm -rf ~/.claude-providers
```

Keychain items named `ccp-*` can be removed in Keychain Access, or with `ccp remove NAME` before deleting the folder.

## Releases

Pushing a version tag builds the app on GitHub (universal binary, ad-hoc signed) and attaches it to a release:

```sh
git tag v1.1.0 && git push origin v1.1.0
```

The repository holds no image files. The app icon is drawn from `app/icon.swift` when the app is built.

## License

MIT. See [LICENSE](LICENSE).
