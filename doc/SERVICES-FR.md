# Services du réseau Privateness

[English](SERVICES.md)

Carte opérationnelle de tous les services de la pile privateness.network.
Chaque composant est une brique d’infrastructure de sécurité, avec ports et dépendances explicitement exposés pour les équipes ops/secops.

## Services cœur

### 1. Emercoin Core

#### Fondation blockchain

- Nommage décentralisé (NVS)
- Source d’entropie RC4OK
- Découverte de services
- Ports : 6661 (P2P), 6662 (JSON-RPC)
- Point d’ancrage de confiance pour tout le réseau

### 2. Privateness

#### Application cœur

- Coordination réseau
- Gestion des services
- Ports : 6006 (P2P), 6660 (JSON-RPC)

### 3. DNS Reverse Proxy

#### DNS décentralisé

- Résolution via Emercoin NVS
- Repli éventuel sur DNS traditionnel
- Ports : 53 (UDP/TCP), 8053 (HTTP)

## Sécurité cryptographique

### 4. pyuheprng

#### Génération d’entropie

- Alimente directement `/dev/random`
- Sources : RC4OK + matériel + UHEP
- Élimine la privation d’entropie
- Port : 5000
- Verrouille toute la cryptographie de la pile sur une entropie forte

### 5. pyuheprng-privatenesstools (combiné)

#### Entropie + outils

- pyuheprng (port 5000)
- privatenesstools (port 8888)
- Combinaison économe en ressources

## Réseaux maillés

### 6. Skywire

#### Routage MPLS en mesh

- Routage décentralisé
- Sélection multi‑chemins
- Aucun routage IP au cœur du réseau
- Port : 8000

### 7. Yggdrasil

#### Surcouche mesh IPv6

- Réseau maillé chiffré
- Routage basé DHT
- Chiffrement de bout en bout
- Port : 9001

### 8. I2P (mode Yggdrasil)

#### Réseau anonyme

- Routage "garlic"
- Routage à travers Yggdrasil
- Chiffrement en couches
- Ports : 7657 (HTTP), 4444 (SOCKS), 6668 (IRC)
- Complète la chaîne de transport intraçable

## Couche d’accès

### 9. AmneziaWG

#### VPN furtif

- WireGuard obfusqué
- Contournement de la DPI
- VPN indétectable
- Port : 51820 (UDP)

### 10. Skywire-AmneziaWG

#### Intégration accès → mesh

- Couche d’accès AmneziaWG
- Routage vers le mesh Skywire
- Pile de confidentialité complète
- Ports : 8001 (Skywire), 51821 (AmneziaWG)

## Stockage & contenu

### 11. IPFS

#### Stockage décentralisé

- Fichiers adressés par contenu
- Distribution pair à pair
- Intégration avec Emercoin NVS
- Ports : 4001 (P2P), 5001 (API), 8080 (gateway), 8081 (WebUI)

## Services utilitaires

### 12. privatenumer

#### Génération de nombres privés

- Nombres aléatoires sécurisés
- Utilise l’entropie de pyuheprng
- Port : 3000

### 13. privatenesstools

#### Utilitaires réseau

- Outils de gestion
- Diagnostics réseau
- Port : 8888

## Tout‑en‑un

### 14. ness-unified

#### Pile complète dans un conteneur

- Tous les services combinés
- Pour déploiement mono‑nœud
- Tous les ports exposés

## Dépendances entre services

```text
emercoin-core (fondation)
    ├─ yggdrasil
    │   └─ i2p-yggdrasil
    ├─ dns-reverse-proxy
    ├─ skywire
    ├─ pyuheprng
    │   ├─ privatenumer
    │   └─ privatenesstools
    └─ privateness
        └─ privatenesstools

ipfs (indépendant)
amneziawg (indépendant)
skywire-amneziawg (indépendant)
```

## Récapitulatif des ports

| Service | Ports | Protocole |
|---------|-------|----------|
| emercoin-core | 6661, 6662 | TCP |
| privateness | 6006, 6660 | TCP |
| dns-reverse-proxy | 53, 8053 | UDP/TCP, HTTP |
| pyuheprng | 5000 | HTTP |
| privatenumer | 3000 | HTTP |
| privatenesstools | 8888 | HTTP |
| skywire | 8000 | HTTP |
| yggdrasil | 9001 | TCP/UDP |
| i2p-yggdrasil | 7657, 4444, 6668 | HTTP, SOCKS, IRC |
| ipfs | 4001, 5001, 8080, 8081 | P2P, API, gateway, WebUI |
| amneziawg | 51820 | UDP |
| skywire-amneziawg | 8001, 51821 | HTTP, UDP |

## Exigences de ressources

### Pile minimale (Ness Essential)

- **Services** : emercoin-core, pyuheprng-privatenesstools, dns-reverse-proxy, privateness
- **RAM** : ~1,5 Go
- **Disque** : ~10 Go
- **CPU** : 2 cœurs minimum

### Pile complète

- **Services** : les 14 services
- **RAM** : ~4 Go
- **Disque** : ~50 Go (y compris stockage IPFS)
- **CPU** : 4 cœurs recommandés

### Optimisé Pi4

- **Services** : pile minimale + IPFS
- **RAM** : ~2 Go
- **Disque** : ~20 Go
- **CPU** : Raspberry Pi 4 4/8 Go

## Couches d’architecture réseau

### Couche 1 : Accès

