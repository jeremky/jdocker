#!/bin/dash
set -e

dir=$(dirname "$0")

## Chargement du fichier de config
cfg="$dir/$(basename -s .sh $0).cfg"
if [ -f $cfg ] ; then
  . $cfg
else
  echo "Fichier $cfg introuvable"
  exit 0
fi

## Vérification de sudo
if [ -f /usr/bin/sudo ] ; then
  sudo=/usr/bin/sudo
fi

## Docker / Podman
if [ -f /usr/bin/podman ] ; then
  dockerapp=podman
else
  dockerapp=docker
fi

## Patch Docker CE
if [ ! -f /usr/bin/docker-compose ] && [ $dockerapp = "docker" ] ; then
  compose="$dockerapp compose"
else
  compose="$dockerapp-compose"
fi

## Installation de Podman si Docker n'est pas trouvé
if [ ! -f /usr/bin/$dockerapp ] && [ -f /usr/bin/apt ] ; then
  echo "Docker n'est pas installé. Installation de Podman..."
  $sudo apt install podman podman-compose
  exit 0
fi

## Installation de la complétion et des droits sudo
if [ ! -f /etc/bash_completion.d/jdocker ] ; then
  $sudo cp $dir/.jdocker.comp /etc/bash_completion.d/jdocker
  $sudo sed -i "s,DIR,$dir," /etc/bash_completion.d/jdocker
  $sudo sed -i "s,DOCKERAPP,$dockerapp," /etc/bash_completion.d/jdocker
  $sudo cp $dir/.jdocker.sudo /etc/sudoers.d/jdocker
  $sudo sed -i "s,USER,$user," /etc/sudoers.d/jdocker
  $sudo chmod 600 /etc/sudoers.d/jdocker
  echo "Droits sudo et auto complétion installés. Redémarrez votre session"
  exit 0
fi

