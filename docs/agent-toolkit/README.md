# AlchemistDrops Elixir Agent Toolkit

This package contains reusable instructions for agents working in Elixir,
Phoenix, LiveView, Ecto, and JavaScript hook projects. Its release number is
stored in `VERSION`.

## Install one skill

Extract an individual archive and copy its named folder into your project:

```sh
mkdir -p .agents/skills
cp -R ecto-development .agents/skills/
```

## Install the complete toolkit

The complete archive preserves the expected repository paths:

- `.agents/skills/` contains reusable workflows.
- `AGENTS.md` routes project work to the applicable skills.
- `.codex/rules/` contains optional command-safety policies.

Review and merge `AGENTS.md` instead of overwriting an existing project file.
Review every `.rules` file before installing it because command permissions
must match the local environment.

## Install safety rules only

The safety archive keeps `.codex/` at its root. After reviewing the rule,
extract it from the root of your project so it merges into `.codex/rules/`:

```sh
unzip 'elixir-safety-rules-v*.zip' -d .
```

## License

The toolkit is released under the MIT License. See `LICENSE.txt`.
