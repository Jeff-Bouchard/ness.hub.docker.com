# Réseau Privateness – Dépôts Docker Hub

Images Docker prêtes pour la production, conçues pour des environnements hostiles (Umbrel, bare metal, clusters).
Vous ne déployez pas une « app », vous déployez un composant d’infrastructure de sécurité.

[English](README.md)

## Comportement de sécurité (profil expérimental)

Ce projet propose un profil où certains traitements cryptographiques **préfèrent bloquer** plutôt que de continuer si l’entropie semble insuffisante. C’est un choix de conception volontaire, destiné aux environnements qui acceptent de sacrifier de la disponibilité pour renforcer la gestion de l’aléa.

Sur des hôtes Linux correctement configurés, le service `pyuheprng` alimente `/dev/random` avec un mélange contrôlé de sources :

- **RC4OK depuis Emercoin Core** (aléa dérivé de la blockchain)
- **Bits matériels bruts** (entropie matérielle directe)
- **Protocole UHEP** (Universal Hardware Entropy Protocol)

Pour ce profil, la configuration GRUB désactive la confiance explicite dans `/dev/urandom` pour la cryptographie et privilégie `/dev/random`. Il s’agit d’une politique **plus conservatrice que la pratique Linux standard**, à évaluer selon vos besoins ; ce n’est pas un jugement global sur `/dev/urandom`.

Voir [CRYPTOGRAPHIC-SECURITY-FR.md](CRYPTOGRAPHIC-SECURITY-FR.md) et `SOURCES.md` pour tous les détails et références externes.

## Équivalence binaire (objectif de conception)

L’équivalence binaire est traitée comme un **objectif important** pour les déploiements réellement décentralisés : chaque nœud devrait pouvoir vérifier qu’il exécute le même binaire que ses pairs.

Sans builds reproductibles et sans comparaison de hash, il devient plus difficile de :

- Vérifier l’intégrité des nœuds
- Détecter des binaires compromis ou modifiés
- Avoir confiance dans le comportement global du réseau

Voir [REPRODUCIBLE-BUILDS-FR.md](REPRODUCIBLE-BUILDS-FR.md) pour les profils de build de référence et les idées de vérification.

### Principe de conception – Sun Tzu

> The art of war teaches us to rely not on the likelihood of the enemy's not coming,
> but on our own readiness to receive him; not on the chance of his not attacking,
> but rather on the fact that we have made our position unassailable.

Ce projet applique ce principe : on ne parie pas sur l’absence d’attaquant ; on construit une position opérationnelle difficile à attaquer, même quand l’adversaire sait que vous existez.

## Documentation

### Documentation cœur

- **[SERVICES-FR.md](SERVICES-FR.md)** – Liste complète des services, dépendances, ports, cas d’usage
- **[DEPLOY-FR.md](DEPLOY-FR.md)** – Instructions de déploiement Docker Hub (nessnetwork)
- **[PORTAINER-FR.md](PORTAINER-FR.md)** – Guide de déploiement Portainer, gestion de stack

### Architecture de sécurité

- **[CRYPTOGRAPHIC-SECURITY-FR.md](CRYPTOGRAPHIC-SECURITY-FR.md)** – Architecture d’entropie, pyuheprng, configuration GRUB
- **[REPRODUCIBLE-BUILDS-FR.md](REPRODUCIBLE-BUILDS-FR.md)** – Équivalence binaire, builds déterministes, vérification
- **[INCENTIVE-SECURITY-FR.md](INCENTIVE-SECURITY-FR.md)** – Paiements sans confiance à des nœuds hostiles, théorie des jeux

### Architecture réseau

- **[NETWORK-ARCHITECTURE-FR.md](NETWORK-ARCHITECTURE-FR.md)** – Hopping de protocoles, routage MPLS, intraçabilité
- **[ARCHITECTURE-FR.md](ARCHITECTURE-FR.md)** – Détails de build multi‑architecture

### Documentation par service

- **[ipfs/README-FR.md](ipfs/README-FR.md)** – Démon IPFS, intégration Emercoin
- **[pyuheprng/README-FR.md](pyuheprng/README-FR.md)** – Documentation du service d’entropie
- **[amneziawg/README-FR.md](amneziawg/README-FR.md)** – Configuration du VPN furtif
- **[skywire-amneziawg/README-FR.md](skywire-amneziawg/README-FR.md)** – Intégration couche d’accès
- **[CONCEPT-FR.md](CONCEPT-FR.md)** – Notes conceptuelles perception/réalité

## Concept Perception → Réalité