## Commandes
case $1 in
  list|ls)
    $sudo $dockerapp container ls -a --format "table {{.Names}} \t {{.Status}}"
    ;;
  listall|lsa)
    $sudo $dockerapp container ls -a --format "table {{.Names}} \t {{.Status}} \t {{.Ports}}"
    ;;
  install|it)
    shift
    for app in $* ; do
      if [ ! -f $dir/cfg/$app/*compose.yml ] || [ -z "$1" ] ; then
        echo "Application $app non trouvée"
        echo ""
        exit 0
      else
        $sudo $compose -f $dir/cfg/$app/*compose.yml up -d
      fi
    done
    ;;
  remove|rm)
    shift
    for app in $* ; do
      if [ ! -f $dir/cfg/$app/*compose.yml ] || [ -z "$1" ] ; then
        echo "Application $app non trouvée"
        echo ""
        exit 0
      else
        $sudo $compose -f $dir/cfg/$app/*compose.yml down
      fi
    done
    ;;
  restart|r)
    if [ ! -z "$2" ] ; then
      shift
      for app in $* ; do
          $sudo $dockerapp restart $app
      done
    fi
    ;;
  purge|pr)
    $sudo $dockerapp system prune -f
    ;;
  purgeall|pra)
    $sudo $dockerapp system prune -f -a --volumes
    ;;
  load|lo)
    if [ ! -d $imgdir/.old ] ; then
      mkdir $imgdir/.old
    fi
    for file in $(ls $imgdir/*.tar) ; do
      $sudo $dockerapp load -i $file
      mv $file $imgdir/.old
    done
    ;;
  upgrade|up)
    if [ ! -z "$2" ] ; then
      shift
      for app in $* ; do
        $dir/jdocker.sh rm $app
        $dir/jdocker.sh it $app
      done
    else
      $sudo $dockerapp images | grep -v ^REPO | sed 's/ \+/:/g' | cut -d: -f1,2 | xargs -L1 $sudo $dockerapp pull
    fi
    ;;
  logs|l)
    if [ -z "$3" ] ; then
      $sudo $dockerapp logs -f $2
    else
      $sudo $dockerapp logs --since=$3 $2
    fi
    ;;
  search|s)
    $sudo $dockerapp search $2
    ;;
  attach|at)
    echo "Ctrl+p, Ctrl+q pour quitter"
    $sudo $dockerapp attach $2
    ;;
  stats|ps)
    $sudo $dockerapp stats --format "table {{.Name}}\t {{.CPUPerc}}\t {{.MemUsage}}"
    ;;
  statsall|psa)
    $sudo $dockerapp stats --format "table {{.Name}}\t {{.CPUPerc}}\t {{.MemPerc}}\t {{.MemUsage}}\t {{.NetIO}}\t {{.BlockIO}}"
    ;;
  bash|sh)
    $sudo $dockerapp exec -it $2 sh
    ;;
  networks|n)
    $sudo $dockerapp network ls
    ;;
  volumes|v)
    $sudo $dockerapp volume ls
    ;;
  backup|bk)
    if [ ! -z "$2" ] ; then
      if [ -d /opt/$2 ] ; then
        if [ ! -d $destbackup/$2/.old ] ; then
          $sudo mkdir -p $destbackup/$2/.old
          $sudo chown -R $user: $destbackup
        fi
        $dir/jdocker.sh rm $2
        cd /opt
        num=0
        tarlist=.$2.$num.list
        tarname=$2.$num.tar.gz
        case $3 in
          f|full)
            if [ -f .$2.0.list ] ; then
              $sudo rm -f .$2.*.list
            fi
            if [ -f $destbackup/$2/$2.0.tar.gz ] ; then
              $sudo mv $destbackup/$2/$2.*.gz $destbackup/$2/.old
            fi
            echo "Sauvegarde full de $2..."
            $sudo tar czg $tarlist -f $tarname $2
            $sudo chown $user: $tarname
            $sudo mv $tarname $destbackup/$2
            ;;
          i|incr)
            if [ ! -f .$2.0.list ] ; then
              echo "Sauvegarde full introuvable. Arrêt"
              exit 0
            fi
            while [ -f $tarlist ] ; do
              num=$(( $num + 1 ))
              tarlist=.$2.$num.list
              tarname=$2.$num.tar.gz
            done
            $sudo cp .$2.$(( $num - 1 )).list $tarlist
            echo "Sauvegarde incrémentielle de $2..."
            $sudo tar czg $tarlist -f $tarname $2
            $sudo chown $user: $tarname
            $sudo mv $tarname $destbackup/$2
            ;;
          *)
            echo "Sauvegarde de $2..."
            $sudo tar czf $2.$(date '+%Y%m%d').tar.gz $2
            $sudo chown $user: $2.$(date '+%Y%m%d').tar.gz
            $sudo mv $2.$(date '+%Y%m%d').tar.gz $destbackup/$2
            $sudo find $destbackup/$2 -name $2.*.gz -mtime +10 -exec rm {} \;
            ;;
        esac
        echo "Sauvegarde terminée. Relance..."
        $dir/jdocker.sh it $2
      else
        echo "Dossier /opt/$2 non trouvé"
      fi
    else
      if [ -f $dir/.jdocker.cron ] ; then
        $sudo cp -v $dir/.jdocker.cron /etc/cron.d/jdocker
        $sudo sed -i "s,DIR,$dir," /etc/cron.d/jdocker
      else
        echo "Fichier $dir/.jdocker.cron absent"
        exit 0
      fi
    fi
    ;;
  lzd|lazydocker)
    if [ ! -f /usr/bin/lazydocker ] ; then
      $sudo curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
      $sudo mv /$HOME/.local/bin/lazydocker /usr/bin/lazydocker
      $sudo chown root: /usr/bin/lazydocker
      if [ ! -e /var/run/docker.sock ] ; then
        $sudo ln -s /var/run/podman/podman.sock /var/run/docker.sock
      fi
    else
      $sudo /usr/bin/lazydocker
    fi
    ;;
  completion)
    echo list listall networks volumes logs load lazydocker install remove restart purge purgeall search attach upgrade stats statsall bash backup help
    ;;
  *|help)
    cat $dir/.jdocker.help
    ;;
esac
