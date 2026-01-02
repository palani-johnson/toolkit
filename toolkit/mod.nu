# Adapted from https://github.com/nushell/nu_scripts/blob/main/nu-hooks/nu-hooks/toolkit/hook.nu

use utils/link.nu *
use env.nu *
use logging.nu *

const toolkit_tmp_dir = [$nu.temp-path toolkit $nu.pid] | path join
const mod_path = (path self | path parse).parent

# Initialize toolkit by adding a pre-prompt hook to load the configuration
export def --env init [] {
  log debug "Initializing"

  if (
    ($env.config.hooks.pre_prompt ++ $env.config.hooks.pre_execution)
    | where { $in | describe | str starts-with "record" }
    | any { $in.added_by? | default "" | $in == "toolkit" }
  ) {
    error make {
      msg: "toolkit already configured"
    }
  }
  

  let hooks = [
    {
      added_by: "toolkit"
      name: "toolkit::create_overlay"
      code: {
        mkdir $toolkit_tmp_dir

        let layers = layers
          | where allowed
          | take (max-layers)
          | enumerate

        log debug $"Found ($layers | length) allowed layers"
        
        for layer in $layers { 
          let mod = $toolkit_tmp_dir | path join $"toolkit-layer-($layer.index).nu"
          
          # create symlinks to layers
          symlink -f $mod $layer.item.path

          let toolkit_env = env | get $layer.index
          if $toolkit_env.module_file != $layer.item.path {
            $env.toolkit.env = $env.toolkit.env | update $layer.index {
              module_file: $layer.item.path
              watch_files: []
              last_sync: null
            }
          }
        }
      }
    }
    ...(
      0..<(max-layers)
      | each { |layer_index| 
          let layer_path = $toolkit_tmp_dir | path join $"toolkit-layer-($layer_index).nu"

          {
            added_by: "toolkit"
            name: $"toolkit::use_overlay_($layer_index)"
            condition: {
              let toolkit_env = env | get $layer_index

              (
                ($layer_path | path exists)
                and (
                  ($toolkit_env.last_sync == null) 
                  or (
                    env 
                    | slice 0..$layer_index
                    | each --flatten { |it| [$it.module_file] ++ $it.watch_files }
                    | each --flatten { ls $in }
                    | any { $in.modified > $toolkit_env.last_sync }
                  )
                )
              )
            }
            # This must be done as a string to bypass parsing time checks
            # Last access time is more precise than (date now)
            code: (
              $"
                overlay use -r ($layer_path)

                $env.toolkit.env.($layer_index).last_sync = ls -l ($layer_path) | get accessed | first

                use ($mod_path)/logging.nu *
                log info $\"loaded layer ($layer_index) from \($env.toolkit.env.($layer_index).module_file)\"
                log debug $\"layer ($layer_index) watch files: \($env.toolkit.env.($layer_index).watch_files)\"
                log trace $\"layer ($layer_index) last sync: \($env.toolkit.env.($layer_index).last_sync)\"
              "
            )
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
}
