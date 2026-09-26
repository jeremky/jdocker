# jdocker

> jdocker has been fully reworked: the script now installs as a real binary via `make install`, following standard Linux conventions (`~/.local/bin`, `~/.config`)

This script makes it easier to install and manage rootless Podman containers on Debian, RHEL and derivatives.
Deployment files are kept in a directory of your choice, so you can deploy them easily without having to be in the directory containing the `compose.yml` file.

## Configuration

Before installing this script, first adjust the `jdocker.cfg` file to suit your preferences:

- `autobackup`: automatically back up external volumes during an upgrade
- `logging`: write completed tasks to a log file
- `autoclean`: automatically remove images after an upgrade
- `backupdays`: backup retention period, in days
- The directories where data is stored (`compose.yml` files, backups, volumes...)

This config file can be edited later at: `~/.config/jdocker/jdocker.cfg`

```txt
# jdocker config
autobackup=false
logging=true
autoclean=true
backupdays=7

composedir=$HOME/compose
volumesdir=$HOME/volumes
backupsdir=$HOME/backups
imagesdir=$HOME/images
```

> The `composedir` directory must contain one subdirectory per application, each with a `compose.yml` file inside.
> For example: `~/compose/app1/compose.yml`

## Installation

The installation automatically sets up `podman` and `podman-compose`, and configures your user to run Podman properly.

### Current user

If your user has sudo privileges:

```bash
make install
```

### User without sudo

Otherwise, run it as `root` and specify which user to install the application for:

```bash
sudo make install PODMAN_USER=<user>
```

As shown at the end of the installation, remember to enable the Podman services. Unlike the standard installation, these services are not enabled automatically:

```bash
systemctl --user enable --now podman-restart.service podman.socket
```

### Port

By default, a regular user can't use ports below 1024. The installation changes this setting to allow ports from 80 upward. To use a different value:

```bash
sudo make install PODMAN_USER=<user> BASEPORT=<port>
```

## Usage

Once installed, `jdocker` can be run directly from your terminal.

To see the help, run `jdocker` without arguments:

```txt
Available commands:
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
```

## Backup

`jdocker` provides a backup system for external volumes.
To automate your backups, adjust `/etc/cron.d/jdocker` to suit your preferences:

```txt
# jdocker cron
jdocksh=$PODMAN_HOME/.local/bin/jdocker
jdocklog=$PODMAN_HOME/.local/state/jdocker/jdocker.log

# app1
0 0 * * *  $PODMAN_USER $jdocksh bk app1 >/dev/null 2>&1

# app2
0 1 * * *  $PODMAN_USER $jdocksh bk app2 >/dev/null 2>&1
```

## Logs

If logging is enabled, a log of completed tasks is available at: `~/.local/state/jdocker/jdocker.log`
