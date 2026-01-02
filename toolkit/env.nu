
const default_config = {
  filenames: ["toolkit.nu"]
  allowed: []
  log_level: "info"
}

# Get the default toolkit configuration
export def "config default" []: [
  nothing -> record<
    filenames: list<string>
    allowed: list<string>
    log_level: oneof<string int>
  >
] {
  $default_config
}

# Get the path to the toolkit configuration file.
# Creates a default config file if none exists.
#
# This command will
#   1) get the config directory from `$env.XDG_CONFIG_HOME` or `$env.HOME/.config`.
#   2) look for a config file named `toolkit` with one of the following extensions (in order):
#        - toml
#        - json
#        - yaml
#        - yml
#        - nuon
#   3) if no config file is found, create a default `toolkit.toml` file in the config directory.
export def "config path" []: nothing -> string {
  let config_dir = $env.XDG_CONFIG_HOME? | default {$env.HOME | path join '.config'}

  [ "toml" "json" "yaml" "yml" "nuon" ]
  | each { |ext| $config_dir | path join $"toolkit.($ext)" }
  | where { path exists }
  | get 0?
  | default { 
      let path = $config_dir | path join "toolkit.toml" 

      mkdir $config_dir
      config default | save $path

      $path 
    }
}

# Get the current toolkit configuration
export def --env config []: [
  nothing -> record<
    filenames: list<string>
    allowed: list<string>
    log_level: oneof<string int>
  >
] {
  let config_path = config path

  if $env.toolkit.sync? == null or (ls $config_path | get modified.0) > $env.toolkit.sync {
    $env.toolkit.sync = date now
    $env.toolkit.config = config default 
      | merge deep (open $config_path)
      | upsert allowed { each { path expand -n } }
  }

  $env.toolkit.config
}
