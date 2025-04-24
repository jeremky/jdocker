#!/bin/bash

dir=$(dirname "$0")

# Chargement du fichier de config
cfg="$dir/jdocker.cfg"
if [[ -f $cfg ]]; then
  . $cfg
else
  echo "Fichier $cfg introuvable"
  exit 0
fi

# Installation de Podman
if [[ ! -f /usr/bin/$dockerapp ]] && [[ -f /usr/bin/apt ]]; then
  echo "Installation de Podman..."
  sudo apt install -y podman podman-compose
  sudo mkdir -p $containersdir
  if [[ $rootless = "on" ]]; then
    sudo sysctl net.ipv4.ip_unprivileged_port_start=$port
    echo "net.ipv4.ip_unprivileged_port_start=$port" | sudo tee /etc/sysctl.d/10-podman.conf
    systemctl enable --user --now podman-restart.service
    systemctl enable --user --now podman.socket
    sudo loginctl enable-linger $user
    sudo chown $user: $containersdir
  fi
fi

# Configuration selon le mode root
if [[ $rootless = "off" ]]; then
  sudo=/usr/bin/sudo
fi

# Installation de la complétion
if [[ ! -f /etc/bash_completion.d/jdocker ]]; then
  sudo cp $dir/.jdocker.comp /etc/bash_completion.d/jdocker
  sudo sed -i "s,SCRIPTDIR,$dir," /etc/bash_completion.d/jdocker
  sudo sed -i "s,DOCKERAPP,$sudo $dockerapp," /etc/bash_completion.d/jdocker
  sudo sed -i "s,CONTDIR,$containersdir," /etc/bash_completion.d/jdocker
  echo "Auto complétion installée. Redémarrez la session ou chargez la complétion avec :"
  echo "  source /etc/bash_completion"
  exit 0
fi

# Commandes
case $1 in
  list | ls)
    $sudo $dockerapp container ls -a --format "table {{.Names}} \t {{.Status}}"
    ;;
  listall | lsa)
    $sudo $dockerapp container ls -a --format "table {{.Names}} \t {{.Status}} \t {{.Ports}} \t {{.Image}}"
    ;;
  install | it)
    shift
    for app in $*; do
      if [[ ! -f $dir/cfg/$app/compose.yml ]] || [[ -z "$1" ]]; then
        echo "Application $app non trouvée"
        echo ""
      else
        $sudo $compose -f $dir/cfg/$app/compose.yml up -d
      fi
    done
    ;;
  remove | rm)
    shift
    for app in $*; do
      if [[ ! -f $dir/cfg/$app/compose.yml ]] || [[ -z "$1" ]]; then
        echo "Application $app non trouvée"
        echo ""
      else
        $sudo $compose -f $dir/cfg/$app/compose.yml down
      fi
    done
    ;;
  restart | r)
    if [[ ! -z "$2" ]]; then
      shift
      for app in $*; do
        $sudo $dockerapp restart $app
      done
    fi
    ;;
  purge | pr)
    $sudo $dockerapp system prune -f
    ;;
  purgeall | pra)
    $sudo $dockerapp system prune -f -a --volumes
    ;;
  load | lo)
    if [[ ! -d $imgdir/.old ]]; then
      sudo mkdir -p $imgdir/.old
      sudo chown -R $user: $imgdir
    fi
    for file in $(ls $imgdir/*.tar); do
      $sudo $dockerapp load -i $file
      mv $file $imgdir/.old
    done
    ;;
  upgrade | up)
    if [[ ! -z "$2" ]]; then
      shift
      for app in $*; do
        $dir/jdocker.sh rm $app
        $dir/jdocker.sh it $app
      done
    else
      $sudo $dockerapp images | grep -v ^REPO | sed 's/ \+/:/g' | cut -d: -f1,2 | xargs -L1 $sudo $dockerapp pull
    fi
    ;;
  logs | l)
    if [[ -z "$3" ]]; then
      $sudo $dockerapp logs -f $2
    else
      $sudo $dockerapp logs --since=$3 $2
    fi
    ;;
  attach | at)
    echo "Ctrl+p, Ctrl+q pour quitter"
    $sudo $dockerapp attach $2
    ;;
  stats | ps)
    $sudo $dockerapp stats --format "table {{.Name}}\t {{.CPUPerc}}\t {{.MemUsage}}"
    ;;
  statsall | psa)
    $sudo $dockerapp stats --format "table {{.Name}}\t {{.CPUPerc}}\t {{.MemPerc}}\t {{.MemUsage}}\t {{.NetIO}}\t {{.BlockIO}}"
    ;;
  bash | sh)
    $sudo $dockerapp exec -it $2 sh
    ;;
  networks | n)
    $sudo $dockerapp network ls
    ;;
  images | i)
    $sudo $dockerapp images
    ;;
  volumes | v)
    $sudo $dockerapp volume ls
    ;;
  backup | bk)
    if [[ ! -z "$2" ]]; then
      if [[ -d $containersdir/$2 ]]; then
        if [[ ! -d $destbackup/$2 ]]; then
          $sudo mkdir -p $destbackup/$2
          $sudo chown $user: $destbackup/$2
        fi
        $dir/jdocker.sh rm $2
        cd $containersdir
        echo "Sauvegarde de $2..."
        $sudo tar czf $2.$(date '+%Y%m%d').tar.gz $2
        $sudo chown $user: $2.$(date '+%Y%m%d').tar.gz
        $sudo mv $2.$(date '+%Y%m%d').tar.gz $destbackup/$2
        find $destbackup/$2 -name $2.*.gz -mtime +7 -exec rm {} \;
        echo "Sauvegarde terminée. Relance..."
        $dir/jdocker.sh it $2
      else
        echo "Dossier $containersdir/$2 introuvable"
      fi
    else
      if [[ -f $dir/jdocker.cron ]]; then
        sudo cp -v $dir/jdocker.cron /etc/cron.d/jdocker
        sudo sed -i "s,DIR,$dir," /etc/cron.d/jdocker
      else
        echo "Fichier $dir/jdocker.cron absent"
      fi
    fi
    ;;
  * | help)
    cat $dir/.jdocker.help
    ;;
esac
