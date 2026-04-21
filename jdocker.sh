#!/bin/bash

# Messages en couleur
error() { echo -e "\033[0;31m====> $*\033[0m"; }
message() { echo -e "\033[0;32m====> $*\033[0m"; }
warning() { echo -e "\033[0;33m====> $*\033[0m"; }

# Chargement du fichier de config
cfg="$HOME/.config/jdocker/jdocker.cfg"
if [[ -f $cfg ]]; then
  # shellcheck source=./jdocker.cfg
  . $cfg
else
  error "Fichier $HOME/.config/jdocker/jdocker.cfg introuvable"
  exit 1
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
  for app in "$@"; do
    if [[ ! -f "$composedir/$app/compose.yml" ]]; then
      echo
      error "Fichier compose.yml pour $app introuvable, $action impossible"
      continue
    fi
    case $action in
      install)
        if ! podman container exists $app; then
          echo && warning "Déploiement de $app..."
          if podman-compose -f $composedir/$app/compose.yml up -d; then
            message "Application $app déployée"
          else
            error "Erreur lors du déploiement de $app"
          fi
        else
          error "Application $app déjà déployée"
        fi
        ;;
      remove)
        if podman container exists $app; then
          echo && warning "Suppression de $app..."
          if podman-compose -f $composedir/$app/compose.yml down; then
            message "Application $app supprimée"
          else
            error "Erreur lors de la suppression de $app"
          fi
        else
          error "Application $app non déployée"
        fi
        ;;
      pull)
        echo && warning "Pull des images pour $app..."
        while IFS= read -r image; do
          if podman pull "$image"; then
            message "Pull terminé pour $image"
          else
            error "Erreur de pull pour $image"
          fi
        done < <(grep "image:" $composedir/$app/compose.yml | awk '{print $2}' | grep -v "^localhost")
        ;;
      backup)
        restartafter=0
        if [[ -d "$volumesdir/$app" ]]; then
          if podman container exists $app; then
            restartafter=1
            process remove $app
          fi
          mkdir -p "$backupsdir/$app"
          echo && warning "Sauvegarde de $app..."
          bckfile=$backupsdir/$app/$app.$(date '+%Y%m%d%H%M').tar.gz
          if podman unshare bash -c "tar -C $volumesdir -czf $bckfile $app && chown root: $bckfile"; then
            find $backupsdir/$app -name "$app.*.gz" -mtime +$backupdays -exec rm {} \;
            ls $bckfile
            message "Sauvegarde de $app terminée"
          else
            error "Erreur lors de la sauvegarde de $app"
          fi
          if (($restartafter)); then
            process install $app
          fi
        fi
        ;;
    esac
  done
}

purge() {
  options=$*
  echo && warning "Suppression des données non utilisées..."
  if podman system prune $options; then
    message "Nettoyage terminé"
  else
    error "Erreur lors du nettoyage"
  fi
}

# Commandes
case $1 in
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
  r | restart)
    shift
    checkarg "$@" || exit 1
    for app in "$@"; do
      podman restart "$app"
    done
    ;;
  pr | purge)
    purge -a -f
    echo
    ;;
  pra | purgeall)
    purge -a --volumes
    echo
    ;;
  lo | load)
    shift
    for img in "$@"; do
      if [[ ! -f "$imagesdir/$img" ]]; then
        error "Fichier $img non trouvé dans $imagesdir"
      else
        podman load -i "$imagesdir/$img"
      fi
    done
    ;;
  up | upgrade)
    shift
    checkarg "$@" || exit 1
    for app in "$@"; do
      process pull $app
      process remove $app
      [[ $autobackup = true ]] && process backup $app
      process install $app
    done
    [[ $autoclean = true ]] && purge -a -f
    echo
    ;;
  p | pull)
    if [[ -n "$2" ]]; then
      shift
      process pull "$@"
      echo
    else
      podman images --format "{{.Repository}}:{{.Tag}}" | grep -v '^localhost' | xargs -r -L1 podman pull
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
    echo && warning "Ctrl+p, Ctrl+q pour quitter"
    podman attach $2
    ;;
  ps | lsa)
    podman container ls -a --format "table {{.ID}} {{.Names}} {{.Image}} {{.CreatedHuman}} {{.Status}} {{.Ports}}"
    ;;
  s | stats)
    podman stats --format "table {{.Name}}  {{.CPUPerc}}  {{.MemPerc}}  {{.MemUsage}}  {{.NetIO}}"
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
    if [[ -n "$2" ]]; then
      shift
      process backup "$@"
      echo
    fi
    ;;
  *)
    echo
    message "Commandes disponibles :"
    cat <<'EOF'
    ls  | list            Lister les conteneurs actifs
    n   | networks        Lister les réseaux virtuels
    v   | volumes         Lister les volumes virtuels
    i   | images          Lister les images
    l   | logs            Consulter les logs pour un conteneur spécifié
    lo  | load            Charger une ou plusieurs images locales spécifiées
    it  | install         Installer un conteneur avec compose
    rm  | remove          Supprimer un conteneur avec compose
    r   | restart         Redémarrer un conteneur
    pr  | purge           Purger les images et les réseaux non utilisés
    pra | purgeall        Purger également les volumes non utilisés
    at  | attach          S'attacher au prompt ouvert pour un conteneur spécifié
    p   | pull            Récupérer la dernière version de l'image d'un conteneur spécifié
    up  | upgrade         Télécharger la dernière image et mettre à jour un conteneur spécifié
    ps  | lsa             Afficher les informations détaillées des conteneurs
    s   | stats           Afficher les statistiques en temps réel des conteneurs
    sh  | bash            Se connecter au bash d'un conteneur spécifié
    bk  | backup          Sauvegarder un conteneur spécifié
    u   | unshare         Basculer l'ID via la commande podman unshare
    h   | help            Afficher cette aide
EOF
    echo
    ;;
esac
