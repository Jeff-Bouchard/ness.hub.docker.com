# NESS Network Guide de Démarrage Rapide - Version Québécoise

Mettez en place un nœud maille axé sur la confidentialité en quelques minutes, pas des heures.

**Dernière vérification**: 7 mars 2026  
**Version NESS**: v0.5.0  
**Responsable**: Jeff Bouchard (https://github.com/Jeff-Bouchard/)

---

## TL;DR (Résumé en 1 minute)

```bash
# Cloner le dépôt
git clone https://github.com/Jeff-Bouchard/ness.hub.docker.com.git
cd ness.hub.docker.com

# Copier le gabarit de configuration
cp .env.example .env

# Déployer la pile minimale (Emercoin + proxy DNS inversé)
docker compose -f docker-compose.minimal.yml up -d

# Vérifier les services en cours d'exécution
docker ps
```

**Ce qui s'exécute**: Synchronisation de la chaîne de blocs Emercoin + résolveur DNS privé + chaîne de blocs centrale Privateness

---

## Choisissez Votre Profil de Déploiement

### Profil 1: Minimal (2 GB disque, ~512 MB RAM)
**Idéal pour**: Tests, appareils avec ressources limitées (Raspberry Pi 3+), preuve de concept

```bash
docker compose -f docker-compose.minimal.yml up -d
```

**Services réels**:
- `emercoin-core` — Nœud de chaîne de blocs Emercoin avec ancrage AuxPoW à Bitcoin
  - Port 6661/TCP: Protocole P2P (pair-à-pair)
  - Port 6662/TCP: API JSON-RPC (authentification par cookie)
- `yggdrasil` — Réseau maille Yggdrasil IPv6
  - Port 9001/UDP: Protocole maille
- `privateness` — Implémentation de la chaîne de blocs NESS (dérivée de Skycoin)
  - Port 6006/TCP: Protocole P2P
  - Port 6660/TCP: API JSON-RPC

**Vérifier**:
```bash
docker compose -f docker-compose.minimal.yml ps
docker logs emercoin-core              # Vérifier la synchro Emercoin
docker logs privateness                # Vérifier le statut Privateness
```

**Arrêter** (les données persistent):
```bash
docker compose -f docker-compose.minimal.yml down
```

---

### Profil 2: NESS Essentiel (5 GB disque, ~1,5 GB RAM) — **RECOMMANDÉ**
**Idéal pour**: Nœuds en production, confidentialité des fichiers, DNS décentralisé, contrôle d'entropie

Inclut tous les éléments du Minimal, plus:

- `pyuheprng-privatenesstools` — PRNG ultra-haute entropie + outils cryptographiques
  - Port 5000/TCP: API HTTP du service d'entropie (/health, /rate, /sources)
  - Port 8888/TCP: API des outils CLI Privateness
  - **Fait**: Alimente directement `/dev/random` avec RC4OK (Emercoin) + entropie matérielle + UHEPRNG (Gibson)
- `dns-reverse-proxy` — Résolveur DNS décentralisé sur Emercoin NVS
  - Port 53/UDP+TCP: Résolveur DNS (port hôte par défaut 1053)
  - Port 8053/TCP: API HTTP de contrôle/métriques
  - **Fait**: Utilise EmerDNS pour les entrées WORM-schema DNS; mode hybride se replie sur Cloudflare/Google DNS
- `ipfs` — Démon du système de fichiers InterPlanétaire
  - Port 4001/TCP: Essaim P2P
  - Port 5001/TCP: API
  - Port 8080/TCP: Passerelle (lecture publique, pas d'écriture)

```bash
docker compose -f docker-compose.ness.yml up -d
```

**Vérifier les services Essentiel**:
```bash
docker compose -f docker-compose.ness.yml ps
docker logs -f pyuheprng-privatenesstools      # Surveiller l'entropie
docker exec pyuheprng-privatenesstools curl http://127.0.0.1:5000/health
docker exec dns-reverse-proxy curl http://127.0.0.1:8053/api/status
```

**Arrêter**:
```bash
docker compose -f docker-compose.ness.yml down
```

---

### Profil 3: Réseau Complet (15 GB disque, 4+ GB RAM)
**Idéal pour**: Recherche, opérateur maille complet, test multi-protocole

Inclut tous les éléments de Essentiel, plus:

- `i2p-yggdrasil` — Protocole Internet Invisible (I2P) sur maille Yggdrasil
  - Port 7657/TCP: Console Web I2P
  - Port 4444/TCP: Proxy HTTP (via I2P)
  - Port 6668/TCP: Tunnel IRC
  - **Fait**: I2P s'exécute en mode "Yggdrasil uniquement" (pas de clearnet)
- `skywire` — Viseur maille Skycoin (routage MPLS basé sur étiquettes)
  - Port 8000/TCP: Interface utilisateur de gestion du viseur
  - **Fait**: Utilise le modèle d'incitation de disponibilité 100% de Skycoin
- `amneziawg` — VPN caché SoftEther (WireGuard avec obfuscation)
  - Port 443/UDP: Point de terminaison VPN

```bash
docker compose -f docker-compose.yml up -d
```

**Vérifier tous les services**:
```bash
docker compose ps
docker compose logs -f
```

**Arrêter**:
```bash
docker compose down
```

---

## Opérations Courantes

### Surveiller Tous les Services (Temps Réel)
```bash
# Journaux globaux (tous les conteneurs)
docker compose logs -f

# Journaux d'un seul service
docker compose logs -f emercoin-core
docker compose logs -f pyuheprng-privatenesstools
docker compose logs -f dns-reverse-proxy
docker compose logs -f yggdrasil
```

### Vérifier la Santé du Service
```bash
# Statut Docker
docker ps

# Connectivité réseau
docker network inspect ness-network

# Inspection de conteneur individuel
docker inspect emercoin-core | grep -A 10 '"Networks"'
docker inspect privateness | grep IPAddress
```

### Redémarrer les Services Individuels
```bash
docker compose restart emercoin-core
docker compose restart privateness
docker compose restart pyuheprng-privatenesstools
docker compose restart dns-reverse-proxy
```

### Construire des Images Localement (à partir de la source)
```bash
# Image unique
docker build -t nessnetwork/emercoin-core:latest ./emercoin-core
docker compose up -d emercoin-core

# Toutes les images (voir build-all.sh)
bash build-all.sh
```

### Exécuter les Outils CLI à l'Intérieur des Conteneurs
```bash
# Statut de la chaîne de blocs Privateness
docker exec privateness privateness-cli status

# Info de la chaîne de blocs Emercoin
docker exec emercoin-core emercoin-cli -datadir=/data getblockchaininfo

# Statistiques d'entropie pyuheprng
docker exec pyuheprng-privatenesstools curl http://127.0.0.1:5000/status

# Vérification de santé du proxy DNS
docker exec dns-reverse-proxy curl http://127.0.0.1:8053/api/health
```

### Données Persistantes (Volumes)
Les données persistent automatiquement entre les redémarrages de conteneurs:
- `emercoin-data` — Chaîne de blocs Emercoin (~1-2 GB, croît avec la chaîne d'ancrage AuxPoW Bitcoin)
- `ipfs-data` — Contenu stocké IPFS (~0-50 GB, configurable)
- `yggdrasil-data` — État du nœud Yggdrasil (~10 MB)
- `i2p-data` — Base de données du routeur I2P (~100 MB)

**Sauvegarde manuelle**:
```bash
docker run --rm -v emercoin-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/emercoin-backup.tar.gz -C /data .
```

---

## Cartographie des Ports (Vérifiée)

### Ports de la Pile Minimal
| Service | Port Hôte | Port Conteneur | Protocole | Utilisation |
|---------|-----------|----------------|-----------|------------|
| emercoin-core | 6661 | 6661 | TCP | Protocole pair P2P (AuxPoW) |
| emercoin-core | 6662 | 6662 | TCP | API JSON-RPC (auth par cookie) |
| yggdrasil | 9001 | 9001 | UDP | Protocole maille Yggdrasil (IPv6) |
| privateness | 6006 | 6006 | TCP | Protocole P2P (basé Skycoin) |
| privateness | 6660 | 6660 | TCP | API JSON-RPC |

### Ports Supplémentaires NESS Essentiel
| Service | Port Hôte | Port Conteneur | Protocole | Utilisation |
|---------|-----------|----------------|-----------|------------|
| pyuheprng | 5000 | 5000 | TCP | Service d'entropie HTTP (/health, /rate, /sources) |
| privatenesstools | 8888 | 8888 | TCP | API des outils CLI Privateness |
| dns-reverse-proxy | 1053 | 53 | UDP | Résolveur DNS (port hôte par défaut 1053) |
| dns-reverse-proxy | 1053 | 53 | TCP | Résolveur DNS (secours TCP) |
| dns-reverse-proxy | 8053 | 8053 | TCP | API HTTP de contrôle DNS |
| ipfs | 4001 | 4001 | TCP | Essaim P2P IPFS |
| ipfs | 5001 | 5001 | TCP | API HTTP IPFS (accès administrateur) |
| ipfs | 8080 | 8080 | TCP | Passerelle IPFS (lecture publique) |

### Ports Supplémentaires Réseau Complet
| Service | Port Hôte | Port Conteneur | Protocole | Utilisation |
|---------|-----------|----------------|-----------|------------|
| i2p-yggdrasil | 7657 | 7657 | TCP | Console Web I2P (routeur/tunnels) |
| i2p-yggdrasil | 4444 | 4444 | TCP | Proxy HTTP I2P |
| skywire | 8000 | 8000 | TCP | Interface utilisateur de gestion du viseur Skywire |
| amneziawg | 443 | 443 | UDP | Point de terminaison VPN SoftEther |

**Personnaliser les ports** dans `.env`:
```bash
EMERCOIN_PORT_RPC=6662
PRIVATENESS_PORT_RPC=6660
DNS_PORT_UDP=53
YGGDRASIL_PORT=9001
SKYWIRE_PORT=8000
PYUHEPRNG_PORT=5000
```

Après modification de `.env`:
```bash
docker compose down
docker compose up -d
```

---

## Dépannage (Basé sur les Faits)

### Le Conteneur s'Arrête Immédiatement
```bash
docker logs <nom-du-conteneur>
```
**Causes courantes**:
- Fichier `.env` manquant → Copier `.env.example` vers `.env`
- Conflit de port → Modifier le port dans `.env`
- Espace disque insuffisant → `docker system df`
- Réseau manquant → Réexécuter `docker compose up -d`

### Le Port est Déjà en Utilisation
```bash
# Linux/macOS
lsof -i :6661

# Windows
Get-NetTCPConnection -LocalPort 6661 | select ProcessName

# Solution: Modifier le port dans .env ou arrêter le processus en conflit
```

### Espace Disque Insuffisant
```bash
docker system df              # Afficher l'utilisation
docker system prune -a        # Supprimer les images/conteneurs inutilisés
docker volume prune           # Supprimer les volumes inutilisés
docker volume rm emercoin-data # Supprimer un volume spécifique (ATTENTION: perte de données)
```

### Utilisation Élevée de la Mémoire
```bash
docker stats                  # Utilisation des ressources en temps réel

# Définir les limites dans docker-compose.yml:
services:
  emercoin-core:
    mem_limit: 2g            # Max 2 GB
    memswap_limit: 2g        # Pas de swap au-delà de la limite
```

### Le Conteneur Redémarre Continuellement
```bash
docker inspect <nom-du-conteneur> | grep -A 5 '"State"'  # Vérifier le code de sortie
docker logs <nom-du-conteneur> --tail 100                  # Dernières 100 lignes
```

---

## Notes de Sécurité (Vérifiées)

### Isolation Réseau
- Tous les conteneurs s'exécutent sur un réseau maille isolé: `ness-network`
- Pas d'accès direct à Internet (sauf exposition explicite via cartographie de port)
- Le trafic entre les conteneurs est chiffré par les protocoles de superposition (Yggdrasil, Skywire, etc.)

### Authentification
- **RPC Emercoin**: Utilise l'authentification par cookie (`/data/.cookie`), inaccessible au navigateur
- **API IPFS (port 5001)**: Pas d'authentification par défaut → **Restreindre à localhost uniquement**
- **Proxy DNS (port 8053)**: Pas d'authentification → **Restreindre à localhost**

### Conteneurs Privilégiés
Seul `pyuheprng-privatenesstools` s'exécute en mode privilégié (accès `/dev/random` requis):
```bash
docker inspect pyuheprng-privatenesstools | grep Privileged
```

Tous les autres s'exécutent sans privilèges.

### Propriété des Données
Les fichiers dans les volumes sont la propriété du UID du conteneur (généralement UID 1000 pour l'utilisateur `ness`):
```bash
docker run --rm -v emercoin-data:/data alpine ls -la /data
```

### Modifier les Identifiants RPC
```bash
# Modifier .env
EMERCOIN_USER=nouvelutilisateur
EMERCOIN_PASS=$(openssl rand -base64 32)
PRIVATENESS_USER=nouvelutilisateur
PRIVATENESS_PASS=$(openssl rand -base64 32)

# Redémarrer
docker compose down
docker compose up -d
```

---

## Référence des Variables d'Environnement

```bash
# Configuration de la Chaîne de Blocs
EMERCOIN_PORT_P2P=6661              # Port de protocole pair-à-pair
EMERCOIN_PORT_RPC=6662              # Port API JSON-RPC
EMERCOIN_USER=rpcuser               # Nom d'utilisateur d'authentification RPC
EMERCOIN_PASS=rpcpassword           # Mot de passe d'authentification RPC

# Réseaux Maille
YGGDRASIL_PORT=9001                 # Port UDP Yggdrasil
SKYWIRE_PORT=8000                   # Port viseur Skywire

# Services de Confidentialité
PRIVATENESS_PORT_P2P=6006           # Port P2P Privateness
PRIVATENESS_PORT_RPC=6660           # Port RPC Privateness
PYUHEPRNG_PORT=5000                 # Port service d'entropie
PRIVATENESSTOOLS_PORT=8888          # Port API d'outils

# Configuration DNS
DNS_PORT_UDP=53                      # Écouteur DNS UDP
DNS_PORT_TCP=53                      # Écouteur DNS TCP
DNS_API_PORT=8053                    # Port de contrôle HTTP DNS

# Limites de Ressources (Optionnel)
EMERCOIN_MEM_LIMIT=2g               # Mémoire max Emercoin
YGGDRASIL_MEM_LIMIT=512m            # Mémoire max Yggdrasil
```

Redémarrer après modifications:
```bash
docker compose down
docker compose up -d
```

---

## Prochaines Étapes

1. **Exécuter le Panneau de Contrôle**:
   ```bash
   bash nessv0.5.sh
   ```
   Menu complet pour: profils, modes DNS, contrôle de service, vérifications de santé, tests

2. **Ouvrir le Tableau de Bord Web**:
   ```bash
   http://localhost:6662/ness-dashboard-v0.5.0.html
   ```
   Surveillance du service en temps réel

3. **Lire la Documentation Technique**:
   - [SERVICES.md](./doc/SERVICES.md) — Chaque service en détail
   - [NETWORK-ARCHITECTURE.md](./doc/NETWORK-ARCHITECTURE.md) — Flux du trafic
   - [CRYPTOGRAPHIC-SECURITY.md](./doc/CRYPTOGRAPHIC-SECURITY.md) — Fondations de sécurité (OWF + EmerNVS)

4. **Rejoindre la Maille**:
   - Skywire: Partager votre clé publique du viseur avec les pairs
   - Yggdrasil: Nœud automatiquement découvrable par adresse IPv6
   - I2P: Identité du routeur persistée dans `/var/lib/i2p/router.info`

5. **Utiliser PrivatenessTools**:
   ```bash
   docker exec pyuheprng-privatenesstools privateness-cli --help
   # Chiffrer les fichiers → IPFS → Sauvegarde décentralisée
   ```

---

## Obtenir de l'Aide

- **Problèmes GitHub**: https://github.com/Jeff-Bouchard/ness.hub.docker.com/issues
- **Documentation Réseau NESS**: Voir le répertoire `./doc/`
- **Documentation Docker**: https://docs.docker.com/compose/reference/

---

## Nettoyage et Arrêt

**Arrêt gracieux** (données préservées):
```bash
docker compose down
```

**Arrêt + suppression des volumes** (supprimer toutes les données):
```bash
docker compose down -v
```

**Nettoyage complet** (supprimer aussi les images):
```bash
docker compose down -v --rmi all
```

---

**Bon maillage!**

**Version du document**: 0.5.0-factchecked-fr-ca  
**Dernière mise à jour**: 7 mars 2026  
**Vérifié par**: Jeff Bouchard (responsable NESS)
