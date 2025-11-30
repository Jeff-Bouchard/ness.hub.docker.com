# Identity Bedrock: Operationalizing Rompel's Minimal Cryptographic Substrate for Sovereign Identity

**Authors:** [Jeff + co-authors], Emercoin Team, Privateness Network Team

---

## Paper Structure - Single Unified Work

**Target Venue:** ACM CCS (Computer and Communications Security) or USENIX Security  
**Length:** 12-14 pages (standard conference format)  
**Type:** Theory + Systems + Application (three facets, one paper)

---

## Abstract (250 words)

**Structure:**
1. **Theoretical Foundation:** Rompel (1990) proved one-way functions are necessary and sufficient for digital signatures. We operationalize this as the irreducible floor for public authentication.

2. **Design:** Identity Bedrock separates identity cryptography (Ed25519) from directory consensus (chain-agnostic). Any append-only ledger with quantifiable finality can host identity bindings.

3. **Implementation:** Deployed on Emercoin NVS (hybrid PoS + Bitcoin AuxPoW), with NESS Fiber infrastructure. Attack cost inherits from directory choice - Bitcoin anchoring provides $5-20B floor.

4. **Key Property:** No institutional keys beneath the individual. Chain-agnostic design enables directory portability while maintaining OWF-based security.

5. **Contribution:** First practical identity system explicitly grounded in Rompel's theorem, with quantified attack costs and deployed verification.

---

## 1. Introduction (2 pages)

### 1.1 The Problem: Institutional Capture

**Content:**
- Every Digital ID system places institutions beneath users: CAs, IdPs, registries, platforms
- These create capture points - entities that can revoke, deny, or control identity
- Threat model: Adversary with unlimited resources, political backing, full control of traditional identity infrastructure
- **Question:** Can identity exist without institutional keys beneath the individual?

### 1.2 The Theoretical Answer: Rompel 1990

**Content:**
- Rompel proved: OWF ⟺ EUF-CMA signatures (necessary AND sufficient)
- This is the provable minimum - nothing strictly weaker supports public authentication
- **Thesis:** If we fix OWF as the floor and add only an append-only directory, we get identity with no institutional capture point

### 1.3 Contributions

**Three Facets:**

**Facet 1 - Theory:**
- Formalization of Rompel-based identity with chain-agnostic design
- Proof: Removing OWF collapses authentication; weakening directory only trades one consensus for another
- Security model with quantified attack costs

**Facet 2 - Systems:**
- Architecture: Ed25519 identity layer + pluggable directory substrate
- Implementation: Emercoin NVS (Bitcoin-anchored) + NESS Fiber (99% attack-resistant)
- Chain-agnostic: Same identity portable across directories

**Facet 3 - Application:**
- Deployed system operational since 2013 (Emercoin) with public verification
- Attack cost: $5-20B (inherits from Bitcoin via AuxPoW)
- Threat model: Resistance to institutional capture by design