1. **EmerDNS + EmerNVS** (`dpo:PrivateNESS.Network`, `ness:dns-reverse-proxy-config`) sont les seules sources de vérité pour les identités, le bootstrap, la politique DNS et les URL de services. Tout ce qui n’est pas atteignable depuis ces enregistrements est traité comme non fiable par défaut.
2. **L’application DNS** est assurée par `dns-reverse-proxy` sur `127.0.0.1:53/udp`, qui utilise EmerDNS (127.0.0.1:5335) pour les TLD possédés et, en option, ne relaie les autres TLD que via des serveurs amont de confiance.
3. **Le "commutateur d’existence" clearnet** inverse ou restaure l’accès aux TLD non‑Emer ; OFF signifie que les noms inconnus sont NXDOMAIN / mis en trou noir et que le nœud ne perçoit qu’EmerDNS, ON ajoute des redirecteurs clearnet contrôlés.
4. **Graphe de transport** : WG‑in → Skywire → Yggdrasil → (i2pd optionnel en mode Ygg‑only) → WG/XRAY‑out → clearnet. Tout le trafic visor‑à‑visor reste sur Ygg ; i2p optionnel tourne strictement dans le mode Ygg‑only.
5. **Pipeline identité → config** : un orchestrateur externe lit les entrées Emercoin, dérive `wg.conf`, `xray config.json`, la config Skywire/Ygg, la politique DNS, et écrit tout cela dans chaque conteneur, qui ne contacte jamais directement une infrastructure non fiable.
6. **Les sorties Amnezia** sont les seules surfaces visibles clearnet. La nouvelle image `amnezia-exit` construit `amnezia-xray-core`, installe `amneziawg-tools` et attend `wg.conf` + `config.json` dérivés de ces identités EmerDNS.

## Images

## Ports Cœur Canoniques

- `emercoin-core` :
  - `6661/TCP` = P2P
  - `6662/TCP` = JSON-RPC
- `privateness` :
  - `6006/TCP` = P2P
  - `6660/TCP` = JSON-RPC

### 1. emercoin-core

Nœud blockchain Emercoin.

```bash
docker build -t nessnetwork/emercoin-core ./emercoin-core
docker run -v emercoin-data:/data -p 6661:6661 nessnetwork/emercoin-core
```

### 2. ness-blockchain

**Blockchain native Privateness** (github.com/ness-network/ness)

```bash
docker build -t nessnetwork/ness-blockchain ./ness-blockchain
docker run -v ness-data:/data/ness -p 6006:6006 -p 6660:6660 nessnetwork/ness-blockchain
```

Architecture double‑chaîne avec Emercoin pour une sécurité renforcée.

### 3. privateness

Cœur du réseau Privateness.

```bash
docker build -t ness-network/privateness ./privateness
docker run -p 6006:6006 -p 6660:6660 ness-network/privateness
```

### 3. skywire

Mesh network Skycoin Skywire.

```bash
docker build -t ness-network/skywire ./skywire
docker run -p 8000:8000 ness-network/skywire
```

### 4. pyuheprng

**Service d’entropie cryptographique** – alimente `/dev/random` avec RC4OK + matériel + UHEP.

```bash
docker build -t ness-network/pyuheprng ./pyuheprng
docker run --privileged --device /dev/random -v /dev:/dev \
  -p 5000:5000 \
  -e EMERCOIN_HOST=emercoin-core \
  -e EMERCOIN_PORT=6662 \
  ness-network/pyuheprng
```

**CRITIQUE** : nécessite le mode privilégié pour alimenter `/dev/random` directement. Ce service **élimine la privation d’entropie** et garantit que toutes les opérations cryptographiques utilisent un aléa sûr.

### 5. privatenumer

Service de génération de nombres privés.

```bash
docker build -t ness-network/privatenumer ./privatenumer
docker run -p 3000:3000 ness-network/privatenumer
```

### 6. privatenesstools

Outils du réseau Privateness.

```bash
docker build -t ness-network/privatenesstools ./privatenesstools
docker run -p 8888:8888 ness-network/privatenesstools
```

### 7. yggdrasil

Réseau maillé Yggdrasil.

```bash
docker build -t ness-network/yggdrasil ./yggdrasil
docker run -p 9001:9001 ness-network/yggdrasil
```

### 8. i2p-yggdrasil

Routage I2P au travers du mesh Yggdrasil (IPv6).

```bash
docker build -t ness-network/i2p-yggdrasil ./i2p-yggdrasil
docker run --cap-add=NET_ADMIN --device /dev/net/tun \
  -p 7657:7657 -p 4444:4444 -p 6668:6668 -p 9001:9001 -p 9002:9002 \
  ness-network/i2p-yggdrasil
```

### 9. dns-reverse-proxy

Reverse proxy DNS.

```bash
docker build -t ness-network/dns-reverse-proxy ./dns-reverse-proxy
docker run -p 53:53/udp -p 53:53/tcp -p 8053:8053 ness-network/dns-reverse-proxy
```

### 10. ipfs

**Démon IPFS** – stockage distribué adressé par contenu.

```bash
docker build -t nessnetwork/ipfs ./ipfs
docker run -d \
  -v ipfs-data:/data/ipfs \
  -p 4001:4001 -p 5001:5001 -p 8082:8080 -p 8081:8081 \
  nessnetwork/ipfs
```

