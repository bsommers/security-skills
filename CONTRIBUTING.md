# Contributing

## Layout

Each skill is a directory named `security-*` (or a utility skill such as `tests/`, `brochure/`) containing a single `SKILL.md` with YAML front matter (`name`, `description`, `allowed-tools`) followed by the instructions. To add a skill, create `<skill-name>/SKILL.md`, add it to the skill list in `install.sh`, and document it in `README.md`. To modify one, edit its `SKILL.md` and keep `README.md` and `docs/` consistent with it.

## Testing

There is no automated test suite in this repository (`tests/SKILL.md` is a skill that generates tests for other projects, not tests for this repo). Verify changes by:

```bash
bash -n install.sh
HOME=$(mktemp -d) ./install.sh --dry-run          # preview, changes nothing
HOME=$(mktemp -d) ./install.sh && HOME=$(mktemp -d) ./install.sh --uninstall
```

Always use a throwaway `HOME` when testing the installer. Then try the changed skill on a sample project.

## Pull requests

- Keep each PR focused; describe what changed and how you verified it.
- Update docs when behavior changes.
- Never include secrets, tokens, or real credentials in examples; use obvious placeholders.
- Use https clone URLs in docs: `git clone https://github.com/bsommers/security-skills.git`.
