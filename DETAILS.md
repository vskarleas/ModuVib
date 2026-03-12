# Application features

    Contexte :

    Le concept retenu, « ModuVib », repose sur un module dorsal superposable au vêtement compressif, conçu
    pour être simple à déployer et facile à maintenir. Le projet de session se concentre sur le module dos, mais
    l’architecture a été pensée de façon modulaire : un même principe peut être décliné en plusieurs modules indépendants
    (dos, bras, jambes) pouvant fonctionner seuls ou en combinaison.
    Remarque : cette modularité ne change pas l’objectif principal, centré sur le prurit dorsal chez les grands brûlés.
    Elle constitue toutefois un atout de conception, car elle permet d’envisager, à terme, une adaptation du système à
    d’autres localisations nécessitant une stimulation similaire, sans refondre l’architecture.
    Contrairement à une solution cousue au textile, le dispositif est amovible : les modules se fixent directement
    par-dessus le vêtement compressif. Cette approche simplifie l’hygiène et l’usage quotidien : le vêtement conserve
    ses habitudes de lavage, tandis que l’électronique est protégée et peut être nettoyée séparément. Le module vise une
    résistance aux conditions usuelles (transpiration et projections), avec une cible de protection de type IPX4.
    Sur le plan technique, le système s’appuie sur des éléments robustes et accessibles :
    — Pilotage : chaque module est géré par un microcontrôleur compact ( comme le XIAO ESP32-C3 ) et commu-
    nique en Bluetooth
    .
    — Interface : les réglages (intensité, modes, séquences) sont effectués via une application mobile, afin de
    limiter les manipulations et d’éviter la recherche de commandes physiques sur une zone difficile d’accès comme
    le dos. Ce choix est cohérent avec le profil d’usage identifié, notamment la dextérité/aisance limitée de la
    main gauche, qui impose une commande simple et centralisée.Cette interface facilite aussi l’implantation de
    règles de sécurité (temporisation, arrêt automatique. . .).
    Remarque : en cas d’indisponibilité de l’application (panne, incompatibilité, batterie du téléphone), un
    mode manuel de secours est prévu directement sur le module, avec un bouton marche/arrêt et un
    potentiomètre permettant d’ajuster l’intensité de vibration

    — Vibration (moteurs) : Le soulagement est assuré par des moteurs vibrants de type ERM, basés sur le même
    principe que la vibration d’un téléphone cellulaire. Cette technologie est compacte et simple à intégrer.
    Un point technique majeur concerne la transmission de la vibration jusqu’à la peau. Le module est entouré
    d’une enveloppe en silicone souple ; or, un matériau souple absorbe une partie des vibrations des moteurs, ce
    qui peut diminuer la sensation ressentie par le patient. Pour éviter cette perte, une plaque interne semi-rigide est
    ajoutée du côté en contact avec le vêtement compressif. Les moteurs vibrent contre cette plaque, qui sert de surface
    de transfert et transmet plus efficacement la vibration au vêtement puis à la peau, afin de conserver l’efficacité sur
    la zone ciblée.‘
    L’alimentation a été pensée pour minimiser la charge sur les zones sensibles et s’adapter aux scénarios d’usage.
    Pour des zones restreintes (comme un module placé sur un membre), une seule batterie compacte peut être intégrée
    localement. À l’inverse, pour un module dorsal plus étendu ou pour une utilisation multi-zones, une batterie de plus
    grande capacité peut être portée à la ceinture. L’énergie est alors distribuée par des câbles plats fins, afin de déporter
    la masse et éviter d’ajouter du poids ou des points de pression au niveau du dos.
    Enfin, l’architecture connectée laisse la possibilité d’intégrer ultérieurement des fonctions supplémentaires ( comme
    l’intégration de capteurs inertiels ou de mécanismes de biofeedback ), afin d’étendre l’usage du dispositif au-delà du
    soulagement, vers un support plus large de réadaptation.

    maintenant que tu as le contexte on va devoir concevoir une application, elle comporterait :

    Login screen pour eviter que n'importe qui puisse se connecter a notre wearable connectée. Pour le moment on reste sur un mdp simple mais a terme il faudra pouvoir le relier a une vraie database en ligne type et pouvoir se creer des comptes.

    Ensuite,v une fois logger, alors pas forcement dans cette ordre, il faudra reorganiser mais il faut :
    (tu dois absolument trouver les meilleures idées et pas uniquement te baser sur ce que je te suggere, ca se trouve mes idées ne sont pas bien)

    une home page
    un dashboard ?
    une page de setting classique comme nimporte quelle application
    une page ou l'on peut regler les vibrations
    une page ou l'on peut sequencer, programmer, s'entrainer a se reduquer en generant des vibrations genre le patient appuie sur un endroit du dos virtuel que le voit sur le telephone et l'appli envoie une vibration a cette endroit c'est comme un biofeedback qui permet au patient de verifier qu'il sente bien la vibration a l'endroit souhaité.

    Aussi tres important, dans notre cas on se concentre sur le dos, mais l'application a vocation a pouvoir tout gerer les modules des bras, avant bras, jambes, mollet. Donc reflechi deja a une solution d'application globale meme si apres on se concetre que sur la section dorsale.

    On doit pouvoir regler comme on veut. personnalisable. On doit pouvoir se connecter au dispositif en bluetooth, si c'est la premiere fois on appaire mais sinon on tente de se connecter directement.

    J'ai besoin que tu m'aides a penser au reste car je n'ai clairement pas pensé a tout.

    Restructure moi tout ce que je viens de dire, propose des idées. Agis comme un expert dans le domaine.

NOTE A FAIRE :

-Login screen, quand on valide et que les champs sont vide ou incorrecte, les contours des boites de email et mot de passe sont bien en rouge mais les boites changent de taille, hors je veux que ce soit fixe. c'est du au fait que le texte apparait en dessous pour dire a l'utilisateur quoi faire. On pourrait mettre le texte dedans ?

- pour le mot de passe oublié, ajouter un padding a gauche et droite du rectangle arrondi qui apparait en surbrillance quand on clique dessus
- Pour s'inscrire, ajouter le meme effet quand on appuie dessus (une surbrillance qui montre quon a appuyer comme pour mdp oublié)
- De facon générale, je veux que peut importe le telephone, l'application garde les memes proportions ou du moins s'ajuste correctement pour pas que ca casse le design

Faiit jusque ici

- Si je me connecte sur mon telephone, garder en memoire ma connexion pour les prochaines fois, que je ne dois pas me reconnecter a chaque fois, sauf si je clique sur me deconnecter (diffrents du bouton quitter application a ajuster)
- RELIEF ET THERAPIE NE SONT PAS LES BONS TERMES, JE LES CHANGERAI PLUS TARD
