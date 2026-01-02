use ../mod.nu layers

export def --env watch-files [
  ...paths: glob
  --append (-a) # Add files to watch list instead of replacing
] {
  try {
    let layer = layers
      | enumerate
      | each { |it| $it.item | upsert index $it.index }
      | where allowed
      | where path == $env.CURRENT_FILE
      | first

    let cell_path = [$layer.index watch_files] | into cell-path

    mut files = do {
      cd ($env.CURRENT_FILE | path parse | $in.parent)

      $paths | each --flatten { glob $in } 
    }

    if $append {
      $files = ($env.toolkit.env | get $cell_path) ++ $files
    }
    
    $env.toolkit.env = $env.toolkit.env | update $cell_path $files
    
  } catch {
    error make -u {
      msg: $"toolkit: watch-files must only be used within an active toolkit file"
    } 
  }
}
