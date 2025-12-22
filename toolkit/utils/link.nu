# Consider moving this to it's own module later.

# An os-independent symlink creation command
export def symlink [
  link_name: string 
  target: string
  --force (-f) # If the $link_name file already exists, then unlink it so that the link may occur.
] {
  match $nu.os-info.name {
    "macos" | "linux" => {
      let extra_params = [ 
        (if $force {"-f"}) 
      ] | where $it != null
      
      ^ln -s ...$extra_params $target $link_name
    }
    _ => {
      error make -u {
        msg: $"symlink command not implemented for this OS: ($nu.os-info.name)"
      }
    }
  }
}

# An os-independent hardlink creation command
export def hardlink [
  link_name: string 
  target: string
  --force (-f) # If the $link_name file already exists, then unlink it so that the link may occur.
] {
  match $nu.os-info.name {
    "macos" | "linux" => {
      let extra_params = [ 
        (if $force {"-f"}) 
      ] | where $it != null

      ^ln -s ...$extra_params $target $link_name
    }
    _ => {
      error make -u {
        msg: $"hardlink command not implemented for this OS: ($nu.os-info.name)"
      }
    }
  }
}
