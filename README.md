# jdocker.sh

Ce script permet une administration plus simplifiée des conteneurs Docker/Podman. Les fichiers `docker-compose.yml` sont centralisés dans le répertoire de votre choix, ce qui permet de les déployer facilement, sans avoir besoin d'être dans le dossier où se trouve le fichier `docker-compose.yml`.

## Configuration

Avant d'utiliser ce script, vous devez tout d'abord modifier le fichier `jdocker.cfg`, pour spécifier les informations suivantes :

- Votre nom d'utilisateur, utilisé pour la création des dossiers nécessaires au bon fonctionnement du script

- Les applications de conteneurisation à utiliser. Si vous n'en avez pas déjà, laissez `podman`. Il sera automatiquement installé lors du premier lancement du script.

- Le mode rootless, à passer à `off` seulement si là encore, vous avez déjà un environnement en place avec Docker ou Podman en rootful

- Le port minimal autorisé utilisé par vos conteneurs. Nécessaire pour le mode rootless

- Les différents répertoires où sont stockées les données (fichiers `docker-compose.yml`, les backups, les volumes...)

```txt
# jdocker config
user=votre_user

# applications à utiliser (podman/docker)
dockerapp=podman
compose=podman-compose

# rootless (si podman est utilisé)
rootless=on
port=80

# répertoires
configdir=/chemin/vers/compose
containersdir=/opt/containers
destbackup=/home/votre_user/backups
imgdir=/opt/dockerimg
```

> le dossier `configdir` doit contenir un sous dossier pour chaque application, avec un fichier `compose.yml` et un fichier `.env`

## Utilisation

Lancez le script une première fois pour installer l'auto complétion. Si vous déplacez le script, supprimez le fichier `/etc/bash_completion.d/jdocker` et relancez-le.

Pour automatiser vos backups, il y a un fichier `jdocker.cron` dans ce répertoire. Modifiez le selon vos préférences. Exécutez ensuite `./jdocker.sh bk` pour le copier dans le répertoire `/etc/cron.d`

Pour consulter l'aide, lancez `./jdocker.sh` sans paramètre :

```txt
Commandes disponibles :
  ls  | list            Lister les conteneurs actifs
  lsa | listall         Lister les conteneurs actifs avec les ports et l'image utilisée
  n   | networks        Lister les réseaux virtuels
  v   | volumes         Lister les volumes virtuels
  i   | images          Lister les images
  l   | logs            Consulter les logs pour un conteneur spécifié
  lo  | load            Charger les images présentes dans le dossier dédié
  it  | install         Installer un conteneur avec compose
  rm  | remove          Supprimer un conteneur avec compose
  r   | restart         Redémarrer un conteneur
  pr  | purge           Purger les anciennes images
  pra | purgeall        Purger les images, les volumes et réseaux non utilisés
  at  | attach          S'attacher au prompt ouvert pour un conteneur spécifié
  up  | upgrade         Rechercher des nouvelles versions d'image ou mettre à jour un conteneur spécifié
  ps  | stats           Afficher les statistiques des conteneurs en cours d'exécution
  psa | statsall        Afficher les statistiques des conteneurs détaillées
  sh  | bash            Se connecter au bash d'un conteneur spécifié
  bk  | backup          Sauvegarder un conteneur spécifié (droits root nécessaires)
```
