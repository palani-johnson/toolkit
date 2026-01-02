use utils/link.nu *
use env.nu *
use logging.nu *

const toolkit_tmp_dir = [$nu.temp-path toolkit $nu.pid] | path join
const toolkit_empty_file = $toolkit_tmp_dir | path join "empty.nu"
const mod_path = (path self | path parse).parent

# Initialize toolkit. 
#
# Sets up hooks to manage overlays for toolkit layers. Call this function in `config.nu`.
export def --env init [
  --max-layers (-m): int = 5 # maximum number of layers to support. more layers may negatively impact performance
] {
  if (
    ($env.config.hooks.pre_prompt ++ $env.config.hooks.pre_execution)
    | where { $in | describe | str starts-with "record" }
    | any { $in.added_by? | default "" | $in == "toolkit" }
  ) {
    error make {
      msg: "toolkit already configured"
    }
  }

  $env.ENV_CONVERSIONS.toolkit = { from_string: { {} } to_string: { "" } }
  $env.toolkit = {
    tmp_dir: $toolkit_tmp_dir
    env: (
      0..<$max_layers | each {{
        module_file: null
        watch_files: []
        last_sync: null
      }}
    )
  }

  let hooks = []
    | append {
        name: "sync_config"
        code: { config }
      }
    | append {
        name: "create_overlay"
        code: {
          mkdir $toolkit_tmp_dir
          touch $toolkit_empty_file

          let allowed_layers = layers
            | where allowed
            | take ($max_layers)

          log debug $"Found ($allowed_layers | length) allowed layers"

          let layers = 0..<$max_layers 
            | each {{ path: $toolkit_empty_file index: $in }}
            | merge deep $allowed_layers
          
          for layer in $layers { 
            let mod = $toolkit_tmp_dir | path join $"toolkit-layer-($layer.index).nu"
            
            # create symlinks to layers
            symlink -f $mod $layer.path

            if ($env.toolkit.env | get $layer.index | get module_file) != $layer.path {
              $env.toolkit.env = $env.toolkit.env | update $layer.index {
                module_file: $layer.path
                watch_files: []
                last_sync: null
              }
            }
          }
        }
      }
    | append (
        0..<$max_layers | each { |layer_index| 
          let layer_path = $toolkit_tmp_dir | path join $"toolkit-layer-($layer_index).nu"

          {
            name: $"use_overlay_($layer_index)"
            condition: {
              let toolkit_env = $env.toolkit.env | get $layer_index

              $toolkit_env.last_sync == null or (
                $layer_index > 0 
                and ($env.toolkit.env | get ($layer_index - 1) | get last_sync) > $toolkit_env.last_sync
              ) or (
                $toolkit_env.watch_files 
                | append $toolkit_env.module_file
                | each --flatten { ls $in }
                | any { $in.modified > $toolkit_env.last_sync }
              )
            }
            # This must be done as a string to bypass parsing time checks
            code: (
              $"
                overlay use -r ($layer_path)

                # Last access time is more precise than date now
                $env.toolkit.env.($layer_index).last_sync = ls -l ($layer_path) | get accessed | first
              "
            )
          }
        }
      )
    | append {
        name: "cleanup_overlay_dir"
        code: { rm -r $toolkit_tmp_dir }
      }
    | upsert added_by "toolkit"
    | upsert name { $"toolkit::($in)" }

  $env.config.hooks.pre_prompt ++= $hooks
  $env.config.hooks.pre_execution ++= $hooks
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
  | each { |path|
      let allowed = $config.allowed_dirs 
        | any { |pattern| $path | str starts-with $pattern }

      let valid = try { 
        nu-check --as-module $path
      } catch {
        error make -u {
          msg: $"toolkit: ($path) is not a valid nu module"
        }
      }

      { 
        path: $path 
        allowed: ($allowed and $valid)
      }
    }
}
