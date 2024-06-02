#!/bin/dash

## Variables
dir=$(dirname "$0")
cfg="$dir/$(basename -s .sh $0).cfg"

## Config
if [ -f $cfg ] ; then
    . $cfg
else
    echo "Fichier $cfg introuvable"
    exit 0
fi

## Sudo
if [ -f /usr/bin/sudo ] ; then
    sudo=/usr/bin/sudo
fi

## Verification
if [ ! -f /usr/bin/docker ] && [ -f /usr/bin/apt ] ; then
    echo "Docker n'est pas installé. Installation..."
    $sudo apt install docker.io docker-compose
    exit 0
elif [ -f /usr/bin/docker-compose ] ; then
    compose="docker-compose"
else
    compose="docker compose"
fi

## Commandes
case $1 in
    list|ls)
        $sudo docker container ls -a --format "table {{.Names}} \t {{.Status}}"
        ;;
    listall|lsa)
        $sudo docker container ls -a --format "table {{.Names}} \t {{.Status}} \t {{.Ports}} \t {{.Image}}"
        ;;
    install|it)
        if [ ! -f $dir/cfg/$2/docker-compose.yml ] || [ -z "$2" ] ; then
            echo "Applications disponibles :"
            ls -1 $dir/cfg
            exit 0
        else
            if [ -f $dir/cfg/$2/$(hostname).env ] ; then
                $sudo $compose -f $dir/cfg/$2/docker-compose.yml --env-file $dir/cfg/$2/$(hostname).env up -d
            else
                $sudo $compose -f $dir/cfg/$2/docker-compose.yml up -d
            fi
        fi
        ;;
    remove|rm)
        if [ -f $dir/cfg/$2/docker-compose.yml ] ; then
            if [ -f $dir/cfg/$2/$(hostname).env ] ; then
                $sudo $compose -f $dir/cfg/$2/docker-compose.yml --env-file $dir/cfg/$2/$(hostname).env down
            else
                $sudo $compose -f $dir/cfg/$2/docker-compose.yml down
            fi
        fi
        ;;
    restart|r)
        $sudo docker restart $2
        ;;
    purge|pr)
        $sudo docker system prune -f -a --volumes
        ;;
    upgrade|up)
        if [ ! -z "$2" ] ; then
            shift
            for appup in $* ; do
                $dir/jdocker.sh rm $appup
                $dir/jdocker.sh it $appup
            done
        else
            $sudo docker images | grep -v ^REPO | grep -v none | sed 's/ \+/:/g' | cut -d: -f1,2 | xargs -L1 $sudo docker pull
        fi
        ;;
    logs|l)
        if [ -z "$3" ] ; then
            $sudo docker logs -f $2
        else
            $sudo docker logs --since=$3 $2
        fi
        ;;
    extract|e)
        logfile=$($sudo docker inspect --format='{{.LogPath}}' $2)
        $sudo cat $logfile > $2.log
        echo "fichier $2.log créé"
        ;;
    search|s)
        $sudo docker search $2
        ;;
    attach|at)
        echo "Ctrl+p, Ctrl+q pour quitter"
        $sudo docker attach $2
        ;;
    stats|ps)
        $sudo docker stats --format "table {{.Name}}\t {{.CPUPerc}}\t {{.MemPerc}}\t {{.MemUsage}}\t {{.NetIO}}\t {{.BlockIO}}"
        ;;
    bash|sh)
        $sudo docker exec -it $2 sh
        ;;
    net|n)
        $sudo docker network ls
        ;;
    volume|v)
        $sudo docker volume ls
        ;;
    backup|bk)
        if [ ! -z "$2" ] ; then
            if [ -d /opt/$2 ] ; then
                if [ ! -d $destbackup/$2/.old ] ; then
                    $sudo mkdir -p $destbackup/$2/.old
                    $sudo chown -R $user: $destbackup/$2
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
            if [ -f $dir/.cron.$(hostname) ] ; then
                cron=$dir/.cron.$(hostname)
            else
                cron=$dir/.cron
            fi
            if [ -f $cron ] ; then
                $sudo cp -v $cron /etc/cron.d/jdocker
                $sudo sed -i "s,DIR,$dir," /etc/cron.d/jdocker
            else 
                echo "Fichier $cron absent"
                exit 0
            fi
        fi
        ;;
    lzd|lazydocker)
        if [ ! -f /usr/bin/lazydocker ] ; then
            $sudo curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
            $sudo mv /$HOME/.local/bin/lazydocker /usr/bin/lazydocker
            $sudo chown root: /usr/bin/lazydocker
        else
            $sudo /usr/bin/lazydocker
        fi
        ;;
    *)
        cat $dir/.help
        ;;
esac
