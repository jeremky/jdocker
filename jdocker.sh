#!/bin/bash

dir=$(dirname "$0")

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

# Chargement du fichier de config
cfg="$dir/jdocker.cfg"
if [[ -f $cfg ]]; then
  . $cfg
else
  echo -e "${RED}Fichier $cfg introuvable${RESET}"
  exit 0
fi

# Installation de Podman
if [[ ! -f /usr/bin/podman && -f /usr/bin/apt ]]; then
  echo -e "${GREEN}Installation de Podman...${RESET}"
  sudo apt install -y podman podman-compose
  sudo mkdir -p $containersdir
  sudo chown $user: $containersdir
  sudo sysctl net.ipv4.ip_unprivileged_port_start=$port
  echo "net.ipv4.ip_unprivileged_port_start=$port" | sudo tee /etc/sysctl.d/10-podman.conf
  sudo loginctl enable-linger $user
  systemctl enable --user --now podman-restart.service
  systemctl enable --user --now podman.socket
fi

# Installation de la complétion
if [[ ! -f /etc/bash_completion.d/jdocker ]]; then
  sudo cp $dir/.jdocker.comp /etc/bash_completion.d/jdocker
  sudo sed -i "s,CONFIGDIR,$configdir," /etc/bash_completion.d/jdocker
  sudo sed -i "s,CONTDIR,$containersdir," /etc/bash_completion.d/jdocker
  sudo sed -i "s,IMGDIR,$imgdir," /etc/bash_completion.d/jdocker
  echo -e "${GREEN}Auto complétion installée. Redémarrez la session ou chargez la complétion avec :${RESET}"
  echo "  source /etc/bash_completion"
  exit 0
fi

# Commandes
case $1 in
  list | ls)
    podman container ls -a --format "table {{.Names}} \t {{.Status}}"
    ;;
  listall | lsa)
    podman container ls -a --format "table {{.Names}} \t {{.Status}} \t {{.Ports}} \t {{.Image}}"
    ;;
  install | it)
    shift
    for app in $*; do
      if [[ ! -d $configdir/$app || -z "$1" ]]; then
        echo -e "${RED}Application $app non trouvée${RESET}"
      else
        $compose -f $configdir/$app/*compose.yml up -d
        echo -e "${GREEN}Application $app déployée${RESET}"
      fi
    done
    ;;
  remove | rm)
    shift
    for app in $*; do
      if [[ ! -d $configdir/$app || -z "$1" ]]; then
        echo -e "${RED}Application $app non trouvée${RESET}"
      else
        $compose -f $configdir/$app/*compose.yml down
        echo -e "${GREEN}Application $app supprimée${RESET}"
      fi
    done
    ;;
  restart | r)
    if [[ ! -z "$2" ]]; then
      shift
      for app in $*; do
        podman restart $app
      done
    fi
    ;;
  purge | pr)
    podman system prune -f
    ;;
  purgeall | pra)
    podman system prune -f -a --volumes
    ;;
  load | lo)
    shift
    for img in $*; do
      if [[ ! -f $imgdir/$img ]]; then
        echo -e "${RED}Fichier $img non trouvé dans $imgdir${RESET}"
      else
        podman load -i $imgdir/$img
      fi
    done
    ;;
  upgrade | up)
    if [[ ! -z "$2" ]]; then
      shift
      for app in $*; do
        if [[ -d $configdir/$app ]]; then
          $dir/jdocker.sh p $app
          $dir/jdocker.sh rm $app
          $dir/jdocker.sh it $app
        else
          echo -e "${RED}Application $app introuvable${RESET}"
        fi
      done
    else
      echo -e "${RED}Aucune application spécifiée en paramètre${RESET}"
    fi
    ;;
  pull | p)
    if [[ ! -z "$2" ]]; then
      shift
      for app in $*; do
        if [[ -z "$(cat $configdir/$app/*compose.yml | grep "image:" | grep localhost)" ]]; then
          podman pull $(cat $configdir/$app/*compose.yml | grep "image:" | cut -d: -f3,2)
        fi
      done
    else
      podman images | grep -v ^REPO | grep -v localhost | sed 's/ \+/:/g' | cut -d: -f1,2 | xargs -L1 $sudo podman pull
    fi
    ;;
  logs | l)
    if [[ -z "$3" ]]; then
      podman logs -f $2
    else
      podman logs --since=$3 $2
    fi
    ;;
  attach | at)
    echo "Ctrl+p, Ctrl+q pour quitter"
    podman attach $2
    ;;
  stats | ps)
    podman stats --format "table {{.Name}}\t {{.CPUPerc}}\t {{.MemUsage}}"
    ;;
  statsall | psa)
    podman stats --format "table {{.Name}}\t {{.CPUPerc}}\t {{.MemPerc}}\t {{.MemUsage}}\t {{.NetIO}}\t {{.BlockIO}}"
    ;;
  bash | sh)
    podman exec -it $2 sh
    ;;
  networks | n)
    podman network ls
    ;;
  images | i)
    podman images
    ;;
  unshare | u)
    shift
    podman unshare $*
    ;;
  volumes | v)
    podman volume ls
    ;;
  backup | bk)
    if [[ ! -z "$2" ]]; then
      if [[ -d $containersdir/$2 ]]; then
        if [[ ! -d $destbackup/$2 ]]; then
          mkdir -p $destbackup/$2
        fi
        $dir/jdocker.sh rm $2
        cd $containersdir
        echo "Sauvegarde de $2..."
        podman unshare tar czf $2.$(date '+%Y%m%d').tar.gz $2 
        podman unshare chown root: $2.$(date '+%Y%m%d').tar.gz
        mv $2.$(date '+%Y%m%d').tar.gz $destbackup/$2
        find $destbackup/$2 -name $2.*.gz -mtime +$retention -exec rm {} \;
        echo "Sauvegarde terminée. Relance..."
        $dir/jdocker.sh it $2
      else
        echo -e "${RED}Dossier $containersdir/$2 introuvable${RESET}"
      fi
    else
      if [[ -f $dir/jdocker.cron ]]; then
        sudo cp -v $dir/jdocker.cron /etc/cron.d/jdocker
        sudo sed -i "s,SCR,$(realpath "$0")," /etc/cron.d/jdocker
        sudo sed -i "s,USER,$user," /etc/cron.d/jdocker
      else
        echo -e "{$RED}Fichier $dir/jdocker.cron absent${RESET}"
      fi
    fi
    ;;
  * | help)
    echo -e "${GREEN}Commandes disponibles :${RESET}"
    cat $dir/.jdocker.help
    ;;
esac
