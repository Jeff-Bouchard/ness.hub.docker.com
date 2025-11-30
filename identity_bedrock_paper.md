# Identity Bedrock: A Minimal Two-Layer Architecture for User‑Controlled Authentication

**Author:**  
Jeff Bouchard

**Affiliations:**  
Privateness Network – privateness.network
Emercoin Community (volunteer) – emercoin.com/team  


**Contact:** jeff@privateness.network

---

## Abstract

A line of work by Naor–Yung and Rompel in the late 1980s and early 1990s established that the existence of one-way functions (OWF) is necessary and sufficient for the existence of digital signature schemes that are existentially unforgeable under adaptive chosen-message attack (EUF‑CMA). Informally, this places one-way functions as a minimal standard hardness assumption for the *existence* of secure signatures in the usual probabilistic polynomial‑time model.

In this paper we treat that classification as a design guideline and propose a simple two‑layer identity architecture, which we call **Identity Bedrock**. The identity layer consists solely of an EUF‑CMA secure signature scheme (instantiated with Ed25519, following RFC 8032), while the directory layer consists of an append‑only ledger e.g blockchain of bindings from identifiers to public keys with some notion of verifiable finality. 

Cryptographic assumptions for authentication thereby reduce to those needed for OWF and the chosen signature scheme; assumptions about consensus, availability, and finality for the directory are treated separately.

We implement Identity Bedrock on top of Emercoin Name‑Value Storage (EmerNVS), using Emercoin Core as decentralized source of Truth. 

Emercoin’s documented hybrid Proof‑of‑Stake plus Bitcoin Auxiliary Proof‑of‑Work design couples part of its directory security to Bitcoin’s consensus; any security we attribute to the directory simply inherits the assumptions and limitations of Emercoin and Bitcoin as described in their respective documentation and public analyses. 

Seed material for Ed25519 keys is derived from a combination of the operating system’s cryptographically secure random facility, Emercoin Core’s RC4OK‑based pseudorandom number generator, and Gibson’s Ultra‑High Entropy PRNG (UHEPRNG) used as an additional mixing step with a local salt; UHEPRNG is not used as the sole entropy source.

To the best of our knowledge, this is one of the first deployed identity architectures that (i) explicitly adopts the Naor–Yung–Rompel classification as its design motivation, and (ii) implements a corresponding two‑layer pattern on a Bitcoin‑anchored name–value directory with publicly verifiable bindings while keeping that "ultimate identity" private and unlinkable to real world identity without direct disclosure.

---

## 1. Introduction

### 1.1 Motivation: Institutional Capture and Identity Layers

Many deployed identity systems place one or more institutional keys "beneath" the user. X.509 public‑key infrastructures rely on Certificate Authority (CA) roots and intermediate CAs. OAuth and OpenID Connect flows are mediated by Identity Provider (IdP) servers. Government‑issued credentials depend on registry authorities. A number of blockchain‑based identity schemes introduce admin or governance keys (for registries, DAOs, or smart contracts) or permissioned validator sets.

In such systems, a party that controls these institutional keys (or the infrastructure around them) can often revoke, deny, or modify identity information independently of the user’s consent. As various digital identity initiatives evolve, these capture points can become attractive loci for technical or political influence.

Our aim in this work is more modest than "solving digital identity" in general. We ask a narrower question:

> Can we design an identity and authentication architecture in which, at the cryptographic layer, there are no additional signing keys beneath the individual beyond those implied by standard assumptions for digital signatures?

We would like any additional components (ledgers, registries, applications, networking layers) to act as *clients* of an identity and directory service, rather than as alternative cryptographic roots.

### 1.2 Minimal Assumptions for Signatures: Naor–Yung and Rompel

The theoretical foundations of signatures have been studied extensively. Of particular relevance here are two classic results.

Naor and Yung introduced **universal one‑way hash function families (UOWHFs)** and showed that the existence of UOWHFs implies the existence of EUF‑CMA secure signature schemes. Rompel subsequently showed how to construct UOWHFs from arbitrary one‑way functions. Combined with the straightforward observation that EUF‑CMA secure signatures imply the existence of a one‑way function, these works yield the well‑known equivalence:

- One‑way functions exist  
  **if and only if**  
  EUF‑CMA secure signature schemes exist.

Informally, in the model considered by these works, one-way functions are a minimal standard hardness assumption for the *existence* of digital signature schemes suitable for public authentication. Importantly, this classification is purely cryptographic and does not depend on any particular ledger, directory, or blockchain; it is a statement about what can be constructed from one-way functions in the abstract.

We do not re‑prove or extend these results. Instead, we take them as a starting point for system design: we attempt to keep the cryptographic assumptions for authentication at this minimal level (one‑way functions → signatures), and to push other concerns—such as naming, availability, and finality—into a separate directory layer.

### 1.3 Identity Bedrock in One Line

At a high level, **Identity Bedrock** consists of:

- an **identity layer** that performs authentication using a standard EUF‑CMA secure signature scheme (Ed25519), and  
- a **directory layer** that records bindings \((\text{id}, \text{pk})\) in an append‑only ledger with verifiable finality.

In our implementation, the directory layer is Emercoin’s Name‑Value Storage (EmerNVS) and EmerDNS/.coin, run via Emercoin Core without modification. Higher‑layer systems—applications, networking stacks, external blockchains, oracles—are treated as **clients** of this identity and directory service: they read bindings and verify signatures, but do not introduce additional signing roots beneath the user.

---

## 2. Cryptographic Baseline and Identity Bedrock Pattern

### 2.1 Naor–Yung–Rompel Baseline for Signatures

Let **OWF** denote the statement "one‑way functions exist," **UOWHF** the statement "universal one‑way hash function families exist," and **SIG\_{EUF‑CMA}** the statement "there exists a digital signature scheme that is existentially unforgeable under adaptive chosen‑message attack."

The following implications are known:

1. Naor–Yung showed that  
   \[
      \mathrm{UOWHF} \Rightarrow \mathrm{SIG}_{\mathrm{EUF\mbox{-}CMA}}.
   \]

2. Rompel showed how to construct UOWHFs from arbitrary one‑way functions, i.e.  
   \[
      \mathrm{OWF} \Rightarrow \mathrm{UOWHF}.
   \]

3. It is folklore (and straightforward to formalize) that any EUF‑CMA secure signature scheme implies the existence of a one‑way function, i.e.  
   \[
      \mathrm{SIG}_{\mathrm{EUF\mbox{-}CMA}} \Rightarrow \mathrm{OWF}.
   \]

Combining these, we obtain the equivalence:
\[
   \mathrm{OWF} \Leftrightarrow \mathrm{SIG}_{\mathrm{EUF\mbox{-}CMA}}.
\]

In this sense, one‑way functions are a minimal standard hardness assumption for the *existence* of EUF‑CMA secure signatures in the probabilistic polynomial‑time (PPT) model considered in these works. This statement is completely independent of any specific ledger or directory implementation; it is a statement about what can be constructed from OWF in the abstract.

### 2.2 Minimal Assumption for Authentication

We use this classification as a design guideline.

**Definition (Minimal assumption for authentication).**  
We say that an authentication layer operates at a *Rompel‑based minimal assumption level* if, at the cryptographic level, its only primitive strictly beneath public‑key authentication (in the sense of the equivalence above) is the existence of one‑way functions. Concretely:

- Authentication is instantiated via a digital signature scheme that is EUF‑CMA s
