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
        "AIBox runs your AI agents in a virtual machine with its own kernel: the agent only reaches the files of the guest, the host stays untouched, and the box can be reset or thrown away.",

      "nav.model": "the model",
      "nav.isolation": "vm / container",
      "nav.practices": "good practices",
      "nav.how": "how it works",
      "nav.console": "console",
      "nav.faq": "faq",
      "nav.menu": "menu",
      "nav.main": "Skip to content",
      "nav.sections": "Sections",
      "nav.language": "Language",

      "copy.label": "copy",
      "copy.done": "copied",

      "hero.badge": "a virtual machine for your AI agents",
      "hero.title": "Your agent works in a VM.",
      "hero.title.accent": "Not on your machine.",
      "hero.lede":
        "An agent is a shell with your permissions, and it does whatever the prompt asks. AIBox runs it inside a virtual machine with its own kernel, its own filesystem and no way back: the only thing it shares with the host is the folder you choose.",
      "hero.cta.primary": "Get started",
      "hero.cta.secondary": "View on GitHub",
      "hero.cta.docs": "Read the docs",
      "hero.meta.1": "KVM / QEMU + libvirt",
      "hero.meta.2": "its own kernel",
      "hero.meta.3": "outbound traffic only",
      "hero.meta.4": "nothing collected, nothing in the cloud",

      "model.kicker": "the model",
      "model.title": "One shared folder, and the agent stays inside",
      "model.lede":
        "The day to day workflow is deliberately narrow. AIBox sets up a virtual machine, shares one directory with it, and gives the agent the harnesses it needs. Everything else stays where it belongs.",
      "model.card1.tag": "step 1",
      "model.card1.title": "A folder, shared both ways",
      "model.card1.body":
        "The host share is mounted in the guest with virtiofs. The agent works there, exactly as it would work in a directory on your machine.",
      "model.card1.1": "The agent reads and writes the shared folder, and nothing else",
      "model.card1.2": "Your keys, your SSH agent, your cloud credentials stay on the host",
      "model.card1.3": "The folder is yours to choose: a worktree, a scratch space, a repo",
      "model.card2.tag": "step 2",
      "model.card2.title": "Local commits, and you push",
      "model.card2.body":
        "Without credentials in the guest, the agent can commit but it cannot push. You keep the last word on what leaves your machine.",
      "model.card2.1": "The agent commits locally in the shared folder",
      "model.card2.2": "It has no git credentials, so it cannot push to your remotes",
      "model.card2.3": "You read the diff and push, from the host, with your own keys",
      "model.note":
        "AIBox is not a sandbox that certifies anything. It is a boundary that is easy to set up and hard to cross by accident: the guest has its own kernel, the host filesystem is not in its namespace, and the network is outbound only unless you open it yourself.",

      "isolation.kicker": "isolation",
      "isolation.title": "What actually separates the agent from your machine",
      "isolation.lede":
        "The same agent, in three places. The difference is not a policy file, it is what the kernel and the hypervisor enforce.",
      "isolation.head.what": "what",
      "isolation.head.host": "on your machine",
      "isolation.head.docker": "in a container",
      "isolation.head.vm": "in a virtual machine",
      "isolation.row1.label": "Kernel",
      "isolation.row1.host": "The host kernel, with your uid",
      "isolation.row1.docker": "The host kernel, shared with the host",
      "isolation.row1.vm": "Its own kernel, in the guest",
      "isolation.row2.label": "Files",
      "isolation.row2.host": "Everything your user can read",
      "isolation.row2.docker": "The host filesystem, unless you mount it carefully",
      "isolation.row2.vm": "Only the guest filesystem",
      "isolation.row3.label": "Credentials",
      "isolation.row3.host": "SSH keys, cloud credentials, browser sessions",
      "isolation.row3.docker": "The same, as soon as you mount the home or pass a socket",
      "isolation.row3.vm": "None, unless you put them there",
      "isolation.row4.label": "Devices",
      "isolation.row4.host": "The real ones, with your permissions",
      "isolation.row4.docker": "The host devices, when the runtime is not careful",
      "isolation.row4.vm": "Emulated, through the hypervisor",
      "isolation.row5.label": "Network",
      "isolation.row5.host": "Your network, your host name, your ports",
      "isolation.row5.docker": "Your network, with a bridge or host mode",
      "isolation.row5.vm": "NAT, outbound only, inbound closed",
      "isolation.row6.label": "Escape",
      "isolation.row6.host": "No escape needed, it is already there",
      "isolation.row6.docker": "A kernel or runtime flaw is a host compromise",
      "isolation.row6.vm": "The guest kernel is the wall, root included",
      "isolation.row7.label": "Blast radius",
      "isolation.row7.host": "Your workstation",
      "isolation.row7.docker": "Your workstation",
      "isolation.row7.vm": "One disk image you can throw away",
      "isolation.scroll": "Scroll the table to see the three columns.",
      "isolation.note":
        "A container is the right tool to isolate a build. It is a configuration, not a guarantee: the usual development setups bind the home directory, mount the Docker socket, or run with extra capabilities, and each of those puts the host back in reach. A virtual machine moves the boundary into the kernel, where the agent has no say.",

      "practices.kicker": "good practices",
      "practices.title": "How to use the box without shooting yourself in the foot",
      "practices.lede":
        "The box protects the host from the agent. It does not protect the agent from the internet, and it does not protect you from your own habits. A few rules keep the value high.",
      "practice.1.title": "Never put your keys in the guest",
      "practice.1.body":
        "No SSH key, no git credential, no <code>~/.aws</code>, no token file. The guest is the one place you cannot watch. An agent that finds a key will use it.",
      "practice.2.title": "Share only what the task needs",
      "practice.2.body":
        "The share is the one door between the host and the agent. A worktree for the current task is enough; sharing your whole home is not.",
      "practice.3.title": "Keep the box closed to the network",
      "practice.3.body":
        "The guest is behind NAT: it can reach the internet, the internet cannot reach it. Leave it that way unless you need a service to be reachable, and open it per service.",
      "practice.4.title": "Snapshot before a risky run",
      "practice.4.body":
        "A snapshot takes seconds and gives you a way back. A broken agent becomes an interesting state to look at instead of a lost afternoon.",
      "practice.5.title": "Read the diff before you push",
      "practice.5.body":
        "The agent commits locally because it has no credentials. That is the point: you are the one deciding what goes out.",
      "practice.6.title": "Know what the agent can still reach",
      "practice.6.body":
        "The agent has outbound internet access, like any program you run. AIBox collects nothing and sends nothing, but what the agent does with the network is between you and your provider.",

      "playground.kicker": "playground",
      "playground.title": "A box you can break, reset and throw away",
      "playground.lede":
        "Setting up a sandboxed agent environment is not hard, but it is tedious, and it is easy to get wrong. AIBox does the boring part so that managing the box is not a second project.",
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
      "feature.6.title": "VS Code, two ways",
      "feature.6.body":
        "The Remote-SSH extension on your VS Code, or the VS Code Server running inside the guest. Both are installed for you.",
      "feature.7.title": "The harnesses, wired",
      "feature.7.body":
        "Everything needed to install, update and expose opencode, Claude Code and the DeepSeek Harness is already handled.",
      "feature.8.title": "Easy updates",
      "feature.8.body":
        "Check the host and the VM, then update a service, the scripts, the OS or all of them, one target at a time.",

      "network.kicker": "network",
      "network.title": "Outbound by default, one door in",
      "network.lede":
        "The VM sits behind NAT. It can reach the internet, the internet cannot reach it, and the only path from your machine to the guest is the SSH tunnel.",
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
        "The setup creates the guest image, generates a key pair for it, installs the packages, the services and the tunnel, and shares the folder. Every answer is saved, so a second run only asks what changed.",
      "how.step2.no": "step 2",
      "how.step2.title": "Open a shell in the guest",
      "how.step2.body":
        "One command opens an SSH session in the virtual machine, with every service already forwarded to the right local port. This is where your agent works.",
      "how.step3.no": "step 3",
      "how.step3.title": "Or drive the box from the browser",
      "how.step3.body":
        "The local console shows the services with a live availability dot, and gives you the VM controls, the snapshots and the updates. It stops when you close the tab.",
      "how.code1.title": "clone & setup",
      "how.code2.title": "connect",
      "how.code3.title": "web console",
      "how.note":
        "The tunnel is a systemd user service, so it comes back with your session even without a terminal. The virtual machine itself is <b>not</b> started automatically: the host does not restart it after a reboot, and you start it with <code>aibox start</code>.",

      "console.kicker": "the console",
      "console.title": "A convenience, not a service",
      "console.lede":
        "The console exists for the people who would rather click than type, and for the moments when a browser is nicer than a terminal. It is not something you are meant to leave running.",
      "console.practice1.title": "It stops with the tab",
      "console.practice1.body":
        "Closing the browser tab asks the console to stop, a few seconds later. There is no daemon left behind, and no port left open.",
      "console.practice2.title": "It listens on 127.0.0.1 only",
      "console.practice2.body":
        "The console is never reachable from the network. When the configured port is busy, it takes the next free one instead of failing.",
      "console.practice3.title": "A token per session",
      "console.practice3.body":
        "A random token is generated at every start and passed in the URL fragment. The API also rejects foreign Host and Origin headers, so another site cannot drive your console.",
      "console.practice4.title": "The root password is asked, never kept",
      "console.practice4.body":
        "A step that needs sudo asks for the password at that moment. It stays in one shell variable for that step, is never written to a file, never appears in a command line, and is gone when the step ends.",
      "console.1.title": "Overview",
      "console.1.body":
        "VM and tunnel state, the services that answer, and the buttons to start, stop or restart the box.",
      "console.2.title": "Services",
      "console.2.body":
        "Every service with its port, its local URL and its LAN exposure, plus a live dot that tells you if it really listens.",
      "console.3.title": "Snapshots",
      "console.3.body":
        "Create a snapshot before a risky change, list the ones you have, revert or delete them in a click.",

      "vscode.kicker": "vs code",
      "vscode.title": "Two ways to open the guest",
      "vscode.lede":
        "Both are supported, and both are installed for you. Pick the one that fits how you work.",
      "vscode.card1.tag": "remote-ssh",
      "vscode.card1.title": "Your VS Code, over SSH",
      "vscode.card1.body":
        "The Remote-SSH extension connects to the guest through the same tunnel as everything else. The host path is mapped to the guest path, so you open a local folder and edit it remotely.",
      "vscode.card1.1": "Your own VS Code, your own settings, your own extensions",
      "vscode.card1.2": "<code>aibox vscode</code> opens it on the right folder",
      "vscode.card2.tag": "vs code server",
      "vscode.card2.title": "The server, inside the guest",
      "vscode.card2.body":
        "The setup installs the VS Code Server in the guest, so a browser based VS Code can run entirely inside the virtual machine.",
      "vscode.card2.1": "The editor itself runs in the guest, not on your host",
      "vscode.card2.2": "Kept up to date with <code>aibox update vscode-server</code>",

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
        "macOS is not supported yet: the Lima based support is being finished, and it will land here. Windows is not planned, the host scripts assume a Linux system with libvirt.",

      "faq.kicker": "faq",
      "faq.title": "The questions people actually ask",
      "faq.lede": "Short answers, including the limits.",
      "faq.1.q": "Can the agent reach my files?",
      "faq.1.a": "Only the ones in the shared folder, and the ones inside the guest. Your SSH keys, your browser sessions and the rest of the workstation are not in the guest's filesystem.",
      "faq.2.q": "Why a virtual machine and not Docker?",
      "faq.2.a": "A container shares the host kernel and, in most development setups, the host home directory or the Docker socket. A virtual machine has its own kernel, and the host filesystem is simply not in its namespace. For a build, a container is enough. For an agent that writes and runs its own code, the boundary has to be below the process.",
      "faq.3.q": "Is the box really isolated?",
      "faq.3.a": "It is a boundary, not a proof. The share is a real door, the agent has outbound internet access, and a bridged network or a forwarded port would open the guest. What AIBox does is make the safe configuration the default one, and the unsafe one something you have to ask for explicitly.",
      "faq.4.q": "Does the agent have internet access?",
      "faq.4.a": "Yes, like any program you run: the guest is behind NAT, so it can reach the internet and the internet cannot reach it. AIBox itself collects nothing and sends nothing, but what your agent does with the network depends on your provider and on you.",
      "faq.5.q": "What if the agent breaks everything?",
      "faq.5.a": "You take a snapshot before it starts, and you revert it afterwards. The broken state stays available to look at, and the host never saw any of it.",
      "faq.6.q": "Is the web console a service I should leave running?",
      "faq.6.a": "No. It is a foreground command: it listens on 127.0.0.1 only, and it stops shortly after you close the tab. The token it needs is generated at every start, and the API rejects foreign Host and Origin headers.",
      "faq.7.q": "Does the box start with my computer?",
      "faq.7.a": "The tunnel is a systemd user service, so it starts with your session. The virtual machine is not started for you: a host reboot leaves it off, and you bring it up with <code>aibox start</code>.",
      "faq.8.q": "Does any of my data leave the machine?",
      "faq.8.a": "AIBox does not collect, store or send anything: the VM runs on your hardware, the console is served by BusyBox on your machine and the tunnels are plain SSH. The agent, on the other hand, has the same internet access as any program you run.",
      "faq.9.q": "Is macOS supported? Is Windows?",
      "faq.9.a": "macOS is on the way: the Lima based support is being finished. Windows is not planned, the host scripts assume a Linux system with libvirt.",
      "faq.10.q": "Can I run my own services?",
      "faq.10.a": "Yes. <code>aibox service-add mytool 8080</code> registers a port, and the tunnel, the console and the status output pick it up right away.",
      "faq.11.q": "How do I reach a service from another device?",
      "faq.11.a": "Expose it on the LAN with <code>aibox tunnel lan on opencode</code>. The exposure is temporary by default: it reverts on its own after a couple of hours, and it is always lost on reboot. If a service really has to stay reachable, ask for it explicitly: AIBox then keeps the setting in the configuration and applies it again on the next start. The tunnel binds the port on your network interface instead of localhost, for that service only.",
      "faq.12.q": "Do I need root on the host?",
      "faq.12.a": "Only for a few setup steps, and the password is asked at that moment. It is never written to a file, never passed on a command line and never kept after the step ends.",

      "cta.title": "Give your agent a box to work in",
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
        "AIBox exécute vos agents IA dans une machine virtuelle dotée de son propre noyau : l'agent n'accède qu'aux fichiers du guest, l'hôte reste intact, et la boîte peut être réinitialisée puis jetée.",

      "nav.model": "modèle",
      "nav.isolation": "vm / conteneur",
      "nav.practices": "pratiques",
      "nav.how": "principe",
      "nav.console": "console",
      "nav.faq": "questions",
      "nav.menu": "menu",
      "nav.main": "Aller au contenu",
      "nav.sections": "Sections",
      "nav.language": "Langue",

      "copy.label": "copier",
      "copy.done": "copié",

      "hero.badge": "une machine virtuelle pour vos agents IA",
      "hero.title": "Votre agent travaille dans une VM.",
      "hero.title.accent": "Pas sur votre machine.",
      "hero.lede":
        "Un agent, c'est un shell avec vos permissions, et il fait ce que le prompt lui demande. AIBox l'exécute dans une machine virtuelle avec son propre noyau, son propre système de fichiers et aucun chemin de retour : la seule chose qu'il partage avec l'hôte, c'est le dossier que vous choisissez.",
      "hero.cta.primary": "Commencer",
      "hero.cta.secondary": "Voir sur GitHub",
      "hero.cta.docs": "Lire la documentation",
      "hero.meta.1": "KVM / QEMU + libvirt",
      "hero.meta.2": "son propre noyau",
      "hero.meta.3": "trafic sortant uniquement",
      "hero.meta.4": "rien de collecté, rien dans le cloud",

      "model.kicker": "le modèle",
      "model.title": "Un dossier partagé, et l'agent reste dedans",
      "model.lede":
        "Le flux de travail quotidien est volontairement étroit. AIBox met en place une machine virtuelle, lui partage un répertoire, et donne à l'agent les harnais dont il a besoin. Tout le reste reste à sa place.",
      "model.card1.tag": "étape 1",
      "model.card1.title": "Un dossier partagé dans les deux sens",
      "model.card1.body":
        "Le partage de l'hôte est monté dans le guest en virtiofs. L'agent y travaille, exactement comme il travaillerait dans un dossier de votre machine.",
      "model.card1.1": "L'agent lit et écrit le dossier partagé, et rien d'autre",
      "model.card1.2": "Vos clés, votre agent SSH, vos identifiants cloud restent sur l'hôte",
      "model.card1.3": "Le dossier est à vous : un worktree, un espace de travail, un dépôt",
      "model.card2.tag": "étape 2",
      "model.card2.title": "Des commits locaux, et vous poussez",
      "model.card2.body":
        "Sans identifiants dans le guest, l'agent peut commiter mais il ne peut pas pousser. Vous gardez le dernier mot sur ce qui sort de votre machine.",
      "model.card2.1": "L'agent commite localement dans le dossier partagé",
      "model.card2.2": "Il n'a pas d'identifiants git, il ne peut pas pousser vers vos dépôts",
      "model.card2.3": "Vous relisez le diff et vous poussez, depuis l'hôte, avec vos clés",
      "model.note":
        "AIBox n'est pas un bac à sable qui certifie quoi que ce soit. C'est une frontière facile à mettre en place et difficile à franchir par accident : le guest a son propre noyau, le système de fichiers de l'hôte n'est pas dans son espace de noms, et le réseau est sortant tant que vous ne l'ouvrez pas vous-même.",

      "isolation.kicker": "isolation",
      "isolation.title": "Ce qui sépare réellement l'agent de votre machine",
      "isolation.lede":
        "Le même agent, à trois endroits. La différence n'est pas un fichier de politique, c'est ce que le noyau et l'hyperviseur imposent.",
      "isolation.head.what": "quoi",
      "isolation.head.host": "sur votre machine",
      "isolation.head.docker": "dans un conteneur",
      "isolation.head.vm": "dans une machine virtuelle",
      "isolation.row1.label": "Noyau",
      "isolation.row1.host": "Le noyau de l'hôte, avec votre uid",
      "isolation.row1.docker": "Le noyau de l'hôte, partagé avec lui",
      "isolation.row1.vm": "Le sien, dans le guest",
      "isolation.row2.label": "Fichiers",
      "isolation.row2.host": "Tout ce que votre utilisateur peut lire",
      "isolation.row2.docker": "Le système de l'hôte, sauf montage très prudent",
      "isolation.row2.vm": "Seulement le système du guest",
      "isolation.row3.label": "Identifiants",
      "isolation.row3.host": "Clés SSH, identifiants cloud, sessions de navigateur",
      "isolation.row3.docker": "Les mêmes, dès que vous montez le home ou un socket",
      "isolation.row3.vm": "Aucun, sauf si vous les mettez là",
      "isolation.row4.label": "Périphériques",
      "isolation.row4.host": "Les vrais, avec vos permissions",
      "isolation.row4.docker": "Les périphériques de l'hôte, quand le runtime est laxiste",
      "isolation.row4.vm": "Émulés, via l'hyperviseur",
      "isolation.row5.label": "Réseau",
      "isolation.row5.host": "Votre réseau, votre nom d'hôte, vos ports",
      "isolation.row5.docker": "Votre réseau, en bridge ou en mode host",
      "isolation.row5.vm": "NAT, sortant seulement, entrant fermé",
      "isolation.row6.label": "Évasion",
      "isolation.row6.host": "Aucune évasion nécessaire, il est déjà là",
      "isolation.row6.docker": "Un flaw du noyau ou du runtime est une compromission de l'hôte",
      "isolation.row6.vm": "Le noyau du guest est le mur, root compris",
      "isolation.row7.label": "Rayon d'impact",
      "isolation.row7.host": "Votre poste de travail",
      "isolation.row7.docker": "Votre poste de travail",
      "isolation.row7.vm": "Une image disque que vous pouvez jeter",
      "isolation.scroll": "Faites défiler le tableau pour voir les trois colonnes.",
      "isolation.note":
        "Un conteneur est le bon outil pour isoler une compilation. C'est une configuration, pas une garantie : les setups de développement habituels montent le dossier home, le socket Docker, ou tournent avec des capabilities supplémentaires, et chacune de ces pratiques remet l'hôte à portée. Une machine virtuelle descend la frontière dans le noyau, là où l'agent n'a rien à dire.",

      "practices.kicker": "bonnes pratiques",
      "practices.title": "Utiliser la boîte sans se tirer une balle dans le pied",
      "practices.lede":
        "La boîte protège l'hôte de l'agent. Elle ne protège pas l'agent d'internet, ni vous de vos propres habitudes. Quelques règles suffisent à garder la valeur intacte.",
      "practice.1.title": "Ne mettez jamais vos clés dans le guest",
      "practice.1.body":
        "Ni clé SSH, ni identifiant git, ni <code>~/.aws</code>, ni fichier de token. Le guest est le seul endroit que vous ne surveillez pas. Un agent qui trouve une clé s'en sert.",
      "practice.2.title": "Ne partagez que ce dont la tâche a besoin",
      "practice.2.body":
        "Le partage est la seule porte entre l'hôte et l'agent. Un worktree pour la tâche en cours suffit ; partager tout votre home, non.",
      "practice.3.title": "Gardez la boîte fermée au réseau",
      "practice.3.body":
        "Le guest est derrière un NAT : il atteint internet, internet ne l'atteint pas. Laissez-le ainsi, sauf si un service doit être joignable, et ouvrez-le service par service.",
      "practice.4.title": "Faites un snapshot avant une exécution risquée",
      "practice.4.body":
        "Un snapshot prend quelques secondes et vous donne une voie de retour. Un agent cassé devient un état intéressant à examiner plutôt qu'un après-midi perdu.",
      "practice.5.title": "Relisez le diff avant de pousser",
      "practice.5.body":
        "L'agent commite localement parce qu'il n'a pas d'identifiants. C'est le but : c'est vous qui décidez de ce qui sort.",
      "practice.6.title": "Sachez ce que l'agent peut encore atteindre",
      "practice.6.body":
        "L'agent a un accès internet sortant, comme n'importe quel programme que vous lancez. AIBox ne collecte rien et n'envoie rien, mais ce que l'agent fait du réseau relève de votre fournisseur et de vous.",

      "playground.kicker": "bac à sable",
      "playground.title": "Une boîte que l'on casse, réinitialise et jette",
      "playground.lede":
        "Mettre en place un environnement confiné pour un agent n'est pas difficile, mais c'est fastidieux, et c'est facile à rater. AIBox fait la partie boring pour que gérer la boîte ne devienne pas un second projet.",
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
      "feature.6.title": "VS Code, deux façons",
      "feature.6.body":
        "L'extension Remote-SSH sur votre VS Code, ou le VS Code Server qui tourne dans le guest. Les deux sont installés pour vous.",
      "feature.7.title": "Les harnais, câblés",
      "feature.7.body":
        "Tout ce qu'il faut pour installer, mettre à jour et exposer opencode, Claude Code et le DeepSeek Harness est déjà pris en charge.",
      "feature.8.title": "Des mises à jour simples",
      "feature.8.body":
        "Vérifiez l'hôte et la VM, puis mettez à jour un service, les scripts, l'OS ou tout à la fois, cible par cible.",

      "network.kicker": "réseau",
      "network.title": "Sortant par défaut, une seule porte",
      "network.lede":
        "La VM est derrière un NAT. Elle atteint internet, internet ne l'atteint pas, et le seul chemin de votre machine vers le guest est le tunnel SSH.",
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
        "L'installation crée l'image du guest, génère une paire de clés pour lui, installe les paquets, les services et le tunnel, et partage le dossier. Chaque réponse est mémorisée, donc une seconde exécution ne demande que ce qui a changé.",
      "how.step2.no": "étape 2",
      "how.step2.title": "Ouvrir un shell dans le guest",
      "how.step2.body":
        "Une seule commande ouvre une session SSH dans la machine virtuelle, chaque service déjà redirigé vers le bon port local. C'est là que votre agent travaille.",
      "how.step3.no": "étape 3",
      "how.step3.title": "Ou piloter la boîte depuis le navigateur",
      "how.step3.body":
        "La console locale montre les services avec un point de disponibilité en direct, et donne accès au cycle de vie de la VM, aux snapshots et aux mises à jour. Elle s'arrête quand vous fermez l'onglet.",
      "how.code1.title": "cloner et installer",
      "how.code2.title": "se connecter",
      "how.code3.title": "console web",
      "how.note":
        "Le tunnel est un service utilisateur systemd, il revient donc avec votre session même sans terminal. La machine virtuelle, elle, <b>n'est pas</b> démarrée automatiquement : l'hôte ne la relance pas après un redémarrage, et vous la lancez avec <code>aibox start</code>.",

      "console.kicker": "la console",
      "console.title": "Une commodité, pas un service",
      "console.lede":
        "La console existe pour ceux qui préfèrent cliquer plutôt que taper, et pour les moments où un navigateur est plus agréable qu'un terminal. Ce n'est pas un truc que l'on laisse tourner.",
      "console.practice1.title": "Elle s'arrête avec l'onglet",
      "console.practice1.body":
        "Fermer l'onglet du navigateur demande à la console de s'arrêter, quelques secondes plus tard. Aucun daemon ne reste derrière, aucun port ne reste ouvert.",
      "console.practice2.title": "Elle n'écoute que sur 127.0.0.1",
      "console.practice2.body":
        "La console n'est jamais joignable depuis le réseau. Quand le port configuré est occupé, elle prend le suivant libre au lieu d'échouer.",
      "console.practice3.title": "Un token par session",
      "console.practice3.body":
        "Un token aléatoire est généré à chaque démarrage et passé dans le fragment de l'URL. L'API refuse aussi les en-têtes Host et Origin étrangers, donc un autre site ne peut pas piloter votre console.",
      "console.practice4.title": "Le mot de passe root est demandé, jamais gardé",
      "console.practice4.body":
        "Une étape qui a besoin de sudo demande le mot de passe à ce moment-là. Il reste dans une variable shell pour cette étape, n'est jamais écrit dans un fichier, n'apparaît jamais dans une ligne de commande, et disparaît à la fin de l'étape.",
      "console.1.title": "Vue d'ensemble",
      "console.1.body":
        "L'état de la VM et du tunnel, les services qui répondent, et les boutons pour démarrer, arrêter ou redémarrer la boîte.",
      "console.2.title": "Services",
      "console.2.body":
        "Chaque service avec son port, son URL locale et son exposition réseau, plus un point en direct qui indique s'il écoute vraiment.",
      "console.3.title": "Snapshots",
      "console.3.body":
        "Créez un snapshot avant un changement risqué, listez ceux que vous avez, restaurez-les ou supprimez-les en un clic.",

      "vscode.kicker": "vs code",
      "vscode.title": "Deux façons d'ouvrir le guest",
      "vscode.lede":
        "Les deux sont supportées, et les deux sont installées pour vous. Prenez celle qui colle à votre façon de travailler.",
      "vscode.card1.tag": "remote-ssh",
      "vscode.card1.title": "Votre VS Code, en SSH",
      "vscode.card1.body":
        "L'extension Remote-SSH se connecte au guest par le même tunnel que tout le reste. Le chemin de l'hôte est converti en chemin guest : vous ouvrez un dossier local et vous éditez à distance.",
      "vscode.card1.1": "Votre VS Code, vos réglages, vos extensions",
      "vscode.card1.2": "<code>aibox vscode</code> l'ouvre sur le bon dossier",
      "vscode.card2.tag": "vs code server",
      "vscode.card2.title": "Le serveur, dans le guest",
      "vscode.card2.body":
        "L'installation met le VS Code Server dans le guest, pour qu'un VS Code Based sur navigateur tourne entièrement dans la machine virtuelle.",
      "vscode.card2.1": "L'éditeur lui-même tourne dans le guest, pas sur votre hôte",
      "vscode.card2.2": "Mis à jour avec <code>aibox update vscode-server</code>",

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
        "macOS n'est pas encore supporté : le support basé sur Lima est en cours de finition, et il atterrira ici. Windows n'est pas prévu, les scripts hôte supposent un système Linux avec libvirt.",

      "faq.kicker": "questions",
      "faq.title": "Les questions que l'on pose vraiment",
      "faq.lede": "Des réponses courtes, limites comprises.",
      "faq.1.q": "L'agent peut-il atteindre mes fichiers ?",
      "faq.1.a": "Seulement ceux du dossier partagé, et ceux du guest. Vos clés SSH, vos sessions de navigateur et le reste du poste de travail ne sont pas dans le système de fichiers du guest.",
      "faq.2.q": "Pourquoi une machine virtuelle et pas Docker ?",
      "faq.2.a": "Un conteneur partage le noyau de l'hôte et, dans la plupart des setups de développement, le dossier home de l'hôte ou le socket Docker. Une machine virtuelle a son propre noyau, et le système de fichiers de l'hôte n'est tout simplement pas dans son espace de noms. Pour une compilation, un conteneur suffit. Pour un agent qui écrit et exécute son propre code, la frontière doit être sous le processus.",
      "faq.3.q": "La boîte est-elle vraiment isolée ?",
      "faq.3.a": "C'est une frontière, pas une preuve. Le partage est une vraie porte, l'agent a un accès internet sortant, et un réseau bridge ou un port redirigé ouvrirait le guest. Ce que fait AIBox, c'est rendre la configuration sûre celle par défaut, et l'autre quelque chose que vous demandez explicitement.",
      "faq.4.q": "L'agent a-t-il un accès internet ?",
      "faq.4.a": "Oui, comme n'importe quel programme que vous lancez : le guest est derrière un NAT, il atteint internet et internet ne l'atteint pas. AIBox en revanche ne collecte rien et n'envoie rien, mais ce que votre agent fait du réseau dépend de votre fournisseur et de vous.",
      "faq.5.q": "Et si l'agent casse tout ?",
      "faq.5.a": "Vous prenez un snapshot avant qu'il commence, et vous revenez en arrière après. L'état cassé reste disponible pour l'examiner, et l'hôte n'en a jamais rien vu.",
      "faq.6.q": "La console web est-elle un service à laisser tourner ?",
      "faq.6.a": "Non. C'est une commande de premier plan : elle n'écoute que sur 127.0.0.1, et elle s'arrête peu après la fermeture de l'onglet. Le token dont elle a besoin est généré à chaque démarrage, et l'API refuse les en-têtes Host et Origin étrangers.",
      "faq.7.q": "La boîte démarre-t-elle avec mon ordinateur ?",
      "faq.7.a": "Le tunnel est un service utilisateur systemd, il démarre donc avec votre session. La machine virtuelle n'est pas démarrée pour vous : un redémarrage de l'hôte la laisse éteinte, et vous la lancez avec <code>aibox start</code>.",
      "faq.8.q": "Est-ce que mes données quittent la machine ?",
      "faq.8.a": "AIBox ne collecte, ne stocke et n'envoie rien : la VM tourne sur votre matériel, la console est servie par BusyBox sur votre machine et les tunnels sont du SSH pur. L'agent, en revanche, a le même accès internet que n'importe quel programme que vous lancez.",
      "faq.9.q": "macOS est-il supporté ? Et Windows ?",
      "faq.9.a": "macOS est en chemin : le support basé sur Lima est en cours de finition. Windows n'est pas prévu, les scripts hôte supposent un système Linux avec libvirt.",
      "faq.10.q": "Puis-je faire tourner mes propres services ?",
      "faq.10.a": "Oui. <code>aibox service-add mytool 8080</code> enregistre un port, et le tunnel, la console et la sortie de statut le reprennent immédiatement.",
      "faq.11.q": "Comment accéder à un service depuis un autre appareil ?",
      "faq.11.a": "Exposez-le sur le réseau avec <code>aibox tunnel lan on opencode</code>. L'exposition est temporaire par défaut : elle revient toute seule après quelques heures, et elle est toujours perdue au redémarrage. Si un service doit vraiment rester joignable, demandez-le explicitement : AIBox garde alors le réglage dans la configuration et le réapplique au prochain démarrage. Le tunnel écoute sur l'interface réseau au lieu de localhost, pour ce service uniquement.",
      "faq.12.q": "Faut-il être root sur l'hôte ?",
      "faq.12.a": "Seulement pour quelques étapes d'installation, et le mot de passe est demandé à ce moment-là. Il n'est jamais écrit dans un fichier, jamais passé sur une ligne de commande, et jamais gardé après l'étape.",

      "cta.title": "Donnez à votre agent une boîte où travailler",
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
