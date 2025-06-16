#!/bin/bash

dir=$(dirname "$0")

# Messages colorisés
error()    { echo -e "\033[0;31m====> $*\033[0m" ;}
message()  { echo -e "\033[0;32m====> $*\033[0m" ;}
warning()  { echo -e "\033[0;33m====> $*\033[0m" ;}

# Chargement du fichier de config
cfg="$dir/jdocker.cfg"
if [[ -f $cfg ]]; then
  . $cfg
else
  error "Fichier $cfg introuvable"
  exit 0
fi

# Installation de Podman
if [[ ! -f /usr/bin/podman && -f /usr/bin/apt ]]; then
  echo ""
  warning "Installation de Podman..."
  sudo apt install -y podman podman-compose
  sudo mkdir -p $containersdir
  sudo chown $user: $containersdir
  sudo sysctl net.ipv4.ip_unprivileged_port_start=$port
  echo "net.ipv4.ip_unprivileged_port_start=$port" | sudo tee /etc/sysctl.d/10-podman.conf
  sudo loginctl enable-linger $user
  systemctl enable --user --now podman-restart.service
  systemctl enable --user --now podman.socket
  echo ""
  message "Installation de Podman terminée"
  echo ""
fi

# Installation de la complétion
if [[ ! -f /etc/bash_completion.d/jdocker ]]; then
  sudo cp $dir/.jdocker.comp /etc/bash_completion.d/jdocker
  sudo sed -i "s,CONFIGDIR,$configdir," /etc/bash_completion.d/jdocker
  sudo sed -i "s,CONTDIR,$containersdir," /etc/bash_completion.d/jdocker
  sudo sed -i "s,IMGDIR,$imgdir," /etc/bash_completion.d/jdocker
  echo ""
  message "Auto complétion installée. Redémarrez la session ou chargez la complétion avec :"
  echo "  source /etc/bash_completion"
  echo ""
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
    if [[ ! -z "$2" ]]; then
      shift
      for app in $*; do
        if [[ ! -d $configdir/$app || -z "$1" ]]; then
          error "Application $app introuvable"
        else
          echo ""
          warning "Déploiement de $app..."
          $compose -f $configdir/$app/*compose.yml up -d
          message "Application $app déployée"
        fi
      done
      echo ""
    else
      error "Aucune application spécifiée en paramètre"
    fi
    ;;
  remove | rm)
    if [[ ! -z "$2" ]]; then
      shift
      for app in $*; do
        if [[ ! -d $configdir/$app || -z "$1" ]]; then
          error "Application $app introuvable"
        else
          echo ""
          warning "Suppression de $app..."
          $compose -f $configdir/$app/*compose.yml down
          message "Application $app supprimée"
        fi
      done
      echo ""
    else
      error "Aucune application spécifiée en paramètre"
    fi
    ;;
  restart | r)
    if [[ ! -z "$2" ]]; then
      shift
      for app in $*; do
        if podman container exists $app; then
          echo ""
          podman restart $app
          message "Application $app redémarrée"
        else
          echo ""
          error "Application $app introuvable"
        fi
      done
      echo ""
    else
      error "Aucune application spécifiée en paramètre"
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
        error "Fichier $img non trouvé dans $imgdir"
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
          error "Application $app introuvable"
        fi
      done
    else
      error "Aucune application spécifiée en paramètre"
    fi
    ;;
  pull | p)
    if [[ ! -z "$2" ]]; then
      shift
      for app in $*; do
        if [[ -d $configdir/$app && -z "$(cat $configdir/$app/*compose.yml | grep "image:" | grep localhost)" ]]; then
          echo ""
          warning "Récupération de la nouvelle image $app..."
          podman pull $(cat $configdir/$app/*compose.yml | grep "image:" | cut -d: -f3,2)
          message "Nouvelle image $app récupérée"
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
    warning "Ctrl+p, Ctrl+q pour quitter"
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
      shift
      for app in $*; do
        if [[ -d $containersdir/$app ]]; then
          if [[ ! -d $destbackup/$app ]]; then
            mkdir -p $destbackup/$app
          fi
          $dir/jdocker.sh rm $app
          cd $containersdir
          echo ""
          message "Sauvegarde de $app..."
          podman unshare tar czf $app.$(date '+%Y%m%d').tar.gz $app
          podman unshare chown root: $app.$(date '+%Y%m%d').tar.gz
          mv $app.$(date '+%Y%m%d').tar.gz $destbackup/$app
          find $destbackup/$app -name $app.*.gz -mtime +$retention -exec rm {} \;
          message "Sauvegarde terminée"
          $dir/jdocker.sh it $app
        else
          error "Dossier $containersdir/$app introuvable"
        fi
      done
    else
      if [[ -f $dir/jdocker.cron ]]; then
        sudo cp -v $dir/jdocker.cron /etc/cron.d/jdocker
        sudo sed -i "s,SCR,$(realpath "$0")," /etc/cron.d/jdocker
        sudo sed -i "s,USER,$user," /etc/cron.d/jdocker
      else
        error "Fichier $dir/jdocker.cron absent"
      fi
    fi
    ;;
  * | help)
    echo ""
    message "Commandes disponibles :"
    cat $dir/.jdocker.help
    echo ""
    ;;
esac
