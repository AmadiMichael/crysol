# Crysol • [![Unit Tests][tests-shield]][tests-shield-url] [![License: MIT][license-shield]][license-shield-url] [![Solidity][solidity-shield]][solidity-shield-url]

> **Warning**
>
> Very much work in progress! Don't use!

## Installation

Install module via Foundry:

```bash
$ forge install pmerkleplant/crysol
```

## Contributing

The project uses the Foundry toolchain. You can find installation instructions [here](https://getfoundry.sh/).

Setup:

```bash
$ git clone https://github.com/pmerkleplant/crysol
$ cd crysol/
$ forge install
```

Run tests:

```bash
$ forge test
$ forge test -vvvv # Run with full stack traces
$ FOUNDRY_PROFILE=intense forge test # Run in intense mode
```

Lint:

```bash
$ forge fmt [--check]
```

Update gas snapshots:

```bash
$ forge snapshot --nmt "Fuzz" [--check]
```

[tests-shield]: https://github.com/pmerkleplant/crysol/actions/workflows/unit-tests.yml/badge.svg
[tests-shield-url]: https://github.com/pmerkleplant/crysol/actions/workflows/unit-tests.yml

[license-shield]: https://img.shields.io/badge/License-MIT-yellow.svg
[license-shield-url]: https://opensource.org/licenses/MIT

[solidity-shield]: https://img.shields.io/badge/solidity-%3E=0.8.16%20%3C=0.8.21-aa6746
[solidity-shield-url]: https://github.com/pmerkleplant/crysol/actions/workflows/solc-version-tests.yml
