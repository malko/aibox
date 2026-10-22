/* AIBox — landing page i18n (no framework, no dependency).
   English is the default, French is a full translation. */

(function (global) {
  "use strict";

  const DEFAULT_LANG = "en";
  const STORAGE_KEY = "aiboxSiteLang";

  const messages = {
    en: {
      "meta.title": "AIBox — a virtual machine sandbox for your AI agents",
      "meta.description":
        "AIBox gives your AI agents a virtual machine to work in: the agent only reaches the files of the guest, the host stays untouched, and the whole box can be thrown away and rebuilt.",

      "nav.why": "why",
      "nav.isolation": "vm or docker",
      "nav.how": "how it works",
      "nav.console": "console",
      "nav.faq": "faq",
      "nav.menu": "menu",
      "nav.main": "Skip to content",
      "nav.sections": "Sections",
      "nav.language": "Language",

      "copy.label": "copy",
      "copy.done": "copied",

      "hero.badge": "a sandbox for your AI agents",
      "hero.title": "Your agent, in a box it",
      "hero.title.accent": "cannot escape.",
      "hero.lede":
        "AI agents need files, a shell and freedom. Give them a virtual machine: they work in the guest, they break the guest, and your laptop never finds out.",
      "hero.cta.primary": "Get started",
      "hero.cta.secondary": "View on GitHub",
      "hero.cta.docs": "Read the docs",
      "hero.meta.1": "KVM / QEMU + libvirt",
      "hero.meta.2": "its own kernel",
      "hero.meta.3": "disposable snapshots",
      "hero.meta.4": "nothing in the cloud",

      "why.kicker": "why",
      "why.title": "An agent on your machine is an agent on your life",
      "why.lede":
        "A coding agent is a shell with your permissions. Hand it your computer and you hand it your keys, your files and your secrets.",
      "why.risk.tag": "on the host",
      "why.risk.title": "What it can reach",
      "why.risk.lede": "Everything your user can reach, and the agent never asks.",
      "why.risk.1": "Your SSH keys, your .env files, your cloud credentials",
      "why.risk.2": "Your projects, your notes, your browser sessions",
      "why.risk.3": "A wrong command that deletes the wrong directory",
      "why.risk.4": "A system left dirty, with packages and files everywhere",
      "why.risk.5": "Your tokens, sent wherever the prompt takes it",
      "why.safe.tag": "in the box",
      "why.safe.title": "What it can reach",
      "why.safe.lede": "The guest filesystem, and nothing else. The boundary is the kernel.",
      "why.safe.1": "The files of the virtual machine, and the shared folder",
      "why.safe.2": "Your projects, but the copies inside the guest",
      "why.safe.3": "A wrong command that breaks the guest, and nothing else",
      "why.safe.4": "A snapshot to go back to",
      "why.safe.5": "A box you delete without a second thought",

      "isolation.kicker": "isolation",
      "isolation.title": "Why a virtual machine, and not a container",
      "isolation.lede":
        "A container is a process with a few walls around it. A virtual machine is another computer. When the agent is the one you do not trust, that difference is the whole point.",
      "isolation.head.what": "what",
      "isolation.head.docker": "a container",
      "isolation.head.vm": "a virtual machine",
      "isolation.row1.label": "Kernel",
      "isolation.row1.docker": "Shared with the host",
      "isolation.row1.vm": "Its own, inside the guest",
      "isolation.row2.label": "Files",
      "isolation.row2.docker": "The host filesystem, unless you mount it very carefully",
      "isolation.row2.vm": "Only the guest filesystem",
      "isolation.row3.label": "Escape",
      "isolation.row3.docker": "A container escape is a host compromise",
      "isolation.row3.vm": "The guest kernel is the wall, root included",
      "isolation.row4.label": "Devices",
      "isolation.row4.docker": "The host devices, if you are not careful",
      "isolation.row4.vm": "Emulated, with your permission",
      "isolation.row5.label": "Blast radius",
      "isolation.row5.docker": "The whole workstation",
      "isolation.row5.vm": "One disposable disk",
      "isolation.row6.label": "Reset",
      "isolation.row6.docker": "Delete the container, lose the work",
      "isolation.row6.vm": "Revert a snapshot, keep the work",
      "isolation.note":
        "A container is fine to isolate a build. It is not fine to isolate an agent that writes its own code and runs it. AIBox uses a virtual machine, with a real kernel, for that reason.",

      "playground.kicker": "playground",
      "playground.title": "A playground you can break and throw away",
      "playground.lede":
        "The point is not only to protect the machine. It is to give the agent a place where it can try things — and to make that place easy to create, easy to reset and easy to share.",
      "feature.1.title": "One-command setup",
      "feature.1.body":
        "A guided setup builds the guest, the SSH access, the services and the tunnel, step by step. Every answer is saved.",
      "feature.2.title": "A local web console",
      "feature.2.body":
        "Services, updates, setup steps, snapshots and the VM lifecycle, in a tab that stays on your machine.",
      "feature.3.title": "One tunnel per service",
      "feature.3.body":
        "Each service gets its own port forward and its own bind address. Localhost by default, the network only when you ask.",
      "feature.4.title": "LAN exposure on demand",
      "feature.4.body":
        "Expose a single service to the network, per service, without opening the whole VM to the world.",
      "feature.5.title": "Snapshots and resets",
      "feature.5.body":
        "Snapshot before a risky run, revert in a click, and keep the broken state around to study it.",
      "feature.6.title": "VS Code Remote-SSH",
      "feature.6.body":
        "Open the shared folder in your own VS Code. The host path is mapped to the guest path for you.",
      "feature.7.title": "Your harnesses, installed",
      "feature.7.body":
        "The setup installs opencode, the DeepSeek Harness and Claude Code in the guest, and registers their services for you.",
      "feature.8.title": "Updates you can see",
      "feature.8.body":
        "Check the host and the VM for updates, then apply them one target at a time — a service, a script, the OS or all of them.",

      "network.kicker": "network",
      "network.title": "One door into the box",
      "network.lede":
        "The VM is never exposed directly. Every service travels through a single SSH tunnel, and only the services you choose can leave the machine.",
      "network.host": "Your machine",
      "network.host.sub": "aibox CLI · web console",
      "network.tunnel": "Tunnel",
      "network.tunnel.sub": "ssh -N, one -L per service",
      "network.vm": "AIBox VM",
      "network.vm.sub": "KVM guest · virtiofs share",
      "network.service": "Service",
      "network.service.sub": "opencode · dsh · claude",
      "network.localhost": "localhost:4096",
      "network.lan": "LAN",
      "network.lan.sub": "only if you allow it",
      "network.tag1": "ssh",
      "network.tag2": "ssh",
      "network.tag3": "per service",
      "network.tag4": "on demand",
      "network.boundary": "kernel boundary",

      "how.kicker": "how it works",
      "how.title": "Three commands and you have a box",
      "how.lede":
        "Clone the repository, run the setup, then pick how you want to work: the shell, the console or VS Code.",
      "how.step1.no": "step 1",
      "how.step1.title": "Set the box up",
      "how.step1.body":
        "The setup walks through the VM, SSH, the services and the tunnel. Every answer is saved, so a second run only asks what changed.",
      "how.step2.no": "step 2",
      "how.step2.title": "Open a shell in the guest",
      "how.step2.body":
        "One command opens an SSH session in the virtual machine, with every service already forwarded to the right local port. This is where your agent works.",
      "how.step3.no": "step 3",
      "how.step3.title": "Or drive the box from the browser",
      "how.step3.body":
        "The local console shows the services with a live availability dot, and gives you the VM controls, the snapshots and the updates.",
      "how.code1.title": "clone & setup",
      "how.code2.title": "connect",
      "how.code3.title": "web console",

      "console.kicker": "the console",
      "console.title": "The web console, in three views",
      "console.lede":
        "The same state the CLI shows, in a browser tab that stays on your machine — no account, no server, no telemetry.",
      "console.1.title": "Overview",
      "console.1.body":
        "VM and tunnel state, the services that answer, and the buttons to start, stop or restart the box.",
      "console.2.title": "Services",
      "console.2.body":
        "Every service with its port, its local URL and its LAN exposure, plus a live dot that tells you if it really listens.",
      "console.3.title": "Snapshots",
      "console.3.body":
        "Create a snapshot before a risky change, list the ones you have, revert or delete them in a click.",

      "commands.kicker": "commands",
      "commands.title": "The CLI stays out of your way",
      "commands.lede":
        "A dozen commands cover the whole life of the box. Everything is scriptable, nothing is interactive-only.",
      "cmd.start": "Start the VM and the tunnel",
      "cmd.status": "State, service URLs, tunnel state",
      "cmd.web": "Open the local web console",
      "cmd.exec": "Run a command in the VM",
      "cmd.tunnel": "Tunnel and LAN exposure",
      "cmd.vscode": "Open the VM in VS Code",
      "cmd.service-add": "Add a service",
      "cmd.service-list": "List the services",
      "cmd.snapshot": "Create, list or delete snapshots",
      "cmd.update": "Update a target",
      "cmd.check": "Check for updates",
      "cmd.setup": "Run the setup steps",
      "cmd.shutdown": "Stop the tunnel and the VM",

      "req.kicker": "requirements",
      "req.title": "Almost nothing",
      "req.lede": "A Linux host with KVM, and a guest image. That is the whole list.",
      "req.host.title": "host",
      "req.host.1": "KVM/QEMU with libvirt",
      "req.host.2": "<code>virsh</code> and <code>libvirt-client</code>",
      "req.host.3": "BusyBox <code>httpd</code> for the web console",
      "req.host.4": "A Linux distribution, on bare metal or on a workstation",
      "req.guest.title": "guest",
      "req.guest.1": "Ubuntu or Debian, with SSH access",
      "req.guest.2": "4 GB of RAM, 4 cores recommended",
      "req.guest.3": "A dedicated user with sudo rights",
      "req.guest.4": "The share is mounted with virtiofs",
      "req.note":
        "macOS is not supported yet. The Lima based support is being finished, and it will land here.",

      "faq.kicker": "faq",
      "faq.title": "The questions people actually ask",
      "faq.lede": "Short answers, no marketing.",
      "faq.1.q": "Can the agent reach my files?",
      "faq.1.a": "Only the ones you put in the shared folder, and the ones inside the guest. Your SSH keys, your browser sessions and the rest of the workstation stay out of reach: the agent works in a virtual machine with its own kernel.",
      "faq.2.q": "Why a virtual machine and not Docker?",
      "faq.2.a": "A container shares the kernel and the filesystem of the host: a container escape, or a badly written mount, hands the agent your whole machine. A virtual machine has its own kernel, and that kernel is the boundary. For a build, a container is enough. For an agent that writes and runs its own code, it is not.",
      "faq.3.q": "What if the agent breaks everything?",
      "faq.3.a": "You take a snapshot before it starts, and you revert it afterwards. The broken state stays available to look at, and the host never saw any of it.",
      "faq.4.q": "Does any of my data leave the machine?",
      "faq.4.a": "No. The VM runs on your hardware, the console is served by BusyBox on your machine and the tunnels are plain SSH. There is no account, no telemetry and no cloud service in the loop.",
      "faq.5.q": "Do I need root on the host?",
      "faq.5.a": "Only for a few setup steps, and the console asks for the sudo password once, in memory, when a privileged step needs it. Everything else runs as your user.",
      "faq.6.q": "Can I run my own services?",
      "faq.6.a": "Yes. <code>aibox service-add mytool 8080</code> registers a port, and the tunnel, the console and the status output pick it up right away.",
      "faq.7.q": "How do I reach a service from another device?",
      "faq.7.a": "Expose that service on the LAN: <code>aibox tunnel lan on opencode --permanent</code>. The tunnel binds the port on your network interface instead of localhost, for that service only.",
      "faq.8.q": "Is macOS supported?",
      "faq.8.a": "Not yet. The Lima based support is on its way, and this page will say so as soon as it works.",

      "cta.title": "Give your agent a box to break",
      "cta.lede":
        "One repository, a handful of shell scripts, and a virtual machine that behaves like a machine you own. Clone it, run the setup, and let the agent work.",
      "cta.button": "Get started on GitHub",
      "cta.secondary": "Read the README",

      "footer.tagline": "your AI, in its own box",
      "footer.made": "Shell scripts, no framework, no cloud.",
      "footer.links": "Links",
      "footer.repo": "Repository",
      "footer.issues": "Issues",
      "footer.license": "MIT License"
    },

    fr: {
      "meta.title": "AIBox — une machine virtuelle pour confiner vos agents IA",
      "meta.description":
        "AIBox donne à vos agents IA une machine virtuelle où travailler : l'agent n'accède qu'aux fichiers du guest, l'hôte reste intact, et toute la boîte peut être jetée puis reconstruite.",

      "nav.why": "pourquoi",
      "nav.isolation": "vm ou docker",
      "nav.how": "principe",
      "nav.console": "console",
      "nav.faq": "questions",
      "nav.menu": "menu",
      "nav.main": "Aller au contenu",
      "nav.sections": "Sections",
      "nav.language": "Langue",

      "copy.label": "copier",
      "copy.done": "copié",

      "hero.badge": "un bac à sable pour vos agents IA",
      "hero.title": "Votre agent, dans une boîte dont il",
      "hero.title.accent": "ne peut pas sortir.",
      "hero.lede":
        "Un agent IA a besoin de fichiers, d'un shell et de liberté. Donnez-lui une machine virtuelle : il travaille dans le guest, il casse le guest, et votre portable n'en saura rien.",
      "hero.cta.primary": "Commencer",
      "hero.cta.secondary": "Voir sur GitHub",
      "hero.cta.docs": "Lire la documentation",
      "hero.meta.1": "KVM / QEMU + libvirt",
      "hero.meta.2": "son propre noyau",
      "hero.meta.3": "des snapshots jetables",
      "hero.meta.4": "rien dans le cloud",

      "why.kicker": "pourquoi",
      "why.title": "Un agent sur votre machine est un agent sur votre vie",
      "why.lede":
        "Un agent de code, c'est un shell avec vos permissions. Donnez-lui votre ordinateur et vous lui donnez vos clés, vos fichiers et vos secrets.",
      "why.risk.tag": "sur l'hôte",
      "why.risk.title": "Ce qu'il peut atteindre",
      "why.risk.lede": "Tout ce que votre utilisateur atteint, et l'agent ne demande jamais la permission.",
      "why.risk.1": "Vos clés SSH, vos fichiers .env, vos identifiants cloud",
      "why.risk.2": "Vos projets, vos notes, vos sessions de navigateur",
      "why.risk.3": "Une mauvaise commande qui supprime le mauvais dossier",
      "why.risk.4": "Un système sali, des paquets et des fichiers partout",
      "why.risk.5": "Vos tokens, envoyés là où le prompt l'emmène",
      "why.safe.tag": "dans la boîte",
      "why.safe.title": "Ce qu'il peut atteindre",
      "why.safe.lede": "Le système de fichiers du guest, et rien d'autre. La frontière, c'est le noyau.",
      "why.safe.1": "Les fichiers de la machine virtuelle, et le dossier partagé",
      "why.safe.2": "Vos projets, mais les copies dans le guest",
      "why.safe.3": "Une mauvaise commande qui casse le guest, et rien d'autre",
      "why.safe.4": "Un snapshot vers lequel revenir",
      "why.safe.5": "Une boîte que vous supprimez sans y penser",

      "isolation.kicker": "isolation",
      "isolation.title": "Pourquoi une machine virtuelle, et pas un conteneur",
      "isolation.lede":
        "Un conteneur, c'est un processus entouré de quelques murs. Une machine virtuelle, c'est un autre ordinateur. Quand l'agent est justement celui en qui vous n'avez pas confiance, cette différence est tout l'enjeu.",
      "isolation.head.what": "quoi",
      "isolation.head.docker": "un conteneur",
      "isolation.head.vm": "une machine virtuelle",
      "isolation.row1.label": "Noyau",
      "isolation.row1.docker": "Partagé avec l'hôte",
      "isolation.row1.vm": "Le sien, dans le guest",
      "isolation.row2.label": "Fichiers",
      "isolation.row2.docker": "Le système de l'hôte, sauf montage très prudent",
      "isolation.row2.vm": "Seulement le système du guest",
      "isolation.row3.label": "Évasion",
      "isolation.row3.docker": "Une évasion de conteneur est une compromission de l'hôte",
      "isolation.row3.vm": "Le noyau du guest est le mur, root compris",
      "isolation.row4.label": "Périphériques",
      "isolation.row4.docker": "Les périphériques de l'hôte, si l'on n'y fait pas attention",
      "isolation.row4.vm": "Émulés, avec votre accord",
      "isolation.row5.label": "Rayon d'impact",
      "isolation.row5.docker": "Tout le poste de travail",
      "isolation.row5.vm": "Un disque jetable",
      "isolation.row6.label": "Remise à zéro",
      "isolation.row6.docker": "Supprimer le conteneur, perdre le travail",
      "isolation.row6.vm": "Revenir à un snapshot, garder le travail",
      "isolation.note":
        "Un conteneur convient pour isoler une compilation. Il ne convient pas pour isoler un agent qui écrit son propre code et l'exécute. AIBox utilise une machine virtuelle, avec un vrai noyau, pour cette raison.",

      "playground.kicker": "bac à sable",
      "playground.title": "Un terrain de jeu que l'on peut casser et jeter",
      "playground.lede":
        "L'objectif n'est pas seulement de protéger la machine. C'est aussi de donner à l'agent un endroit où essayer — et de rendre cet endroit facile à créer, facile à réinitialiser et facile à partager.",
      "feature.1.title": "Installation en une commande",
      "feature.1.body":
        "Une installation guidée construit le guest, l'accès SSH, les services et le tunnel, étape par étape. Chaque réponse est mémorisée.",
      "feature.2.title": "Une console web locale",
      "feature.2.body":
        "Services, mises à jour, installation, snapshots et cycle de vie de la VM, dans un onglet qui ne quitte jamais votre machine.",
      "feature.3.title": "Un tunnel par service",
      "feature.3.body":
        "Chaque service a sa redirection de port et sa propre adresse d'écoute. Localhost par défaut, le réseau uniquement quand vous le demandez.",
      "feature.4.title": "Exposition réseau à la demande",
      "feature.4.body":
        "Exposez un seul service au réseau, service par service, sans ouvrir la VM entière au monde.",
      "feature.5.title": "Snapshots et remises à zéro",
      "feature.5.body":
        "Snapshot avant une exécution risquée, retour arrière en un clic, et on garde l'état cassé pour l'étudier.",
      "feature.6.title": "VS Code en Remote-SSH",
      "feature.6.body":
        "Ouvrez le dossier partagé dans votre propre VS Code. Le chemin de l'hôte est converti en chemin guest pour vous.",
      "feature.7.title": "Vos harnais, installés",
      "feature.7.body":
        "L'installation installe opencode, le DeepSeek Harness et Claude Code dans le guest, et enregistre leurs services pour vous.",
      "feature.8.title": "Des mises à jour visibles",
      "feature.8.body":
        "Vérifiez l'hôte et la VM, puis appliquez ce qui change cible par cible : un service, un script, l'OS ou tout à la fois.",

      "network.kicker": "réseau",
      "network.title": "Une seule porte dans la boîte",
      "network.lede":
        "La VM n'est jamais exposée directement. Chaque service passe par un unique tunnel SSH, et seuls ceux que vous choisissez peuvent quitter la machine.",
      "network.host": "Votre machine",
      "network.host.sub": "CLI aibox · console web",
      "network.tunnel": "Tunnel",
      "network.tunnel.sub": "ssh -N, un -L par service",
      "network.vm": "VM AIBox",
      "network.vm.sub": "guest KVM · partage virtiofs",
      "network.service": "Service",
      "network.service.sub": "opencode · dsh · claude",
      "network.localhost": "localhost:4096",
      "network.lan": "LAN",
      "network.lan.sub": "si vous l'autorisez",
      "network.tag1": "ssh",
      "network.tag2": "ssh",
      "network.tag3": "par service",
      "network.tag4": "à la demande",
      "network.boundary": "frontière du noyau",

      "how.kicker": "principe",
      "how.title": "Trois commandes et vous avez une boîte",
      "how.lede":
        "Clonez le dépôt, lancez l'installation, puis choisissez votre façon de travailler : le shell, la console ou VS Code.",
      "how.step1.no": "étape 1",
      "how.step1.title": "Installer la boîte",
      "how.step1.body":
        "L'installation passe par la VM, SSH, les services et le tunnel. Chaque réponse est mémorisée, donc une seconde exécution ne demande que ce qui a changé.",
      "how.step2.no": "étape 2",
      "how.step2.title": "Ouvrir un shell dans le guest",
      "how.step2.body":
        "Une seule commande ouvre une session SSH dans la machine virtuelle, chaque service déjà redirigé vers le bon port local. C'est là que votre agent travaille.",
      "how.step3.no": "étape 3",
      "how.step3.title": "Ou piloter la boîte depuis le navigateur",
      "how.step3.body":
        "La console locale montre les services avec un point de disponibilité en direct, et donne accès au cycle de vie de la VM, aux snapshots et aux mises à jour.",
      "how.code1.title": "cloner et installer",
      "how.code2.title": "se connecter",
      "how.code3.title": "console web",

      "console.kicker": "la console",
      "console.title": "La console web, en trois vues",
      "console.lede":
        "Le même état que la CLI, dans un onglet qui reste sur votre machine — sans compte, sans serveur, sans télémétrie.",
      "console.1.title": "Vue d'ensemble",
      "console.1.body":
        "L'état de la VM et du tunnel, les services qui répondent, et les boutons pour démarrer, arrêter ou redémarrer la boîte.",
      "console.2.title": "Services",
      "console.2.body":
        "Chaque service avec son port, son URL locale et son exposition réseau, plus un point en direct qui indique s'il écoute vraiment.",
      "console.3.title": "Snapshots",
      "console.3.body":
        "Créez un snapshot avant un changement risqué, listez ceux que vous avez, restaurez-les ou supprimez-les en un clic.",

      "commands.kicker": "commandes",
      "commands.title": "La CLI ne s'impose pas",
      "commands.lede":
        "Une douzaine de commandes couvrent toute la vie de la boîte. Tout est scriptable, rien n'est propre au mode interactif.",
      "cmd.start": "Démarrer la VM et le tunnel",
      "cmd.status": "État, URL des services, état du tunnel",
      "cmd.web": "Ouvrir la console web locale",
      "cmd.exec": "Exécuter une commande dans la VM",
      "cmd.tunnel": "Tunnel et exposition réseau",
      "cmd.vscode": "Ouvrir la VM dans VS Code",
      "cmd.service-add": "Ajouter un service",
      "cmd.service-list": "Lister les services",
      "cmd.snapshot": "Créer, lister ou supprimer des snapshots",
      "cmd.update": "Mettre à jour une cible",
      "cmd.check": "Vérifier les mises à jour",
      "cmd.setup": "Lancer les étapes d'installation",
      "cmd.shutdown": "Arrêter le tunnel et la VM",

      "req.kicker": "prérequis",
      "req.title": "Presque rien",
      "req.lede": "Un hôte Linux avec KVM, et une image guest. C'est toute la liste.",
      "req.host.title": "hôte",
      "req.host.1": "KVM/QEMU avec libvirt",
      "req.host.2": "<code>virsh</code> et <code>libvirt-client</code>",
      "req.host.3": "BusyBox <code>httpd</code> pour la console web",
      "req.host.4": "Une distribution Linux, sur machine nue ou sur poste de travail",
      "req.guest.title": "guest",
      "req.guest.1": "Ubuntu ou Debian, accessible en SSH",
      "req.guest.2": "4 Go de RAM, 4 cœurs recommandés",
      "req.guest.3": "Un utilisateur dédié avec les droits sudo",
      "req.guest.4": "Le partage est monté en virtiofs",
      "req.note":
        "macOS n'est pas encore supporté. Le support basé sur Lima est en cours de finition, et il atterrira ici.",

      "faq.kicker": "questions",
      "faq.title": "Les questions que l'on pose vraiment",
      "faq.lede": "Des réponses courtes, sans discours.",
      "faq.1.q": "L'agent peut-il atteindre mes fichiers ?",
      "faq.1.a": "Seulement ceux que vous mettez dans le dossier partagé, et ceux du guest. Vos clés SSH, vos sessions de navigateur et le reste du poste de travail restent hors de portée : l'agent travaille dans une machine virtuelle qui a son propre noyau.",
      "faq.2.q": "Pourquoi une machine virtuelle et pas Docker ?",
      "faq.2.a": "Un conteneur partage le noyau et le système de fichiers de l'hôte : une évasion de conteneur, ou un montage maladroit, livre toute votre machine à l'agent. Une machine virtuelle a son propre noyau, et ce noyau est la frontière. Pour une compilation, un conteneur suffit. Pour un agent qui écrit et exécute son propre code, non.",
      "faq.3.q": "Et si l'agent casse tout ?",
      "faq.3.a": "Vous prenez un snapshot avant qu'il commence, et vous revenez en arrière après. L'état cassé reste disponible pour l'examiner, et l'hôte n'en a jamais rien vu.",
      "faq.4.q": "Est-ce que mes données quittent la machine ?",
      "faq.4.a": "Non. La VM tourne sur votre matériel, la console est servie par BusyBox sur votre machine et les tunnels sont du SSH pur. Aucun compte, aucune télémétrie, aucun service cloud dans la boucle.",
      "faq.5.q": "Faut-il être root sur l'hôte ?",
      "faq.5.a": "Seulement pour quelques étapes d'installation, et la console demande le mot de passe sudo une fois, en mémoire, quand une étape privilégiée en a besoin. Le reste tourne avec votre utilisateur.",
      "faq.6.q": "Puis-je faire tourner mes propres services ?",
      "faq.6.a": "Oui. <code>aibox service-add mytool 8080</code> enregistre un port, et le tunnel, la console et la sortie de statut le reprennent immédiatement.",
      "faq.7.q": "Comment accéder à un service depuis un autre appareil ?",
      "faq.7.a": "Exposez ce service sur le réseau : <code>aibox tunnel lan on opencode --permanent</code>. Le tunnel écoute alors sur l'interface réseau au lieu de localhost, pour ce service uniquement.",
      "faq.8.q": "macOS est-il supporté ?",
      "faq.8.a": "Pas encore. Le support basé sur Lima est en cours, et cette page le dira dès que ça fonctionnera.",

      "cta.title": "Donnez à votre agent une boîte à casser",
      "cta.lede":
        "Un dépôt, quelques scripts shell, et une machine virtuelle qui se comporte comme une machine qui vous appartient. Clonez, lancez l'installation, et laissez l'agent travailler.",
      "cta.button": "Commencer sur GitHub",
      "cta.secondary": "Lire le README",

      "footer.tagline": "votre IA, dans sa propre boîte",
      "footer.made": "Des scripts shell, pas de framework, pas de cloud.",
      "footer.links": "Liens",
      "footer.repo": "Dépôt",
      "footer.issues": "Tickets",
      "footer.license": "Licence MIT"
    }
  };

  function currentLang() {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored && messages[stored]) return stored;
    } catch (e) {
      /* storage unavailable */
    }
    const nav = (navigator.language || DEFAULT_LANG).slice(0, 2);
    return messages[nav] ? nav : DEFAULT_LANG;
  }

  function t(key, params) {
    const lang = currentLang();
    let text = messages[lang][key];
    if (text === undefined) text = messages[DEFAULT_LANG][key];
    if (text === undefined) return key;
    if (!params) return text;
    return text.replace(/\{(\w+)\}/g, (match, name) =>
      Object.prototype.hasOwnProperty.call(params, name) ? params[name] : match
    );
  }

  function applyTranslations(root) {
    const scope = root || document;

    scope.querySelectorAll("[data-i18n]").forEach((el) => {
      el.textContent = t(el.dataset.i18n);
    });
    scope.querySelectorAll("[data-i18n-html]").forEach((el) => {
      el.innerHTML = t(el.dataset.i18nHtml);
    });
    scope.querySelectorAll("[data-i18n-attr]").forEach((el) => {
      const pairs = el.dataset.i18nAttr.split(",");
      pairs.forEach((pair) => {
        const [attr, key] = pair.split(":").map((s) => s.trim());
        if (attr && key) el.setAttribute(attr, t(key));
      });
    });
    scope.querySelectorAll("[data-copy-label]").forEach((el) => {
      if (!el.classList.contains("done")) el.textContent = t(el.dataset.copyLabel);
    });
  }

  function setLang(lang) {
    if (!messages[lang]) return;
    try {
      localStorage.setItem(STORAGE_KEY, lang);
    } catch (e) {
      /* storage unavailable */
    }
    document.documentElement.lang = lang;
    applyTranslations();
    document.querySelectorAll("[data-lang]").forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.lang === lang);
      btn.setAttribute("aria-pressed", btn.dataset.lang === lang ? "true" : "false");
    });
  }

  function init() {
    setLang(currentLang());
    document.querySelectorAll("[data-lang]").forEach((btn) => {
      btn.addEventListener("click", () => setLang(btn.dataset.lang));
    });
  }

  global.I18N = { t, setLang, applyTranslations, currentLang, messages };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})(window);
