use config.nu


# All log levels, in order of increasing verbosity
const log_levels = {
  error: {
    color: (ansi red_bold)
    index: 0
  }
  warn: {
    color: (ansi yellow_bold)
    index: 1
  }
  info: {
    color: (ansi green_bold)
    index: 2
  }
  debug: {
    color: (ansi blue_bold)
    index: 3
  }
  trace: {
    color: (ansi magenta_bold)
    index: 4
  }
}

def --env log [
  --level (-l): string = "info"
  msg: any
] {
  let index = $log_levels | get $level | get index

  let current_level = config | get log_level
  let current_index = $log_levels | get $current_level | get index

  if $index <= $current_index {
    print $"(ansi blue_reverse)toolkit(ansi reset) [($log_levels | get $level | get color)($level)(ansi reset)] ($msg)" 
  }
}

export def --env "log error" [msg: any] {
  log --level "error" $msg
}

export def --env "log warn" [msg: any] {
  log --level "warn" $msg
}

export def --env "log info" [msg: any] {
  log --level "info" $msg
}

export def --env "log debug" [msg: any] {
  log --level "debug" $msg
}

export def --env "log trace" [msg: any] {
  log --level "trace" $msg
}

