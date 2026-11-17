# Dotfiles

These are my config files for the tools I use:

## Emacs

Requires emacs 26 because it uses native line numbers. Go to `.emacs.d` folder to check the config.

Tested on MacOS Mojave

## Vim

I use vim for quick edits, check out the cconf [here](.vimrc)

## Alacrity

A multiplatform terminal emulator. It's simple and configurable by a yaml [config](.alacritty.yml) file.

## Tmux

A terminal multiplexer, easy to handle panes, splitted windows, sessions, etc. 

## ZSH

Go to `zsh` folder to check the config.

## Jujutsu work identity

Keep machine-specific work identities outside this repository. Create
`~/.config/jj/conf.d/work.toml` with:

```toml
[[--scope]]
--when.repositories = ["~/Code/work/"]

[--scope.user]
email = "name@company.com"
```

Jujutsu loads files in `conf.d` after the shared `jj/config.toml`, so this overrides the email only
inside that repository path. Verify it from a work repository with:

```sh
jj config get user.email
```
