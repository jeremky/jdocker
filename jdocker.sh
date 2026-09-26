#!/bin/bash -e

# Colored messages
error() { echo -e "\033[0;31m❯ $*\033[0m"; }
message() { echo -e "\033[0;36m──────────\033[0m\n\033[0;32m❯ $*\033[0m"; }
warning() { echo -e "\033[0;33m❯ $*\033[0m\n\033[0;36m──────────\033[0m"; }

# Load config file
cfg="$HOME/.config/jdocker/jdocker.cfg"
if [[ ! -f "$cfg" ]]; then
  error "File $cfg not found"
  exit 1
fi
# shellcheck source=./jdocker.cfg
. "$cfg"

checkarg() {
  if [[ $# -eq 0 ]]; then
    error "No application specified"
    return 1
  fi
}

log() {
  [[ "$logging" = true ]] || return 0
  local logfile="$HOME/.local/state/jdocker/jdocker.log"
  mkdir -p "$(dirname "$logfile")"
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$logfile"
}

process() {
  local action="$1"
  shift
  for app in "$@"; do
    if [[ ! -f "$composedir/$app/compose.yml" ]]; then
      error "File $composedir/$app/compose.yml not found"
      exit 1
    fi
    case "$action" in
      install)
        if ! podman container exists "$app"; then
          echo && warning "Deploying $app"
          if podman compose -f "$composedir/$app/compose.yml" up -d; then
            message "Application $app deployed"
          else
            error "Error while deploying $app"
          fi
        else
          error "Application $app already deployed"
        fi
        ;;
      remove)
        if podman container exists "$app"; then
          echo && warning "Removing $app"
          if podman compose -f "$composedir/$app/compose.yml" down; then
            message "Application $app removed"
          else
            error "Error while removing $app"
          fi
        else
          error "Application $app not deployed"
        fi
        ;;
      pull)
        podman compose -f "$composedir/$app/compose.yml" pull || error "Error while pulling images for $app"
        ;;
      backup)
        restartafter=0
        if [[ -d "$volumesdir/$app" ]]; then
          if podman container exists "$app"; then
            restartafter=1
            process remove "$app"
          fi
          mkdir -p "$backupsdir/$app"
          echo && warning "Backing up $app"
          log "Backup of $app started"
          bckfile="$backupsdir/$app/$app.$(date '+%Y%m%d%H%M').tar.gz"
          if podman unshare bash -c "tar -C \"$volumesdir\" -czf \"$bckfile\" \"$app\" && chown root:root \"$bckfile\""; then
            find "$backupsdir/$app" -name "$app.*.gz" -mtime "+$backupdays" -exec rm {} \;
            ls "$bckfile"
            message "Backup of $app complete"
            log "Backup of $app complete: $bckfile"
          else
            error "Error while backing up $app"
            log "Error while backing up $app"
          fi
          if ((restartafter)); then
            process install "$app"
          fi
        fi
        ;;
    esac
  done
}

purge() {
  local options=("$@")
  if podman system prune "${options[@]}"; then
    log "Purge complete (options: ${options[*]})"
  else
    log "Error while purging (options: ${options[*]})"
  fi
}

# Commands
case "$1" in
  ls | list)
    podman container ls -a --format "table {{.Names}}   {{.Status}}"
    ;;
  it | install)
    shift
    checkarg "$@" || exit 1
    process install "$@"
    echo
    ;;
  rm | remove)
    shift
    checkarg "$@" || exit 1
    process remove "$@"
    echo
    ;;
  st | start)
    shift
    checkarg "$@" || exit 1
    for app in "$@"; do
      podman start "$app"
    done
    ;;
  sp | stop)
    shift
    checkarg "$@" || exit 1
    for app in "$@"; do
      podman stop "$app"
    done
    ;;
  r | restart)
    shift
    checkarg "$@" || exit 1
    for app in "$@"; do
      podman restart "$app"
    done
    ;;
  pr | purge)
    purge -a -f
    ;;
  pra | purgeall)
    purge -a --volumes
    ;;
  lo | load)
    shift
    for img in "$@"; do
      if [[ ! -f "$imagesdir/$img" ]]; then
        error "File $img not found in $imagesdir"
      else
        podman load -i "$imagesdir/$img"
      fi
    done
    ;;
  up | upgrade)
    shift
    checkarg "$@" || exit 1
    for app in "$@"; do
      log "Upgrade of $app started"
      process pull "$app"
      process remove "$app"
      [[ "$autobackup" = true ]] && process backup "$app"
      process install "$app"
      log "Upgrade of $app complete"
    done
    if [[ "$autoclean" = true ]]; then
      echo && warning "Automatic cleanup"
      purge -a -f
      message "Cleanup complete"
    fi
    echo
    ;;
  p | pull)
    if [[ -n "$2" ]]; then
      shift
      process pull "$@"
      echo
    else
      podman images --format "{{.Repository}}:{{.Tag}}" | grep -v '^localhost' | grep -v '<none>' | xargs -r -L1 podman pull
    fi
    ;;
  l | logs)
    shift
    checkarg "$@" || exit 1
    if [[ -z "$2" ]]; then
      podman logs -f "$1"
    else
      podman logs --since="$2" "$1"
    fi
    ;;
  at | attach)
    shift
    checkarg "$@" || exit 1
    echo && warning "Ctrl+p, Ctrl+q to detach"
    podman attach "$1"
    ;;
  ps | lsa)
    podman container ls -a --format "table {{.ID}} {{.Names}} {{.Image}} {{.CreatedHuman}} {{.Status}} {{.Ports}}"
    ;;
  s | stats)
    podman stats --format "table {{.Name}}  {{.CPUPerc}}  {{.MemPerc}}  {{.MemUsage}}  {{.NetIO}}"
    ;;
  sh | bash)
    shift
    checkarg "$@" || exit 1
    podman exec -it "$1" sh
    ;;
  n | networks)
    podman network ls
    ;;
  i | images)
    podman images
    ;;
  u | unshare)
    shift
    if [ $# -eq 0 ]; then
      podman unshare bash --rcfile <(printf '
      source ~/.bashrc
      PS1="\[\033[01;33m\]unshare@\h\[\033[00m\]:\[\033[01;34m\]\w \$\[\033[00m\] "
      ')
    else
      podman unshare --rootless-netns "$@"
    fi
    ;;
  v | volumes)
    podman volume ls
    ;;
  bk | backup)
    shift
    checkarg "$@" || exit 1
    process backup "$@"
    echo
    ;;
  *)
    echo
    warning "Available commands:"
    cat <<'EOF'
    ls  | list            List active containers
    n   | networks        List virtual networks
    v   | volumes         List virtual volumes
    i   | images          List images
    l   | logs            Show logs for a given container
    lo  | load            Load one or more given local images
    it  | install         Install a container with compose
    rm  | remove          Remove a container with compose
    st  | start           Start a container
    sp  | stop            Stop a container
    r   | restart         Restart a container
    pr  | purge           Purge unused images and networks
    pra | purgeall        Also purge unused volumes
    at  | attach          Attach to the open prompt of a given container
    p   | pull            Pull the latest image of a given container
    up  | upgrade         Download the latest image and upgrade a given container
    ps  | lsa             Show detailed container information
    s   | stats           Show real-time container statistics
    sh  | bash            Open a shell in a given container
    bk  | backup          Back up a given container
    u   | unshare         Switch ID with podman unshare
    h   | help            Show this help
EOF
    echo
    ;;
esac
