#!/bin/bash

dir=$(dirname "$0")

# Messages colorisés
error()    { echo -e "\033[0;31m====> $*\033[0m" ;}
message()  { echo -e "\033[0;32m====> $*\033[0m" ;}
warning()  { echo ; echo -e "\033[0;33m====> $*\033[0m" ;}

# Chargement du fichier de config
cfg="$dir/jdocker.cfg"
if [[ -f $cfg ]]; then
  . $cfg
else
  error "Fichier $cfg introuvable"
  exit 1
fi

# Installation de Podman
if [[ ! -f /usr/bin/podman && -f /usr/bin/apt ]]; then
  warning "Installation de Podman..."
  sudo apt install -y podman podman-compose
  sudo mkdir -p $containersdir
  sudo chown $user: $containersdir
  sudo sysctl net.ipv4.ip_unprivileged_port_start=$port
  echo "net.ipv4.ip_unprivileged_port_start=$port" | sudo tee /etc/sysctl.d/10-podman.conf
  sudo loginctl enable-linger $user
  systemctl enable --user --now podman-restart.service
  systemctl enable --user --now podman.socket
  message "Installation de Podman terminée"
fi

# Installation de la complétion
if [[ ! -f /etc/bash_completion.d/jdocker ]]; then
  sudo cp $dir/.jdocker.comp /etc/bash_completion.d/jdocker
  sudo sed -i "s,CONFIGDIR,$configdir," /etc/bash_completion.d/jdocker
  sudo sed -i "s,CONTDIR,$containersdir," /etc/bash_completion.d/jdocker
  sudo sed -i "s,IMGDIR,$imgdir," /etc/bash_completion.d/jdocker
  echo
  message "Auto complétion installée. Redémarrez la session ou chargez la complétion avec :"
  echo "  source /etc/bash_completion"
  echo
  exit 0
fi

checkarg() {
  if [[ $# -eq 0 ]]; then
    error "Aucune application spécifiée en paramètre"
    return 1
  fi
}

process() {
  local action=$1
  shift
  for app in $@; do
    if [[ ! -d "$configdir/$app" ]]; then
      error "Application $app introuvable"
      continue
    fi
    case $action in
      install)
        warning "Déploiement de $app..."
        $compose -f "$configdir/$app/"*compose.yml up -d
        message "Application $app déployée"
        ;;
      remove)
        warning "Suppression de $app..."
        $compose -f "$configdir/$app/"*compose.yml down
        message "Application $app supprimée"
        ;;
      pull)
        if ! grep -q "image:.*localhost" "$configdir/$app/"*compose.yml; then
          warning "Récupération de la nouvelle image $app..."
          podman pull $(grep "image:" "$configdir/$app/"*compose.yml | awk '{print $2}')
          message "Nouvelle image $app récupérée"
        fi
        ;;
      backup)
        if [[ -d $containersdir/$app ]]; then
          if podman container exists $app; then
            restartafter=1
            process remove $app
          fi
          mkdir -p $destbackup/$app
          cd $containersdir
          warning "Sauvegarde de $app..."
          bckfile=$app.$(date '+%Y%m%d%H%M').tar.gz
          podman unshare tar czf $bckfile $app
          podman unshare chown root: $bckfile
          mv $bckfile $destbackup/$app
          find $destbackup/$app -name $app.*.gz -mtime +$retention -exec rm {} \;
          ls $destbackup/$app/$bckfile
          message "Sauvegarde terminée"
          if (($restartafter)); then
            process install $app
          fi
        fi
        ;;
    esac
  done
}

# Commandes
case $1 in
  ls | list)
    podman container ls -a --format "table {{.Names}} \t {{.Status}}"
    ;;
  lsa | listall)
    podman container ls -a --format "table {{.Names}} \t {{.Status}} \t {{.Ports}} \t {{.Image}}"
    ;;
  it | install)
    shift
    checkarg $@ || exit 1
    process install $@
    ;;
  rm | remove)
    shift
    checkarg $@ || exit 1
    process remove $@
    ;;
  r | restart)
    shift
    checkarg $@ || exit 1
    for app in $@; do
      podman restart $app
    done
    ;;
  pr | purge)
    warning "Suppression dans images non utilisées..."
    podman system prune -f
    message "Nettoyage terminé"
    ;;
  pra | purgeall)
    warning "Suppression des images et des volumes non utilisés..."
    podman system prune -f -a --volumes
    message "Nettoyage terminé"
    ;;
  lo | load)
    shift
    for img in $@; do
      if [[ ! -f $imgdir/$img ]]; then
        error "Fichier $img non trouvé dans $imgdir"
      else
        podman load -i $imgdir/$img
      fi
    done
    ;;
  up | upgrade)
    shift
    checkarg $@ || exit 1
    for app in $@; do
      process pull $app
      process remove $app
      process backup $app
      process install $app
    done
    ;;
  p | pull)
    if [[ ! -z "$2" ]]; then
      shift
      process pull $@
    else
      podman images | grep -v ^REPO | grep -v localhost | sed 's/ \+/:/g' | cut -d: -f1,2 | xargs -L1 $sudo podman pull
    fi
    ;;
  l | logs)
    if [[ -z "$3" ]]; then
      podman logs -f $2
    else
      podman logs --since=$3 $2
    fi
    ;;
  at | attach)
    warning "Ctrl+p, Ctrl+q pour quitter"
    podman attach $2
    ;;
  ps | stats)
    podman stats --format "table {{.Name}}\t {{.CPUPerc}}\t {{.MemUsage}}"
    ;;
  psa | statsall)
    podman stats --format "table {{.Name}}\t {{.CPUPerc}}\t {{.MemPerc}}\t {{.MemUsage}}\t {{.NetIO}}\t {{.BlockIO}}"
    ;;
  sh | bash)
    podman exec -it $2 sh
    ;;
  n | networks)
    podman network ls
    ;;
  i | images)
    podman images
    ;;
  u | unshare)
    shift
    podman unshare $*
    ;;
  v | volumes)
    podman volume ls
    ;;
  bk | backup)
    if [[ ! -z "$2" ]]; then
      shift
      process backup $@
    else
      if [[ -f $dir/jdocker.cron ]]; then
        sudo cp $dir/jdocker.cron /etc/cron.d/jdocker
        sudo sed -i "s,SCR,$(realpath "$0")," /etc/cron.d/jdocker
        sudo sed -i "s,USER,$user," /etc/cron.d/jdocker
        message "Fichier /etc/cron.d/jdocker en place"
        cat /etc/cron.d/jdocker
      else
        error "Fichier $dir/jdocker.cron absent"
      fi
    fi
    ;;
  * | help)
    echo
    message "Commandes disponibles :"
    cat $dir/.jdocker.help
    ;;
esac