- AmneziaWG (entrée VPN furtive)

### Couche 2 : Transport

- Skywire (routage MPLS en mesh)
- Yggdrasil (surcouche mesh IPv6)

### Couche 3 : Réseau

- I2P (routage garlic)
- DNS Reverse Proxy (naming décentralisé)

### Couche 4 : Application

- Privateness (coordination)
- IPFS (stockage)
- Emercoin (blockchain)

### Couche 5 : Sécurité

- pyuheprng (entropie)
- Vérification binaire (builds reproductibles)
- Garanties cryptographiques

## Cas d’usage par combinaison de services

### Navigation privée

```text
Client → AmneziaWG → Skywire → Yggdrasil → I2P → Internet
```

Services nécessaires : amneziawg, skywire, yggdrasil, i2p-yggdrasil

### Hébergement de site web décentralisé

```text
Site web → IPFS → Emercoin NVS (naming) → DNS Proxy → Clients
```

Services nécessaires : ipfs, emercoin-core, dns-reverse-proxy

### Partage de fichiers sécurisé

```text
Fichier → IPFS (stockage) → Emercoin (registre de hash) → Privateness (coordination)
```

Services nécessaires : ipfs, emercoin-core, privateness

### Réseau maillé

```text
Nœud → Skywire (routage) → Yggdrasil (overlay) → Nœuds pairs
```

Services nécessaires : skywire, yggdrasil, emercoin-core

### Pile de confidentialité complète

```text
Tous les services pour une confidentialité et une décentralisation maximales
```

Services nécessaires : les 14 services

## Exemples d’intégration

### IPFS + Emercoin

```bash
# Upload vers IPFS
ipfs add file.txt
# QmXxx...

# Enregistrement dans la blockchain
emercoin-cli name_new "ipfs:myfile" "QmXxx..."

# Résolution via DNS
dig ipfs.myfile.emc TXT
```

### Skywire + AmneziaWG

```bash
# Le client se connecte via AmneziaWG
# Le trafic est automatiquement routé dans le mesh Skywire
# Sortie via des nœuds du mesh décentralisé
```

### I2P + Yggdrasil

```bash
# Le trafic I2P passe dans le mesh IPv6 Yggdrasil
# Double chiffrement : garlic I2P + tunnel Yggdrasil
# Routage intraçable
```

## Supervision de tous les services

```bash
# Vérifier tous les services
docker-compose ps

# Vérifier un service spécifique
docker logs <service-name>

# Checks de santé
curl http://localhost:5000/health  # pyuheprng
curl http://localhost:8053/health  # dns-proxy
curl http://localhost:5001/api/v0/id  # ipfs
```

## Stratégie de sauvegarde

### Données critiques

- Blockchain Emercoin : `/data/emercoin`
- Contenu IPFS : `/data/ipfs`
- Clés Yggdrasil : `/etc/yggdrasil`
- Config AmneziaWG : `/etc/amneziawg`

### Commande de backup

```bash
docker run --rm \
  -v emercoin-data:/emercoin \
  -v ipfs-data:/ipfs \
  -v $(pwd):/backup \
  alpine tar czf /backup/ness-backup.tar.gz /emercoin /ipfs
```

## Considérations de sécurité

### Équivalence binaire

Tous les services doivent utiliser des binaires vérifiés (voir REPRODUCIBLE-BUILDS-FR.md).

Traitez cette matrice de services comme un contrat d’exploitation : si vous déviez des binaires ou des combinaisons décrites ici, vous renoncez à une partie de la position « inattaquable » du réseau.

### Sécurité de l’entropie

pyuheprng doit tourner en mode privilégié (voir CRYPTOGRAPHIC-SECURITY-FR.md).

### Isolation réseau

Les services communiquent via un réseau Docker, isolé de l’hôte.

### Contrôle d’accès

Les labels Portainer permettent un contrôle d’accès par équipe.

## Optimisation des performances

### Nœuds à fort trafic

- Augmenter les limites de connexion Skywire
- Activer le DHT accéléré d’IPFS
- Optimiser le nombre de tunnels I2P

### Appareils contraints en ressources

- Utiliser la pile minimale
- Réduire la limite de stockage IPFS
- Désactiver les services non utilisés

### Déploiement en production

- Activer tous les healthchecks
- Configurer les redémarrages automatiques
- Mettre en place une supervision et des alertes
- Automatiser les sauvegardes

## Liens de documentation

- [CRYPTOGRAPHIC-SECURITY-FR.md](CRYPTOGRAPHIC-SECURITY-FR.md) – Entropie et sécurité
- [REPRODUCIBLE-BUILDS-FR.md](REPRODUCIBLE-BUILDS-FR.md) – Vérification binaire
- [INCENTIVE-SECURITY-FR.md](INCENTIVE-SECURITY-FR.md) – Sécurité économique
- [NETWORK-ARCHITECTURE-FR.md](NETWORK-ARCHITECTURE-FR.md) – Protocol hopping
- [PORTAINER-FR.md](PORTAINER-FR.md) – Guide de déploiement
- [DEPLOY-FR.md](DEPLOY-FR.md) – Déploiement Docker Hub

## Support

Pour la documentation spécifique à chaque service, voir le README.md dans chaque dossier :

- `emercoin-core/README.md`
- `ipfs/README-FR.md`
- `pyuheprng/README-FR.md`
- `amneziawg/README-FR.md`
- etc.
