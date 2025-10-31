La finalité de ce projet est de creer un système NetBD minimal dans une machine
virtuelle, capable de démarrer et de lancer un service en moins d'une
seconde.


L'installation préalable d'un système NetBSD n'est pas obligatoire, en
utilisant les outils fournis, la microvm peut être créée depuis un
système NetBSD, GNU/Linux, MacOS et probablement d'autres.

Lorsque l'on crée une image sur un système NetBSD, cette image sera
formatée en utilisant le système de fichiers FFS, lorsque l'on crée une
image sur GNU/Linux, cette image sera formatée en utilisant ext2.

PVH associé a de nombreuses optimisations permet a NetBSD/amd64 et
NetBSD/i386 de démarrer depuis un VMM compatible PVH (QEMU ou
Firecracker) en quelques milisecondes.

Depuis Juin 2025, la plupart de ces fonctionnalités sont intégrés au
noyau NetBSD 'current' et aux versions de NetBSD 11, celles qui ne le
sont pas encore, sont disponibles dans ma branche de devellopement
NetBSD.

Vous pouvez récupérer un noyau 64 bits deja compilé a l'addresse suivante : 
https://smolbsd.org/assets/netbsd-SMOL
et un noyau 32 bits ici :
https://smolbsd.org/assets/netbsd-SMOL386 
Attention ces noyaux sont issus de la branche 'NetBSD-current'.

