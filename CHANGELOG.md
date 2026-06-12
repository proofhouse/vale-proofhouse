# Changelog

## [0.1.0](https://github.com/proofhouse/vale-proofhouse/compare/f8a77c1b691873d18662b34663111fdf9711f9dc..v0.1.0) - 2026-06-12

### Features

- add an agent-optimized output template - ([a4aea21](https://github.com/proofhouse/vale-proofhouse/commit/a4aea212ca6940692a058a4457da9b531a56df3b)) - [@tbhb](https://github.com/tbhb)
- add the proofhouse vale style - ([9b4170a](https://github.com/proofhouse/vale-proofhouse/commit/9b4170a24b4a333425f3d0181f6d7b84000c4b31)) - [@tbhb](https://github.com/tbhb)

#### Bug Fixes

- ignore the package build output in cspell - ([69a7d36](https://github.com/proofhouse/vale-proofhouse/commit/69a7d365e38327b1fb06fe10e5dfac4039437963)) - [@tbhb](https://github.com/tbhb)

#### Documentation

- add agent instructions and worktree rules - ([463e9d0](https://github.com/proofhouse/vale-proofhouse/commit/463e9d0ef67fde6da53197a10874be99e2ce7610)) - [@tbhb](https://github.com/tbhb)

#### Build system

- add Justfile recipes for linting, testing, and packaging - ([1b16a3d](https://github.com/proofhouse/vale-proofhouse/commit/1b16a3da6bec2b44c7a5fb16a9d17def248ec106)) - [@tbhb](https://github.com/tbhb)

#### Continuous Integration

- put Homebrew on the runner PATH before brew bundle - ([534b9c5](https://github.com/proofhouse/vale-proofhouse/commit/534b9c517851732f22490218892c965a0d33ba89)) - [@tbhb](https://github.com/tbhb)
- add CODEOWNERS and renovate configuration - ([f01d60d](https://github.com/proofhouse/vale-proofhouse/commit/f01d60da55feea7bd6169fc3cd479dc6aa31cb3e)) - [@tbhb](https://github.com/tbhb)
- call the shared reusable workflows for the remaining gates - ([172f6cc](https://github.com/proofhouse/vale-proofhouse/commit/172f6cc898d2850a8bd118debc19dc1a4ec4c335)) - [@tbhb](https://github.com/tbhb)
- add the ci, security, and CodeQL workflows - ([9a22ccd](https://github.com/proofhouse/vale-proofhouse/commit/9a22ccded41db57b4c68a9c759988a82cd23a107)) - [@tbhb](https://github.com/tbhb)
- add the release workflow publishing the vale package - ([e976582](https://github.com/proofhouse/vale-proofhouse/commit/e976582c0763c9419ec1c858871bc2315539027e)) - [@tbhb](https://github.com/tbhb)
- lint rule messages with the prose styles - ([8405e72](https://github.com/proofhouse/vale-proofhouse/commit/8405e72048c1b1c68a39f4ec054f17fbd7c6fdd8)) - [@tbhb](https://github.com/tbhb)
- add prek with shared commit-message gates - ([d995bca](https://github.com/proofhouse/vale-proofhouse/commit/d995bca509b4dada80c18640bd4f3c08f6a1011b)) - [@tbhb](https://github.com/tbhb)
- add yamllint for YAML linting - ([6750977](https://github.com/proofhouse/vale-proofhouse/commit/6750977f33999fa6234c5d64abfba57bf8c0864f)) - [@tbhb](https://github.com/tbhb)
- add biome for JSON/JS/TS linting and formatting - ([e62c65a](https://github.com/proofhouse/vale-proofhouse/commit/e62c65acfc3efc4d619570da42bea4b860beecfc)) - [@tbhb](https://github.com/tbhb)
- add rumdl markdown linter - ([43bb927](https://github.com/proofhouse/vale-proofhouse/commit/43bb927394072c00aa7ad24b2dbd84597b5dbb3a)) - [@tbhb](https://github.com/tbhb)
- add cspell spelling checker with project dictionary - ([13e2bb2](https://github.com/proofhouse/vale-proofhouse/commit/13e2bb27d944068f55dbc07d2ad4783d1370c60a)) - [@tbhb](https://github.com/tbhb)
- add vale prose linter with proofhouse styles and vocabulary - ([61e1de6](https://github.com/proofhouse/vale-proofhouse/commit/61e1de6e4452fb73c4c75ea205882eaeeb044630)) - [@tbhb](https://github.com/tbhb)

#### Refactoring

- retire the Passive rule superseded by ai-tells - ([7c8d64f](https://github.com/proofhouse/vale-proofhouse/commit/7c8d64fb86d2a8977625833b8bddd0ccf2045b49)) - [@tbhb](https://github.com/tbhb)

#### Style

- apply vale fixes to existing tree - ([c722995](https://github.com/proofhouse/vale-proofhouse/commit/c72299531b17248da46bba72fa7edb71e4336f44)) - [@tbhb](https://github.com/tbhb)
