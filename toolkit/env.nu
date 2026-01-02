
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

# Get the path to the toolkit configuration file
# Creates a default config file if none exists
export def "config path" []: nothing -> string {
  let config_dir = $env.XDG_CONFIG_HOME? | default {$env.HOME | path join '.config'}

  mkdir $config_dir

  [ "toml" "json" "yaml" "yml" "nuon" ]
  | each { |ext| $config_dir | path join $"toolkit.($ext)" }
  | where { path exists }
  | get 0?
  | default { 
      let path = $config_dir | path join "toolkit.toml" 

      config default | save $path

      $path 
    }
}

def --env init [] {
  if $env.ENV_CONVERSIONS.toolkit? == null {
    $env.ENV_CONVERSIONS.toolkit = { from_string: { {} } to_string: { "" } }
    $env.toolkit = {}
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
  init 

  let config_path = config path

  if $env.toolkit.sync? == null or (ls $config_path | get modified.0) > $env.toolkit.sync {
    $env.toolkit.sync = date now
    $env.toolkit.config = config default 
      | merge deep (open $config_path)
      | upsert allowed { each { path expand -n } }
  }

  $env.toolkit.config
}

export def --env main []: [
  nothing -> list<
    record<
      module_file: oneof<string nothing>
      watch_files: list<string>
      last_sync: oneof<datetime nothing>
    >
  >
] {
  init

  if $env.toolkit.env? == null {
    $env.toolkit.env = 0..<5 | each {{
      module_file: null
      watch_files: []
      last_sync: null
    }}
  }

  $env.toolkit.env
}

export def --env max-layers [] {
  main | length
}


