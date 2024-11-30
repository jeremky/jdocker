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
if [ ! -f /usr/bin/podman ] && [ -f /usr/bin/apt ] ; then
    echo "Podman n'est pas installé. Installation..."
    $sudo apt install podman podman-compose catatonit
    exit 0
fi

## Commandes
case $1 in
    list|ls)
        $sudo podman container ls -a --sort runningfor --format "table {{.Names}} \t {{.Status}}"
        ;;
    listall|lsa)
        $sudo podman container ls -a --sort names --format "table {{.Names}} \t {{.Status}} \t {{.Ports}}"
        ;;
    install|it)
        shift
        for app in $* ; do
            if [ ! -f $dir/cfg/$app/*compose.yml ] || [ -z "$1" ] ; then
                echo "Application $app non trouvée"
                echo ""
                exit 0
            else
                $sudo podman-compose -f $dir/cfg/$app/*compose.yml up -d
                if [ ! -f /etc/systemd/system/container-$app.service ] ; then
                    cd /etc/systemd/system && $sudo podman generate systemd --new --name --files $app
                    $sudo systemctl daemon-reload
                    $sudo systemctl enable --now container-$app.service
                fi
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
                if [ -f /etc/systemd/system/container-$app.service ] ; then
                    $sudo systemctl disable --now container-$app.service
                    $sudo rm /etc/systemd/system/container-$app.service
                    $sudo systemctl daemon-reload
                fi
            fi
        done
        ;;
    restart|r)
        $sudo systemctl restart container-$2.service
        ;;
    purge|pr)
        $sudo podman system prune -f
        ;;
    purgeall|pra)
        $sudo podman system prune -f -a --volumes
        ;;
    load|lo)
        if [ ! -d $imgdir/.old ] ; then
            mkdir $imgdir/.old
        fi
        for file in $(ls $imgdir/*.tar) ; do
            $sudo podman load -i $file
            mv $file $imgdir/.old
        done
        ;;
    upgrade|up)
        if [ ! -z "$2" ] ; then
            shift
            for app in $* ; do
                if [ -f /etc/systemd/system/container-$app.service ] ; then
                    $sudo systemctl restart container-$app.service
                fi
            done
        else
            $sudo podman auto-update
        fi
        ;;
    logs|l)
        if [ -z "$3" ] ; then
            $sudo podman logs -f $2
        else
            $sudo podman logs --since=$3 $2
        fi
        ;;
    search|s)
        $sudo podman search $2
        ;;
    attach|at)
        echo "Ctrl+p, Ctrl+q pour quitter"
        $sudo podman attach $2
        ;;
    stats|ps)
        $sudo podman stats --format "table {{.Name}}\t {{.CPUPerc}}\t {{.MemUsage}}"
        ;;
    statsall|psa)
        $sudo podman stats --format "table {{.Name}}\t {{.CPUPerc}}\t {{.MemPerc}}\t {{.MemUsage}}\t {{.NetIO}}\t {{.BlockIO}}"
        ;;
    bash|sh)
        $sudo podman exec -it $2 sh
        ;;
    net|n)
        $sudo podman network ls
        ;;
    volume|v)
        $sudo podman volume ls
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
    *)
        cat $dir/.jdocker.help
        ;;
esac
