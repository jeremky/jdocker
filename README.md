# jdocker.sh

Ce script permet une administration plus simplifiée des conteneurs Podman en mode rootless. Les fichiers de déploiement sont centralisés dans le répertoire de votre choix, ce qui permet de les déployer facilement, sans avoir besoin d'être dans le dossier où se trouve le fichier `compose.yml`.

## Configuration

Avant d'utiliser ce script, vous devez tout d'abord renommer le fichier `.jdocker.cfg.template` `jdocker.cfg`, pour ensuite y indiquer les informations suivantes :

- Votre nom d'utilisateur, utilisé pour la création des dossiers nécessaires au bon fonctionnement du script

- L'application de composition à utiliser. Si vous n'en avez pas déjà, laissez `podman-compose`. Il sera automatiquement installé lors du premier lancement du script.

- Le port minimal autorisé utilisé par vos conteneurs.

- Les différents répertoires où sont stockées les données (les fichiers `compose.yml`, les backups, les volumes...)

```txt
# jdocker config
user=votre_user

# applications compose à utiliser (remplacez par docker-compose si podman-docker est installé)
compose=podman-compose

# port minimal à autoriser
port=80

# dossier des fichiers compose
configdir=$dir/cfg

# dossier des volumes
containersdir=/opt/containers

# dossier des sauvegardes
destbackup=/home/$user/backups

# rétention des sauvegardes (en jours)
retention=7

# dossier des images locales
imgdir=/tmp/dockerimg

# sauvegarde automatique lors de l'upgrade
autobackup=false

# ménage automatique après upgrade
autoclean=true

```

> le dossier `configdir` doit contenir un sous dossier pour chaque application, avec un fichier `compose.yml` et un fichier `.env`

## Utilisation

Lancez le script une première fois pour installer Podman et l'auto complétion. Si vous déplacez le script, supprimez le fichier `/etc/bash_completion.d/jdocker` et relancez-le.

Pour consulter l'aide, lancez `./jdocker.sh` sans paramètre :

```txt
Commandes disponibles :
  ls  | list            Lister les conteneurs actifs
  lsa | listall         Lister les conteneurs actifs avec les ports et l'image utilisée
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
  ps  | stats           Afficher les statistiques des conteneurs en cours d'exécution
  psa | statsall        Afficher les statistiques des conteneurs détaillées
  sh  | bash            Se connecter au bash d'un conteneur spécifié
  bk  | backup          Sauvegarder un conteneur spécifié
  u   | unshare         Basculer l'ID via la commande podman unshare
  lzd | lazydocker      Lance l'outil lazydocker et l'installe s'il n'est pas présent
  h   | help            Afficher cette aide
```

## Sauvegarde

`jdocker.sh` propose un système de sauvegarde des volumes. Pour automatiser vos sauvegardes, renommez le fichier `.jdocker.cron.template` en `jdocker.cron` , puis adaptez-le selon vos préférences. 
Exécutez ensuite `./jdocker.sh bk` pour le copier automatiquement dans le répertoire `/etc/cron.d`.

```txt
# jdocker cron
jdocksh=$dir/jdocker.sh

# exemple1
0 0 * * *  $user $jdocksh bk exemple1 >/dev/null 2>&1

# exemple2
0 1 * * *  $user $jdocksh bk exemple2 >/dev/null 2>&1
```
