# Adapted from https://github.com/nushell/nu_scripts/blob/main/nu-hooks/nu-hooks/toolkit/hook.nu

use utils/link.nu *

const toolkit_tmp_dir = [$nu.temp-path toolkit $nu.pid] | path join

# Initialize toolkit by adding a pre-prompt hook to load the configuration
export def --env init [] {
  if (
    ($env.config.hooks.pre_prompt ++ $env.config.hooks.pre_execution)
    | where { $in | describe | str starts-with "record" }
    | any { $in.added_by? | default "" | $in == "toolkit" }
  ) {
    error make {
      msg: "toolkit already configured"
    }
  }

  $env.ENV_CONVERSIONS.TOOLKIT_ENABLED = {
    from_string: { into bool }
    to_string: { into string }
  }
  $env.TOOLKIT_ENABLED = $env.TOOLKIT_ENABLED? | default true
  let max_layers = $env.TOOLKIT_MAX_LAYERS? | default 5
  $env.toolkit_env = 0..<$max_layers 
    | each {{
        module_file: null
        watch_files: []
        last_sync: null
      }}

  let hooks = [
    {
      added_by: "toolkit"
      name: "toolkit::create_overlay"
      code: {
        mkdir $toolkit_tmp_dir

        let layers = layers
          | where allowed
          | take $max_layers
          | enumerate
        
        for layer in $layers { 
          let mod = $toolkit_tmp_dir | path join $"toolkit-layer-($layer.index).nu"
          
          # create symlinks to layers
          symlink -f $mod $layer.item.path

          let toolkit_env = $env.toolkit_env | get $layer.index
          if $toolkit_env.module_file != $layer.item.path {
            $env.toolkit_env = $env.toolkit_env | update $layer.index {
              module_file: $layer.item.path
              watch_files: []
              last_sync: null
            }
          }
        }
      }
    }
    ...(
      0..<$max_layers
      | each { |layer_index| 
          let layer_path = $toolkit_tmp_dir | path join $"toolkit-layer-($layer_index).nu"

          {
            added_by: "toolkit"
            name: "toolkit::use_overlay"
            condition: {
              let toolkit_env = $env.toolkit_env | get $layer_index

              (
                ($env.TOOLKIT_ENABLED? | default true) 
                and ($layer_path | path exists)
                and (
                  ($toolkit_env.last_sync == null) 
                  or (
                    $env.toolkit_env 
                    | slice 0..$layer_index
                    | each --flatten { |it| [$it.module_file] ++ $it.watch_files }
                    | each --flatten { ls $in }
                    | any { $in.modified > $toolkit_env.last_sync }
                  )
                )
              )
            }
            # This must be done as a string to bypass parsing time checks
            code: $"
              overlay use -r ($layer_path)
              $env.toolkit_env.($layer_index).last_sync = ls -l ($layer_path) | get accessed | first
              print $\"toolkit: loaded layer \($env.toolkit_env.($layer_index).module_file)\"
            "
          }
        }
    )
    {
      added_by: "toolkit"
      name: "toolkit::cleanup_overlay_dir"
      code: {
        rm -r $toolkit_tmp_dir
      }
    }
  ]

  $env.config.hooks.pre_prompt ++= $hooks
  $env.config.hooks.pre_execution ++= $hooks
}

def is-allowed [
  path: string
  config: record<
    allowed: list<string>
  >
]: nothing -> bool {
  let allowed = $config.allowed 
    | any { |pattern| $path | str starts-with $pattern }

  let valid = try { 
      nu-check $path
    } catch {
      error make -u {
        msg: $"toolkit: ($path) is not a valid nu module"
      }
    }
  
  $allowed and $valid
}

# toggle toolkit on/off
export def --env toggle [] {
  $env.TOOLKIT_ENABLED = not ($env.TOOLKIT_ENABLED? | default true)

  if $env.TOOLKIT_ENABLED {
    print "toolkit enabled"
  } else {
    print "toolkit disabled"
  }
}
 
# get all toolkit layers from the current directory upwards
export def layers []: [
  nothing -> table<
    path: string
    allowed: bool
  >
] {
  let config = config

  let dir_stack = pwd | path split

  $dir_stack
  | enumerate
  | each --flatten { |it| 
      let dir = $dir_stack | slice 0..$it.index 
      $config.filenames | each { |it| $dir | path join $it }
    }
  | where { path exists }
  | each {{ 
      path: $in 
      allowed: (is-allowed $in $config)
    }}
  | reverse
}

# Get the default toolkit configuration
export def "config default" []: [
  nothing -> record<
    filenames: list<string>
    allowed: list<string>
  >
] {
  {
    filenames: ["toolkit.nu"]
    allowed: []
  }
}

# Get the path to the toolkit configuration file
# Creates a default config file if none exists
export def "config path" []: nothing -> string {
  let config_dir = $env.XDG_CONFIG_HOME? | default {$env.HOME | path join '.config'}

  mkdir $config_dir

  let path = [ "toml" "json" "yaml" "yml" "nuon" ]
    | each { |ext| $config_dir | path join $"toolkit.($ext)" }
    | where { path exists }
    | get 0?
    | default {$config_dir | path join "toolkit.toml"}

  if not ($path | path exists) {
    config default | save $path
  }

  $path
}

# Get the current toolkit configuration
export def config []: [
  nothing -> record<
    filenames: list<string>
    allowed: list<string>
  >
] {
  mut config = config default | merge deep (open (config path))

  $config.allowed = $config.allowed | each { path expand -n }

  $config
}

