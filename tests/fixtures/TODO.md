# TODO

## Open Questions

### What deployment strategy should we use?

We need to decide between blue/green and rolling deployments.

<!-- user answers here -->

### Should we support Neovim 0.9 as well?

Neovim 0.9 is still widely used; dropping it may alienate early adopters.

We decided to require Neovim >= 0.10 to use `vim.system()` and modern APIs.

## Answered Questions

### Which test framework should we use?

We evaluated busted and mini.test.

We chose mini.test because it is Neovim-native and requires no extra install.
