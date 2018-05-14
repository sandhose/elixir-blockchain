---
title: Blockchain en Elixir
author: Quentin Gliech
---

# Introduction

Ce projet est splitté en deux applications Elixir:

* `blockchain`, avec les primitives pour gérer une blockchain, dont des bots pour simuler des transactions et des workers qui minent les blocs
* `blockchain_web`, qui est une tentative d'interface web pour visualiser la chaîne. Malheureusement, le temps ayant manqué, cette partie n'a pas aboutie.

Il nécessite [Elixir](https://elixir-lang.org/) 1.6 pour tourner.

```
cd apps/blockchain/
mix deps.get
mix run run.exs
```

Cet exemple lance un seul nœud block, avec 10 bots qui s'échangent des sous.

Il est possible de faire tourner plusieurs nœuds distincts et de les connecter entre eux:

```
cd apps/blockchain/
mix deps.get
elixir --name one@127.0.0.1 -S mix run run.exs
elixir --name two@127.0.0.1 -S mix run run.exs one@127.0.0.1
elixir --name three@127.0.0.1 -S mix run run.exs one@127.0.0.1 two@127.0.0.1
```

Chaque nœud va alors miner des blocs et les envoyer aux autres nœuds qu'il connaît.
Chaque nœud a également 10 bots qui génèrent des transactions aléatoires.

# Blocks et transactions

Les blocks sont composés de:

* leur index (entier, incrémenté de 1 à chaque nouveau bloc, commence à zéro, `parent(block).index == block.index + 1`)
* une liste de transactions
* un champ `nonce` répondant à la preuve de travail
* le hash du block parent

Les transactions sont composées de:two

* Le `timestamp` de la transaction en microsecondes
* La clé publique de l'envoyeur
* La clé publique du receveur
* Le montant de la transaction
* La signature Ed25519 de la transaction par l'envoyeur

Toutes les transactions sont donc signées, et les blocks soumis à une validation (l'entièreté de la chaîne doit être valide pour qu'un bloc soit considéré comme valide).

# Comptes

Les comptes sont simplement composés d'une paire clé publique/clé privée (algorithme Ed25519).
À tout moment un process peut demander à un worker combien il a de "sous" sur son compte.

# Acceptation d'une nouvelle chaine

Les nœuds blocks envoient à tous les pairs qu'ils connaissent les nouveaux blocks qu'il découvrent.
Pour qu'un bloc soit pris en compte, il faut que sa chaine soit valide, et que son index (sa longueur de chaine) soit plus grande que la chaine actuelle.

Il y a donc un algorithme pour faire la différence entre deux chaînes, pour voir les blocks en plus et les blocks en moins entre deux chaînes.

Les workers gardent un cache de l'état des compte (pour pas avoir à re-parcourir toute la chaîne pour avoir la balance de chaque compte), et les transactions peuvent ainsi être appliquées et rembobinées sur ce cache.

À l'application des transactions, il est vérifié qu'aucun compte ne descend dans le négatif.
Un bloc n'est pas accepté s'il contient des transactions impossibles.

# Preuve de travail, minage et récompense.

La preuve de travail implémentée est simple: il y a un champ dans les blocs `nonce`, qui est incrémenté jusqu'à ce que le hash du bloc commence par suffisamment de zéros.

Les workers peuvent ajouter au bloc une transaction de récompense vers l'adresse de leur choix.
L'envoyeur de cette transaction est l'adresse spéciale `0`, et le montant est forcément de `1.0`.
Au plus une seule transaction peut être présente dans chaque bloc.

# Licence et code source

Code distribué sous MIT, disponible sur GitHub: https://github.com/sandhose/elixir-blockchain