S’intègre avec Emercoin pour un nommage décentralisé (hashes IPFS stockés dans la blockchain).

### 11. amneziawg

AmneziaWG (WireGuard furtif avec obfuscation).

```bash
docker build -t nessnetwork/amneziawg ./amneziawg
docker run --cap-add=NET_ADMIN --cap-add=SYS_MODULE --device /dev/net/tun \
  -p 51820:51820/udp -v awg-config:/etc/amneziawg \
  nessnetwork/amneziawg
```

### 12. skywire-amneziawg

**Couche d’accès** : VPN furtif AmneziaWG → routage mesh Skywire.

```bash
docker build -t ness-network/skywire-amneziawg ./skywire-amneziawg
docker run --cap-add=NET_ADMIN --cap-add=SYS_MODULE --device /dev/net/tun \
  -p 8001:8000 -p 51821:51820/udp \
  ness-network/skywire-amneziawg
```

Les clients se connectent via AmneziaWG, le trafic est routé via le mesh Skywire.

### 13. ness-unified

**Tous les services combinés dans un seul conteneur**.

```bash
docker build -t ness-network/ness-unified ./ness-unified
docker run -v ness-data:/data \
  -p 6661:6661 -p 6662:6662 -p 8775:8775 \
  -p 6006:6006 -p 6660:6660 \
  -p 9001:9001 -p 7657:7657 -p 4444:4444 -p 6668:6668 \
  -p 8000:8000 -p 53:53/udp -p 53:53/tcp -p 8053:8053 \
  -p 5000:5000 -p 3000:3000 -p 8888:8888 \
  ness-network/ness-unified
```

## Options de déploiement

### Portainer (recommandé pour la production)

```bash
# Déploiement via l’interface Portainer
# Stacks → Add Stack → Upload portainer-stack.yml
```

Voir [PORTAINER-FR.md](PORTAINER-FR.md) pour le guide complet.

### Déploiement rapide – stack essentielle Ness

**Stack minimale prête pour la production** (recommandée pour Pi4 et appareils limités) :

```bash
./deploy-ness.sh
```

Cette commande déploie :

- **Emercoin Core** : blockchain + source d’entropie RC4OK
- **pyuheprng + privatenesstools** : entropie + outils combinés (gain de ressources)
- **DNS Reverse Proxy** : DNS décentralisé
- **Privateness** : application centrale

Ou manuellement :

```bash
docker-compose -f docker-compose.ness.yml up -d
```

### Docker Compose

#### Stack complète avec dépendances

```bash
docker-compose up -d
```

#### Stack minimale (services cœur seulement)

```bash
docker-compose -f docker-compose.minimal.yml up -d
```

### Ordre de démarrage des services

1. **emercoin-core** (démarre en premier, healthcheck requis)
2. **yggdrasil** (attend emercoin)
3. **dns-reverse-proxy** (attend emercoin + yggdrasil)
4. **skywire** (attend emercoin)
5. **pyuheprng** (attend emercoin)
6. **ipfs** (indépendant, peut démarrer à tout moment)
7. **i2p-yggdrasil** (attend yggdrasil)
8. **privatenumer** (attend pyuheprng)
9. **privateness** (attend emercoin + yggdrasil + dns)
10. **privatenesstools** (attend privateness + emercoin)

## Vue d’ensemble de l’architecture réseau

Voir [NETWORK-ARCHITECTURE-FR.md](NETWORK-ARCHITECTURE-FR.md) pour une description détaillée. À haut niveau, un flux typique peut ressembler à :

`AmneziaWG (obfusqué) → Skywire (MPLS) → Yggdrasil (IPv6) → I2P (garlic) → DNS blockchain`.

Quelques points de design :

- **Pas de routage IP dans le cœur** : Skywire utilise la commutation de labels MPLS dans le mesh.
- **Plusieurs couches de chiffrement** : chaque protocole apporte son propre chiffrement.
- **Sélection de chemin dynamique** : les routes peuvent changer par paquet.

L’objectif est d’**augmenter l’effort nécessaire** pour une analyse de trafic à grande échelle et pour un blocage simple, sans revendiquer une intraçabilité mathématiquement démontrée.

## Support multi‑architecture

Toutes les images supportent :

- **linux/amd64** (x86_64)
- **linux/arm64** (aarch64)
- **linux/arm/v7** (armhf)

### Construire des images multi‑arch

```bash
./build-multiarch.sh
```

## Push vers Docker Hub

### Architecture unique

```bash
docker login
./build-all.sh
./push-all.sh
```

Pour rejouer un enregistrement complet de l’exécution de `./build-all.sh`, utilisez le cast asciinema présent dans ce répertoire :

```bash
asciinema play build-all.cast
```

### Multi‑architecture (recommandé)

```bash
docker login
./build-multiarch.sh
```
