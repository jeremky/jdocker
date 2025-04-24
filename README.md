# jdocker.sh

Ce script permet une administration plus simplifiée des conteneurs Docker/Podman. Un répertoire `cfg` permet de ranger ses fichiers `compose.yml` afin de les déployer de n'importe où.

## Configuration

Avant d'utiliser ce script, vous devez tout d'abord modifier le fichier `jdocker.cfg`, pour spécifier les informations suivantes :

- Votre nom d'utilisateur, utilisé pour la création des dossiers nécessaires au bon fonctionnement du script

- Les applications de conteneurisation à utiliser. Si vous n'en avez pas déjà, laissez `podman`. Il sera automatiquement installé au 1er lancement

- Le mode rootless, à passer à `off` seulement si là encore, vous avez déjà un environnement en place avec Docker ou Podman en rootfull

- Le port minimal autorisé utilisé par vos conteneurs. Nécessaire pour le mode rootless

## Utilisation

Lancez le script une première fois pour installer l'auto complétion. Si vous déplacez le script, supprimez le fichier `/etc/bash_completion.d/jdocker` et relancez le.

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
  lo  | load            Charge les images présentes dans le dossier $imgdir
  it  | install         Installer un conteneur avec compose
  rm  | remove          Supprimer un conteneur avec compose
  r   | restart         Redémarrer un conteneur
  pr  | purge           Purger les anciennes images
  pra | purgeall        Purge les images, les volumes et réseaux non utilisés
  at  | attach          S'attacher au prompt ouvert pour un conteneur spécifié
  up  | upgrade         Recherche des nouvelles versions d'image ou upgrade un conteneur spécifié
  ps  | stats           Affiche les statistiques des conteneurs en cours d'exécution
  psa | statsall        Affiche davantage de statistiques des conteneurs
  sh  | bash            Se connecter au bash d'un conteneur spécifié
  bk  | backup          Sauvegarde un conteneur spécifié
```
