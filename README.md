# toolkit - a Nushell direnv alternative

:warning: **This is an _EXPERIMENTAL_ module. Use at your own risk.** :warning:

`toolkit` is a nushell module that allows one to dynamically source nushell environments and commands within the current working directory and directory tree. This works similarly to [direnv](https://direnv.net/), with some extra features that direnv lacks.

`toolkit` works by adding `pre_prompt` and `pre_execution` hooks to your env. These hooks activate and deactivate layers of [overlay modules](https://www.nushell.sh/book/overlays.html), searching up your directory tree from your current working directory. The modules are activated top down so that the toolkit modules are layered. Modules lower in the tree will overwrite definitions and environment variables from higher up.

## Table of content

- [toolkit - a Nushell direnv alternative](#toolkit---a-nushell-direnv-alternative)
  - [Table of content](#table-of-content)
  - [Installation](#installation)
    - [With `nupm`](#with-nupm)
    - [With `git clone`](#with-git-clone)
  - [Configuration](#configuration)
    - [Options](#options)
  - [Library](#library)

## Installation

:warning: **INSTALL METHODS NOT TESTED, USE AT YOUR OWN RISK** :warning:

### With `nupm`

Install and configure [nupm](https://github.com/nushell/nupm) and then run

```nushell
nupm install https://github.com/palani-johnson/toolkit --git
```

Then in your `config.nu` add

```nushell
use toolkit
toolkit init
```

### With `git clone`

Clone this repo, then in your `env.nu` add

```nushell
$env.NU_LIB_DIRS ++= [
  "/path/to/toolkit-repo"
]
```

Then in your `config.nu` add

```nushell
use toolkit
toolkit init
```

## Configuration

The configuration file is sourced from either `$env.XDG_CONFIG_HOME` or `$env.HOME/.config`. A file named `toolkit` with any of the following file extensions (in order of precedence) can be used:

- toml
- json
- yaml
- yml
- nuon

If no config file is found, a file named `toolkit.toml` with default settings will be created in the config directory.

### Options

A `--max-layers` parameter (default 5) can be passed to `toolkit init`, controlling the maximum number of layers toolkit will attempt to load. More layers may negatively impact performance. All other configuration options can be configured in your toolkit config file:

| Param        | Type                | Description                                         | Default        |
| ------------ | ------------------- | --------------------------------------------------- | -------------- |
| filenames    | `list<string>`      | list of allowed file names                          | ["toolkit.nu"] |
| allowed_dirs | `list<string>`      | list of allowed directory paths. must be absolute.  | []             |
| log_level    | `oneof<string int>` | The configured log level (see `toolkit/logging.nu`) | info           |

## Library

Toolkit has (will have) a small library of code for common tasks. Access by using the lib in your toolkit module:

```nushell
use toolkit/lib *
```
