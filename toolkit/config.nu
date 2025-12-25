
const default_config = {
  filenames: ["toolkit.nu"]
  allowed: []

  log_level: "info"
}

# Get the default toolkit configuration
export def "main default" []: [
  nothing -> record<
    filenames: list<string>
    allowed: list<string>
    log_level: oneof<string, int>
  >
] {
  $default_config
}

# Get the path to the toolkit configuration file
# Creates a default config file if none exists
export def "main path" []: nothing -> string {
  let config_dir = $env.XDG_CONFIG_HOME? | default {$env.HOME | path join '.config'}

  mkdir $config_dir

  [ "toml" "json" "yaml" "yml" "nuon" ]
  | each { |ext| $config_dir | path join $"toolkit.($ext)" }
  | where { path exists }
  | get 0?
  | default { 
      let path = $config_dir | path join "toolkit.toml" 

      main default | save $path

      $path 
    }
}

# Get the current toolkit configuration
export def main []: [
  nothing -> record<
    filenames: list<string>
    allowed: list<string>
    log_level: oneof<string, int>
  >
] {
  $env | get -o toolkit_config | default {
    main default 
    | merge deep (open (main path))
    | upsert allowed { each { path expand -n } }
  }
}