**Why One Paper:**
- Theory justifies the design (Rompel's floor)
- Systems implements the theory (chain-agnostic architecture)
- Application proves it works (deployed, quantifiable costs)
- Inseparable: each facet needs the others

---

## 2. Background and Related Work (2 pages)

### 2.1 Rompel's Theorem (1990)

**Content:**
- Formal statement: OWF exist ⟺ EUF-CMA signature schemes exist
- Proof sketch (cite original paper)
- Implication: OWF is the irreducible minimum for public authentication
- **Gap in literature:** No prior work explicitly uses this as identity system foundation

### 2.2 Blockchain-Based Identity Systems

**Content:**

**Namecoin/EmerDNS:**
- Name-value storage on blockchain
- **Gap:** Identity keys tied to blockchain wallet keys (not chain-agnostic)
- Miners act as implicit certificate authority

**W3C DIDs / Ethereum-based:**
- DID methods, smart contracts, ENS
- **Gap:** DAO governance keys, registry admins, provider dependencies (Infura)
- Often adds institutional keys above or beneath user

**Sovrin/Hyperledger Indy:**
- Permissioned validators, credential schemas
- **Gap:** Steward keys control network, not pure OWF floor

**Identity Bedrock difference:**
- Pure OWF floor (Rompel)
- Chain-agnostic (identity ≠ directory)
- No institutional keys

### 2.3 Bitcoin AuxPoW and Merged Mining

**Content:**
- Auxiliary Proof-of-Work mechanism
- Emercoin as example: 85% PoS + 15% Bitcoin AuxPoW
- Security inheritance: attacking directory requires attacking Bitcoin
- **Novel use:** Non-monetary application (identity) inheriting Bitcoin's $5-20B attack cost

### 2.4 Skycoin Fiber Consensus

**Content:**
- Announced block publisher keys (not economic consensus)
- 99% hostile nodes irrelevant (can't forge without keys)
- Append-only storage (BoltDB)
- **Novel property:** Infrastructure with majority-attack immunity

---

## 3. Threat Model and Requirements (1.5 pages)

### 3.1 Adversary Capabilities

**Assumed:**
- Essentially unlimited conventional resources
- Political backing for legislation, coercion
- Full control of traditional identity infrastructure (CAs, IdPs, KYC)
- Can outlaw software, seize property, compromise individuals

**Not Assumed:**
- Cannot break OWF (computational complexity)
- Cannot attack consensus mechanisms at scale (economically irrational if quantified)
- Cannot compromise distributed infrastructure globally and simultaneously

### 3.2 Design Requirements

**R1: Mathematical Irreducibility**
- Must use OWF as floor (Rompel)
- Cannot add strictly weaker primitive beneath

**R2: No Institutional Keys**
- Individual key is sole root of trust
- No CA, IdP, registry key beneath user

**R3: Chain-Agnostic**
- Identity cryptography independent of directory consensus
- Portable across different append-only substrates

**R4: Quantifiable Security**
- Attack costs must be explicit and measurable
- No hand-waving about "decentralization"

**R5: Operational Verification**
- Deployed, not theoretical
- Public verification of claims

---

## 4. Identity Bedrock Architecture (3 pages)

### 4.1 The Two-Layer Design

**Layer 1: Identity Cryptography (Chain-Agnostic)**

```
Seed (1536-bit UHEPRNG) 
  → Ed25519 KeyGen 
  → (sk, pk)

Identity = (id, pk)
Authentication = Sign_Ed25519(sk, challenge)
```

**Properties:**
- OWF-equivalent security (Rompel)
- Independent of any blockchain
- Portable across directories

**Layer 2: Directory Substrate (Pluggable)**

```
Directory D ⊆ ID × PK
Bind(id, pk) = 1 ⟺ (id, pk) ∈ D

Requirements:
- Append-only
- Globally verifiable
- Quantifiable finality
```

**Separation:**
- Identity uses Ed25519
- Directory uses whatever consensus (PoW, PoS, AuxPoW, Fiber, etc.)
- **No coupling** - same identity can move between directories

### 4.2 Authentication Protocol

**Setup:**
```
1. User generates (sk, pk) from UHEPRNG seed
2. User publishes (id, pk) to directory D
3. Wait for finality (directory-dependent)
4. Binding is now global: Bind(id, pk) = 1
```

**Challenge-Response:**
```
Verifier V knows: id
Prover P holds: sk

1. V → P: challenge c (random nonce)
2. P → V: σ = Sign_Ed25519(sk, c)  
3. V verifies:
   a. Fetch pk where Bind(id, pk) = 1 from D
   b. Check Verify_Ed25519(pk, c, σ) = 1
   c. Accept iff both true
```

**Key Properties:**
- No state in directory beyond (id, pk) binding
- No smart contracts or conditional logic
- Pure mathematics: signature valid or not

### 4.3 Security Proof Sketch

**Theorem:** If Ed25519 is EUF-CMA secure and D is append-only with finality, then Identity Bedrock provides unforgeable authentication.

**Proof:**
1. Assume adversary A wins: produces valid (id*, c*, σ*) without sk
2. By protocol: V checks Bind(id*, pk*) = 1 in D
3. V checks Verify(pk*, c*, σ*) = 1
4. But c* was never signed by P → violates EUF-CMA
5. Contradiction → Pr[A wins] ≤ negl(λ)

**Directory attacks:**
- Rewriting D to change pk requires directory-specific attack
- Cost depends on directory choice (quantified separately)
- Does not violate authentication security proof

### 4.4 Chain-Agnostic Property

**Same identity (sk, pk) can be published to:**
- Emercoin NVS (Bitcoin-anchored via AuxPoW)
- Bitcoin OP_RETURN + Merkle proofs
- Ethereum smart contract storage
- IPFS + blockchain timestamp
- Any append-only ledger

**Trade-offs:**
- Security inherits from directory choice
- Bitcoin AuxPoW: $5-20B attack cost
- Smaller chains: Lower attack cost
- User selects based on threat model

**Portability:**
- Export: Sign migration statement with sk
- Publish to new directory D'
- Verifiers accept new binding after finality
- Old directory remains historical record

---

## 5. Implementation: Emercoin + NESS (2 pages)

### 5.1 Directory: Emercoin NVS

**Consensus:**
- 85% Proof-of-Stake + 15% Bitcoin AuxPoW (artificially maintained)
- Finality: 1 confirmation (identity records), 6 confirmations (monetary)

**Storage Format (WORM):**
```json
{
  "id": "unique_identifier",
  "pk": "ed25519_public_key_base64",
  "created": "timestamp",
  "expires": "optional"
}
```

**Control:**
- Emercoin wallet keys control NVS record updates
- Ed25519 identity keys authenticate the identity itself
- **Separate concerns:** Directory control ≠ Identity authentication

**Attack Cost:**
- Rewrite NVS requires: EMC stake majority + Bitcoin 51% attack
- Bitcoin component: $5-20B (Coin Metrics 2024)
- **Inherits Bitcoin security for identity application**

### 5.2 Infrastructure: NESS Fiber

**Consensus:**
- Skycoin-type Fiber (announced publisher keys)
- Keys published in Emercoin NVS (e.g., `dpo/PrivateNESS.Network`)
- Validation: Blocks MUST be signed by announced keys

**99% Hostile Node Property:**
- Cannot forge blocks without publisher keys
- Can only delay propagation (DoS)
- Cannot rewrite history (append-only BoltDB)

**Key Compromise:**
- Stealing publisher key → can only reset to genesis (maximally detectable)
- Cannot rewrite past blocks
- New keys announced in Emercoin NVS (Bitcoin-anchored coordination)

### 5.3 Canonical Self-Spend Proof (Skycoin-Type Interop)

**Problem:** Linking Skycoin secp256k1 addresses to Ed25519 identity

**Solution:**
```
1. Create unsigned transaction: A → A (self-spend)
2. Sign with secp256k1 private key
3. Create proof: {network, address, policy, txid, tx_hex}
4. Anchor proof in Emercoin NVS WORM record
5. WORM controlled by Ed25519 bedrock key
```

**Result:** Different chains interoperate, Ed25519 remains ultimate authority

---

## 6. Evaluation (2 pages)

### 6.1 Attack Cost Analysis

**Goal:** Compromise identity binding (id, pk)

| Attack Vector | Requirements | Cost | Result |
|--------------|--------------|------|--------|
| Break Ed25519 | Violate OWF | Impossible (Rompel) | Authentication collapses |
| Rewrite Emercoin NVS | EMC stake + Bitcoin 51% | $5-20B (Coin Metrics) | Directory rewrite |
| Compromise NESS | Steal publisher keys | High, but DoS only | Can't change identity bindings (in Emercoin) |
| Capture 99% nodes | Physical control | High coordination | Zero impact (can't forge) |
| Legal prohibition | Political cost | Variable | Can't compromise crypto |

**Minimum successful attack:** Break Ed25519 OR rewrite directory  
**Practical floor:** $5-20B (Bitcoin component)

### 6.2 Comparison to Other Systems

| System | Identity Floor | Directory | Attack Cost | Institutional Keys? | Chain-Agnostic? |
|--------|---------------|-----------|-------------|--------------------|-----------------| 
| **Identity Bedrock** | Ed25519 (OWF/Rompel) | Pluggable | Inherits from directory | NO | YES |
| X.509 PKI | RSA/ECDSA | CA hierarchy | Compromise CA | YES (CA roots) | NO |
| Namecoin | ECDSA | Namecoin PoW | ~$1-10M | Implicit (miners) | NO |
| Ethereum DIDs | Varies | Ethereum L2 | ETH reorg + DAO | YES (DAO keys) | NO |
| Sovrin | Ed25519 | Permissioned | Trust stewards | YES (steward keys) | NO |

**Unique properties:**
- Only system with explicit Rompel floor
- Only chain-agnostic identity layer
- Only system inheriting Bitcoin security for non-monetary use
- Only system with no institutional keys beneath user

### 6.3 Performance Measurements

**Finality:**
- Emercoin NVS: 1 confirmation (~2 minutes)
- Verification: Query NVS + Ed25519 verify (~milliseconds)

**Scalability:**
- NVS throughput: [measured TPS]
- Challenge-response: No on-chain transaction required (stateless)
- Portable: Same identity works across any directory

---

## 7. Discussion (1.5 pages)

### 7.1 Limitations

**Out of Scope:**
- Key compromise via malware/physical theft (any system vulnerable)
- UI attacks, phishing (orthogonal to cryptographic security)
- Quantum computing (Ed25519 vulnerable to Shor's, post-quantum migration planned)

**Legal/Social:**
- Can outlaw software (can't compromise deployed identities)
- Can coerce individuals (can't capture the protocol itself)
- Can create legal risk (can't rewrite mathematical foundations)

### 7.2 Chain-Agnostic Trade-offs

**Directory Selection:**
- High security (Bitcoin-anchored): Higher cost, slower finality
- Lower security (smaller chains): Cheaper, faster, lower attack cost
- Users choose based on threat model

**Migration:**
- Identity portable across directories
- Migration signed with Ed25519 sk (proves legitimacy)
- Old directory remains historical record

### 7.3 Future Work

**Post-Quantum:**
- NIST PQC standards (CRYSTALS-Dilithium, SPHINCS+)
- Migration path: Sign transition with Ed25519, publish PQ key
- Maintains chain-agnostic property

**Threshold Signatures:**
- k-of-n Ed25519 keys for identity control
- Social recovery without institutional escrow

**Other Directories:**
- Demonstrate portability: Publish same identity to Bitcoin, Ethereum
- Measure attack cost differences
- User studies: Directory selection based on threat model

---

## 8. Related Work (1 page)

### 8.1 Theoretical Foundations

**Rompel (1990):** OWF ⟺ signatures  
- We operationalize as practical identity system

**Goldreich (Foundations of Cryptography):** EUF-CMA security  
- We use as authentication definition

### 8.2 Blockchain Identity

**Namecoin, EmerDNS:** Name-value storage  
- We separate identity crypto from blockchain crypto (chain-agnostic)

**W3C DIDs:** Decentralized identifiers  
- We provide minimal substrate DIDs can build on

**Sovrin, Indy:** Credential ecosystems  
- We provide bedrock layer without institutional keys

### 8.3 Consensus Mechanisms

**Bitcoin AuxPoW:** Merged mining  
- We apply to non-monetary use (identity directory)

**Skycoin Fiber:** Announced publisher  
- We leverage for 99% attack-resistant infrastructure

---

## 9. Conclusion (0.5 pages)

**Summary:**

1. **Theory:** Rompel proved OWF necessary and sufficient. We operationalize as chain-agnostic identity with no institutional keys.

2. **Systems:** Ed25519 identity layer + pluggable directory substrate. Deployed on Emercoin (Bitcoin-anchored) + NESS Fiber (99% immune).

3. **Application:** Attack cost $5-20B (inherits from Bitcoin). Public verification, reproducible builds, operational since 2013.

**Impact:**

- First practical identity system explicitly grounded in Rompel's theorem
- Quantified security: $5-20B attack cost, not hand-waving
- Chain-agnostic: Identity portable across directories
- No capture point: Individual is irreducible cryptographic primitive

**The position is unassailable because there is nothing beneath the individual to capture.**

---

## References

[1] Rompel, J. (1990). "One-Way Functions are Necessary and Sufficient for Secure Signatures." STOC '90.

[2] Josefsson, S., & Liusvaara, I. (2017). "Edwards-Curve Digital Signature Algorithm (EdDSA)." RFC 8032.

[3] Gibson, S. "Ultra-High Entropy Pseudo Random Number Generator." GRC.

[4] Emercoin. "Main Features of Hybrid Mining."

[5] Nuzzi, L., et al. (2024). "Breaking BFT: Quantifying the Cost to Attack Bitcoin and Ethereum." Coin Metrics.

[6] Skycoin. "Technical Background of Version 0 Skycoin Addresses."

[Plus standard cryptography, blockchain, and identity references]

---

## Appendices

**A. Formal Definitions**
- Signature schemes, EUF-CMA security
- Directory properties, finality
- Authentication protocol specification

**B. WORM Format Specification**
- JSON schema
- Validation rules
- Extension fields

**C. Deployment Details**
- Reproducible build process
- Public verification checklist
- Explorer URLs, GitHub repos

---

## Why One Paper, Three Facets Works

**Facet 1 (Theory):** Justifies the design - Rompel's floor is the minimum, anything less fails  
**Facet 2 (Systems):** Implements the theory - chain-agnostic architecture with deployed code  
**Facet 3 (Application):** Proves it works - $5-20B attack cost, operational verification  

**Inseparable:** 
- Theory without implementation = just philosophy
- Systems without theory = ad-hoc design
- Application without both = vaporware

**One paper shows:** "Here's the irreducible minimum (Rompel), here's how to build it (chain-agnostic), here's proof it works (deployed, quantified)."

**Target:** Top-tier security conference (CCS, USENIX) that values theory + systems + real-world impact.

This is the complete story in one place.