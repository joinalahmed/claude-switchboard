# Switchboard

Choose which cloud Claude Code talks to: Anthropic, Google Vertex AI, Amazon Bedrock, Azure AI Foundry, or your own gateway such as LiteLLM. Switchboard is a native Mac app plus a small command-line tool, `ccp`, that does the work.

- Keep several providers side by side and launch Claude Code with any of them.
- Make one the default for plain `claude` in your terminal.
- Keep keys in the macOS Keychain, not in files.
- See how much each provider has been used.

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
| **Providers** | One page per provider: pick a project folder, launch Claude Code in Terminal or iTerm, test the connection, edit settings, see exactly which variables Claude Code will get. |
| **Add provider** | Choose a type (Anthropic API, Anthropic login, Vertex AI, Bedrock, Foundry, gateway, LiteLLM, custom) and fill in a short form. Keys go to the Keychain. |
| **Terminal** | Pick the provider plain `claude` uses, and turn on the shell hook that makes it so. Finds provider variables hiding in Claude Code's own settings and removes them on request. |
| **Usage** | Requests, sessions and tokens per provider, per day and per model. |
| **Health check** | Looks for anything that would stop Claude Code from using the provider you chose. |

## The command line

```sh
ccp                       # Claude Code with the default provider
ccp vertex -c             # a named provider, extra arguments go to claude
ccp add                   # create a provider (asks for each value)
ccp list                  # providers, * marks the default
ccp default bedrock       # change the default
ccp test vertex           # one real request through a provider
ccp doctor                # things that could override your choice
ccp shell install         # plain `claude` follows the default provider
ccp overrides [--fix]     # find, or remove, provider variables in ~/.claude/settings*.json
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

## Plain `claude` and settings that override it

`ccp shell install` (or the switch on the app's Terminal page) adds a clearly marked `claude` function to your `~/.zshrc` that runs `ccp run`. Your original file is saved once as `.zshrc.ccp-backup`, and `ccp shell remove` takes the block out again.

Claude Code applies the `env` block of `~/.claude/settings.json` over your shell, so provider variables there beat any provider you pick. `ccp overrides` lists them, and `ccp overrides --fix` removes them after saving a backup next to the file. The file is rewritten as plain JSON, so key order and formatting may change.

Editors and apps that start Claude Code without your shell, such as IDE extensions, are not affected by any of this.

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
git tag v1.0.0 && git push origin v1.0.0
```

The repository holds no image files. The app icon is drawn from `app/icon.swift` when the app is built.

## License

MIT. See [LICENSE](LICENSE).
