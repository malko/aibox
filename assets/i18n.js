/* AIBox — landing page i18n (no framework, no dependency).
   English is the default, French is a full translation. */

(function (global) {
  "use strict";

  const DEFAULT_LANG = "en";
  const STORAGE_KEY = "aiboxSiteLang";

  const messages = {
    en: {
      "meta.title": "AIBox — your AI, in its own box",
      "meta.description":
        "AIBox turns a KVM virtual machine into a self-hosted AI development box: one-command setup, a local web console, per-service tunnels and on-demand LAN exposure. Bash scripts, nothing in the cloud.",

      "nav.features": "features",
      "nav.how": "how it works",
      "nav.console": "console",
      "nav.commands": "commands",
      "nav.faq": "faq",
      "nav.menu": "menu",
      "nav.main": "Skip to content",
      "nav.sections": "Sections",
      "nav.language": "Language",

      "copy.label": "copy",
      "copy.done": "copied",

      "hero.badge": "open source · bash · nothing in the cloud",
      "hero.title": "Your AI, in its own",
      "hero.title.accent": "box.",
      "hero.lede":
        "AIBox turns a spare KVM virtual machine into a self-hosted AI development box: a guided setup, a local web console, and one tunnel per service that exposes exactly what you need — and nothing else.",
      "hero.cta.primary": "Get started",
      "hero.cta.secondary": "View on GitHub",
      "hero.cta.docs": "Read the docs",
      "hero.meta.1": "KVM / QEMU + libvirt",
      "hero.meta.2": "Ubuntu or Debian guest",
      "hero.meta.3": "per-service SSH tunnels",
      "hero.meta.4": "no cloud, no account",

      "features.kicker": "features",
      "features.title": "Everything the box needs, nothing it doesn't",
      "features.lede":
        "AIBox is a small set of shell scripts. It wires the virtual machine, the services and the network in one place, and stays out of the way afterwards.",
      "feature.1.title": "One-command setup",
      "feature.1.body":
        "A guided setup installs the guest, the SSH access, the services and the tunnel, step by step. Re-run any single step whenever you need it.",
      "feature.2.title": "A local web console",
      "feature.2.body":
        "Services, updates, setup steps, snapshots and the VM lifecycle live in a browser tab that never leaves your machine.",
      "feature.3.title": "One tunnel per service",
      "feature.3.body":
        "Each service gets its own port forward and its own bind address. Localhost by default, the network only when you ask for it.",
      "feature.4.title": "LAN exposure on demand",
      "feature.4.body":
        "Expose a single service to the network for half an hour or for good, per service, without opening the whole VM to the world.",
      "feature.5.title": "Snapshots",
      "feature.5.body":
        "Create, revert and delete VM snapshots from the command line or from the console, without losing your train of thought.",
      "feature.6.title": "VS Code Remote-SSH",
      "feature.6.body":
        "Open the shared folder in your own VS Code. The host path is mapped to the guest path for you, with nothing to write in ~/.ssh/config.",
      "feature.7.title": "Updates you can see",
      "feature.7.body":
        "Check the host and the VM for updates, then apply them one target at a time — a service, a script, the OS or all of them.",
      "feature.8.title": "Plain configuration",
      "feature.8.body":
        "Every setting lives in one readable config file, and the console speaks English and French. Nothing is hidden in a database.",

      "what.kicker": "what it is",
      "what.title": "Three pieces, one workflow",
      "what.lede": "AIBox is not a platform. It is the missing glue between a hypervisor, your services and your laptop.",
      "what.1.title": "The box",
      "what.1.body":
        "A KVM virtual machine on your own hardware, with a predictable user, a predictable home directory and a share mounted in both worlds.",
      "what.2.title": "The console",
      "what.2.body":
        "A local web interface that shows what runs, where it listens and what can be updated — and that can start, stop and snapshot the box.",
      "what.3.title": "The tunnels",
      "what.3.body":
        "A small user service that forwards one port per service over SSH, reconnects on its own and can be exposed to the LAN per service.",

      "how.kicker": "how it works",
      "how.title": "Three commands and you are in",
      "how.lede": "Clone the repository, run the setup, then pick how you want to work: the shell, the console or VS Code.",
      "how.step1.no": "step 1",
      "how.step1.title": "Set the box up",
      "how.step1.body":
        "The setup walks through the VM, SSH, the services and the tunnel. Every answer is saved, so a second run only asks what changed.",
      "how.step2.no": "step 2",
      "how.step2.title": "Connect to it",
      "how.step2.body":
        "One command opens an SSH session in the guest with every service already forwarded to the right local port.",
      "how.step3.no": "step 3",
      "how.step3.title": "Or drive it from the browser",
      "how.step3.body":
        "The local console shows the services with a live availability dot and gives you the VM controls, the snapshots and the updates.",
      "how.code1.title": "clone & setup",
      "how.code2.title": "connect",
      "how.code3.title": "web console",

      "network.kicker": "network",
      "network.title": "One entry point, many services",
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
      "network.tag2": "tunnel",
      "network.tag3": "per service",
      "network.tag4": "on demand",

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
      "commands.lede": "A dozen commands cover the whole life of the box. Everything is scriptable, nothing is interactive-only.",
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
      "req.lede": "A recent Linux host with KVM, and a guest image. That is the whole list.",
      "req.host.title": "host",
      "req.host.1": "KVM/QEMU with libvirt",
      "req.host.2": "<code>virsh</code> and <code>libvirt-client</code>",
      "req.host.3": "BusyBox <code>httpd</code> for the web console",
      "req.host.4": "macOS is supported through Lima",
      "req.guest.title": "guest",
      "req.guest.1": "Ubuntu or Debian, with SSH access",
      "req.guest.2": "4 GB of RAM, 4 cores recommended",
      "req.guest.3": "A dedicated user with sudo rights",
      "req.guest.4": "The share is mounted with virtiofs",

      "faq.kicker": "faq",
      "faq.title": "The questions people actually ask",
      "faq.lede": "Short answers, no marketing.",
      "faq.1.q": "Does any of my data leave the machine?",
      "faq.1.a": "No. The VM runs on your hardware, the console is served by BusyBox on your machine and the tunnels are plain SSH. There is no account, no telemetry and no cloud service in the loop.",
      "faq.2.q": "Do I need root on the host?",
      "faq.2.a": "Only for a few setup steps, and the console asks for the sudo password once, in memory, when a privileged step needs it. Everything else runs as your user.",
      "faq.3.q": "How do I reach a service from another device?",
      "faq.3.a": "Expose that service on the LAN: <code>aibox tunnel lan on opencode --permanent</code>. The tunnel binds the port on your network interface instead of localhost, for that service only.",
      "faq.4.q": "Can I run my own services?",
      "faq.4.a": "Yes. <code>aibox service-add mytool 8080</code> registers a port, and the tunnel, the console and the status output pick it up right away.",
      "faq.5.q": "How do I keep it up to date?",
      "faq.5.a": "<code>aibox check-updates</code> tells you what changed on the host and in the VM. <code>aibox update all</code> applies it, target by target, and <code>aibox self-update</code> refreshes the scripts themselves.",
      "faq.6.q": "Is it Linux only?",
      "faq.6.a": "The host scripts run on Linux. macOS is supported through Lima, where the VM runs in a lightweight virtual machine and the share is mounted under your home directory.",

      "cta.title": "Build your own box",
      "cta.lede":
        "One repository, a handful of shell scripts, and a virtual machine that behaves like a machine you own. Clone it, run the setup, and forget the plumbing.",
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
      "meta.title": "AIBox — votre IA, dans sa propre boîte",
      "meta.description":
        "AIBox transforme une machine virtuelle KVM en un poste de développement IA auto-hébergé : installation en une commande, console web locale, un tunnel par service et exposition réseau à la demande. Des scripts shell, rien dans le cloud.",

      "nav.features": "fonctionnalités",
      "nav.how": "principe",
      "nav.console": "console",
      "nav.commands": "commandes",
      "nav.faq": "questions",
      "nav.menu": "menu",
      "nav.main": "Aller au contenu",
      "nav.sections": "Sections",
      "nav.language": "Langue",

      "copy.label": "copier",
      "copy.done": "copié",

      "hero.badge": "open source · shell · rien dans le cloud",
      "hero.title": "Votre IA, dans sa propre",
      "hero.title.accent": "boîte.",
      "hero.lede":
        "AIBox transforme une machine virtuelle KVM inutilisée en un poste de développement IA auto-hébergé : une installation guidée, une console web locale, et un tunnel par service qui n'expose que ce dont vous avez besoin — rien d'autre.",
      "hero.cta.primary": "Commencer",
      "hero.cta.secondary": "Voir sur GitHub",
      "hero.cta.docs": "Lire la documentation",
      "hero.meta.1": "KVM / QEMU + libvirt",
      "hero.meta.2": "guest Ubuntu ou Debian",
      "hero.meta.3": "un tunnel SSH par service",
      "hero.meta.4": "pas de cloud, pas de compte",

      "features.kicker": "fonctionnalités",
      "features.title": "Tout ce dont la boîte a besoin, rien de plus",
      "features.lede":
        "AIBox est un petit ensemble de scripts shell. Ils relient la machine virtuelle, les services et le réseau en un seul endroit, puis s'effacent.",
      "feature.1.title": "Installation en une commande",
      "feature.1.body":
        "L'installation guide le guest, l'accès SSH, les services et le tunnel, étape par étape. Chaque étape se rejoue seule quand vous le voulez.",
      "feature.2.title": "Une console web locale",
      "feature.2.body":
        "Services, mises à jour, installation, snapshots et cycle de vie de la VM tiennent dans un onglet de navigateur qui ne quitte jamais votre machine.",
      "feature.3.title": "Un tunnel par service",
      "feature.3.body":
        "Chaque service a sa redirection de port et sa propre adresse d'écoute. Localhost par défaut, le réseau uniquement quand vous le demandez.",
      "feature.4.title": "Exposition réseau à la demande",
      "feature.4.body":
        "Exposez un seul service au réseau pour une demi-heure ou pour toujours, service par service, sans ouvrir la VM entière au monde.",
      "feature.5.title": "Snapshots",
      "feature.5.body":
        "Créez, restaurez et supprimez des snapshots depuis la ligne de commande ou la console, sans perdre le fil de ce que vous faites.",
      "feature.6.title": "VS Code en Remote-SSH",
      "feature.6.body":
        "Ouvrez le dossier partagé dans votre propre VS Code. Le chemin de l'hôte est converti en chemin guest, sans rien écrire dans ~/.ssh/config.",
      "feature.7.title": "Des mises à jour visibles",
      "feature.7.body":
        "Vérifiez l'hôte et la VM, puis appliquez ce qui change cible par cible : un service, un script, l'OS ou tout à la fois.",
      "feature.8.title": "Configuration lisible",
      "feature.8.body":
        "Tous les réglages tiennent dans un seul fichier de configuration que vous pouvez lire, et la console parle anglais et français. Rien n'est caché dans une base de données.",

      "what.kicker": "ce que c'est",
      "what.title": "Trois pièces, un seul flux de travail",
      "what.lede": "AIBox n'est pas une plateforme. C'est la colle qui manque entre l'hyperviseur, vos services et votre portable.",
      "what.1.title": "La boîte",
      "what.1.body":
        "Une machine virtuelle KVM sur votre propre matériel, avec un utilisateur prévisible, un home prévisible et un partage monté dans les deux mondes.",
      "what.2.title": "La console",
      "what.2.body":
        "Une interface web locale qui montre ce qui tourne, où ça écoute et ce qui peut être mis à jour — et qui démarre, arrête et snapshot la boîte.",
      "what.3.title": "Les tunnels",
      "what.3.body":
        "Un petit service utilisateur qui transfère un port par service en SSH, se reconnecte tout seul et peut être exposé au réseau service par service.",

      "how.kicker": "principe",
      "how.title": "Trois commandes et vous y êtes",
      "how.lede": "Clonez le dépôt, lancez l'installation, puis choisissez votre façon de travailler : le shell, la console ou VS Code.",
      "how.step1.no": "étape 1",
      "how.step1.title": "Installer la boîte",
      "how.step1.body":
        "L'installation passe par la VM, SSH, les services et le tunnel. Chaque réponse est mémorisée, donc une seconde exécution ne demande que ce qui a changé.",
      "how.step2.no": "étape 2",
      "how.step2.title": "Se connecter",
      "how.step2.body":
        "Une seule commande ouvre une session SSH dans le guest, avec chaque service déjà redirigé vers le bon port local.",
      "how.step3.no": "étape 3",
      "how.step3.title": "Ou piloter depuis le navigateur",
      "how.step3.body":
        "La console locale montre les services avec un point de disponibilité en direct, et donne accès au cycle de vie de la VM, aux snapshots et aux mises à jour.",
      "how.code1.title": "cloner et installer",
      "how.code2.title": "se connecter",
      "how.code3.title": "console web",

      "network.kicker": "réseau",
      "network.title": "Un seul point d'entrée, plusieurs services",
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
      "network.tag2": "tunnel",
      "network.tag3": "par service",
      "network.tag4": "à la demande",

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
      "commands.lede": "Une douzaine de commandes couvrent toute la vie de la boîte. Tout est scriptable, rien n'est propre au mode interactif.",
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
      "req.lede": "Un hôte Linux récent avec KVM, et une image guest. C'est toute la liste.",
      "req.host.title": "hôte",
      "req.host.1": "KVM/QEMU avec libvirt",
      "req.host.2": "<code>virsh</code> et <code>libvirt-client</code>",
      "req.host.3": "BusyBox <code>httpd</code> pour la console web",
      "req.host.4": "macOS est supporté via Lima",
      "req.guest.title": "guest",
      "req.guest.1": "Ubuntu ou Debian, accessible en SSH",
      "req.guest.2": "4 Go de RAM, 4 cœurs recommandés",
      "req.guest.3": "Un utilisateur dédié avec les droits sudo",
      "req.guest.4": "Le partage est monté en virtiofs",

      "faq.kicker": "questions",
      "faq.title": "Les questions que l'on pose vraiment",
      "faq.lede": "Des réponses courtes, sans discours.",
      "faq.1.q": "Est-ce que mes données quittent la machine ?",
      "faq.1.a": "Non. La VM tourne sur votre matériel, la console est servie par BusyBox sur votre machine et les tunnels sont du SSH pur. Aucun compte, aucune télémétrie, aucun service cloud dans la boucle.",
      "faq.2.q": "Faut-il être root sur l'hôte ?",
      "faq.2.a": "Seulement pour quelques étapes d'installation, et la console demande le mot de passe sudo une fois, en mémoire, quand une étape privilégiée en a besoin. Le reste tourne avec votre utilisateur.",
      "faq.3.q": "Comment accéder à un service depuis un autre appareil ?",
      "faq.3.a": "Exposez ce service sur le réseau : <code>aibox tunnel lan on opencode --permanent</code>. Le tunnel écoute alors sur l'interface réseau au lieu de localhost, pour ce service uniquement.",
      "faq.4.q": "Puis-je faire tourner mes propres services ?",
      "faq.4.a": "Oui. <code>aibox service-add mytool 8080</code> enregistre un port, et le tunnel, la console et la sortie de statut le reprennent immédiatement.",
      "faq.5.q": "Comment le garder à jour ?",
      "faq.5.a": "<code>aibox check-updates</code> indique ce qui a changé sur l'hôte et dans la VM. <code>aibox update all</code> l'applique, cible par cible, et <code>aibox self-update</code> met à jour les scripts eux-mêmes.",
      "faq.6.q": "C'est uniquement pour Linux ?",
      "faq.6.a": "Les scripts hôte fonctionnent sous Linux. macOS est supporté via Lima, où la VM tourne dans une machine virtuelle légère et le partage est monté sous votre home.",

      "cta.title": "Construisez votre propre boîte",
      "cta.lede":
        "Un dépôt, quelques scripts shell, et une machine virtuelle qui se comporte comme une machine qui vous appartient. Clonez, lancez l'installation, et oubliez la plomberie.",
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
