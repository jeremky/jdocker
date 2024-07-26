# jdocker.sh

Script permettant une administration plus simplifiée des conteneurs Docker 

- Avant d'utiliser ce script, vous devez tout d'abord modifier le fichier jdocker.cfg pour remplacer votre nom d'utilisateur, et la destination des backups.

- Pour automatiser vos backups, il y a un fichier .cron dans ce répertoire. Modifiez le selon vos préférences. Faites ensuite ./jdocker.sh bk pour le copier dans le répertoire des cron.

Pour consulter l'aide, lancez ./jdocker.sh sans paramètre.

Commandes :
  ls  | list            Lister les conteneurs actifs
  lsa | listall         Lister les conteneurs actifs avec les ports et l'image utilisée
  n   | net             Lister les réseaux docker
  v   | volume          Lister les volumes docker
  l   | logs            Consulter les logs pour un conteneur spécifié
  e   | extract         Extraire les logs dans un fichier
  lzd | lazydocker      Installer lazydocker
  it  | install         Installer un conteneur avec compose
  rm  | remove          Supprimer un conteneur avec compose
  r   | restart         Redémarrer un conteneur
  pr  | purge           Purger les anciennes images, et les volumes et réseaux non utilisés
  s   | search          Rechercher une image docker
  at  | attach          S'attacher au prompt ouvert pour un conteneur spécifié
  up  | upgrade         Recherche une nouvelle version des images docker.
                        Si un conteneur est spécifié, supprime et réinstalle ce dernier
  ps  | stats           Affiche les statistiques des images docker en cours d'exécution
  sh  | bash            Se connecter au bash d'un conteneur spécifié
  bk  | backup          Sauvegarde un conteneur spécifié.
                        Si aucun paramètre, copie le fichier .cron dans /etc/cron.d.
                        Paramètres supplémentaires :
                            f|full      Sauvegarde full
                            i|incr      Sauvegarde incrémentielle
