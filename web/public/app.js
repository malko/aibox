/* AIBox local web console — no framework, no external dependency. */

const TOKEN_KEY = "aiboxWebToken";

const state = {
  token: "",
  status: null,
  updates: null,
  setup: null,
  activeJob: null,
  jobTimer: null,
  jobLogEl: null,
  lastError: "",
  quitting: false,
  sessionId: "",
};

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

function el(tag, props = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (value === null || value === undefined) continue;
    if (key === "className") node.className = value;
    else if (key === "text") node.textContent = value;
    else if (key === "dataset") Object.assign(node.dataset, value);
    else if (key === "value") node.value = value;
    else if (key === "checked" || key === "disabled") node[key] = Boolean(value);
    else node.setAttribute(key, value);
  }
  for (const child of children.flat()) {
    if (child === null || child === undefined || child === false) continue;
    node.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return node;
}

function initToken() {
  const match = window.location.hash.match(/[#&]token=([a-fA-F0-9]+)/);
  if (match) {
    localStorage.setItem(TOKEN_KEY, match[1]);
    history.replaceState(null, "", window.location.pathname + window.location.search);
  }
  state.token = localStorage.getItem(TOKEN_KEY) || "";
}

function newSessionId() {
  if (window.crypto?.randomUUID) {
    return window.crypto.randomUUID().replace(/-/g, "");
  }
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

async function registerSession() {
  if (!state.token) return;
  state.sessionId = newSessionId();
  try {
    await api("session", { method: "POST", body: { id: state.sessionId } });
  } catch {
    // Keep the page usable; the explicit quit button still works.
  }
}

async function cancelPendingQuit() {
  if (!state.token) return;
  try {
    await api("quit/cancel", { method: "POST" });
  } catch {
    // No pending quit, or the server is already stopping.
  }
}

async function api(path, options = {}) {
  if (!state.token) {
    throw new Error("Token absent. Relance `aibox web` pour ouvrir l'interface.");
  }

  const headers = {
    Authorization: `Bearer ${state.token}`,
    ...(options.headers || {}),
  };
  let body;
  if (options.body !== undefined) {
    headers["Content-Type"] = "application/json";
    body = JSON.stringify(options.body);
  }

  const response = await fetch(`/cgi-bin/api.sh/${path}`, {
    method: options.method || "GET",
    headers,
    body,
    cache: "no-store",
  });

  let data;
  try {
    data = await response.json();
  } catch {
    throw new Error(`réponse invalide du serveur (HTTP ${response.status})`);
  }

  if (!response.ok || data.ok === false) {
    if (response.status === 401) {
      throw new Error("Token invalide. Relance `aibox web` pour obtenir un nouveau lien.");
    }
    throw new Error(data.error || `HTTP ${response.status}`);
  }
  return data;
}

let toastTimer = null;
function toast(message, isError = false) {
  const node = $("#toast");
  node.textContent = message;
  node.classList.toggle("error", Boolean(isError));
  node.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => node.classList.remove("show"), isError ? 6500 : 3500);
}

function closeDialog() {
  const dialog = $("#dialog");
  if (dialog.open) dialog.close();
  state.jobLogEl = null;
}

function openDialog({ title, body, actions = [] }) {
  const dialog = $("#dialog");
  if (dialog.open) dialog.close();

  $("#dialog-title").textContent = title;
  const bodyEl = $("#dialog-body");
  bodyEl.replaceChildren();
  if (typeof body === "string") {
    bodyEl.append(el("p", { className: "hint", text: body }));
  } else if (body) {
    bodyEl.append(body);
  }

  const actionsEl = $("#dialog-actions");
  actionsEl.replaceChildren();
  for (const action of actions) {
    const button = el("button", {
      className: `btn ${action.className || ""}`,
      type: "button",
      text: action.label,
    });
    button.addEventListener("click", async () => {
      try {
        await action.onClick?.();
      } catch (error) {
        toast(error.message, true);
      }
    });
    actionsEl.append(button);
  }

  dialog.showModal();
}

function promptSudoPassword(target) {
  return new Promise((resolve) => {
    const dialog = $("#dialog");
    let settled = false;
    const input = el("input", {
      type: "password",
      className: "input mono",
      id: "sudo-password",
      autocomplete: "off",
      spellcheck: "false",
    });
    const finish = (value) => {
      if (settled) return;
      settled = true;
      input.value = "";
      if (dialog.open) dialog.close();
      resolve(value);
    };
    const message = target === "all"
      ? "La mise à jour « tout » inclut les paquets OS et nécessite le mot de passe sudo de la VM. Il n'est ni stocké ni journalisé."
      : "La mise à jour OS nécessite le mot de passe sudo de la VM. Il n'est ni stocké ni journalisé.";
    const body = el("div", {},
      el("p", { className: "hint", text: message }),
      field("mot de passe sudo", input),
    );

    openDialog({
      title: "mise à jour de l'os",
      body,
      actions: [
        { label: "annuler", onClick: () => finish(null) },
        {
          label: "continuer",
          className: "btn-primary",
          onClick: () => {
            if (!input.value) {
              toast("mot de passe requis", true);
              return;
            }
            finish(input.value);
          },
        },
      ],
    });
    dialog.addEventListener("close", () => finish(null), { once: true });
  });
}

function confirmDialog(title, message, confirmLabel = "confirmer", danger = false) {
  return new Promise((resolve) => {
    const dialog = $("#dialog");
    const finish = (value) => {
      if (dialog.open) dialog.close();
      resolve(value);
    };
    openDialog({
      title,
      body: message,
      actions: [
        { label: "annuler", onClick: () => finish(false) },
        {
          label: confirmLabel,
          className: danger ? "btn-danger" : "btn-primary",
          onClick: () => finish(true),
        },
      ],
    });
    dialog.addEventListener("close", () => resolve(false), { once: true });
  });
}

function formatEpoch(epoch) {
  if (!epoch) return "—";
  return new Date(Number(epoch) * 1000).toLocaleString("fr-FR");
}

function stripAnsi(text) {
  return String(text || "").replace(/\x1b\[[0-9;]*[A-Za-z]/g, "");
}

function badgeClass(stateName) {
  if (stateName === "running" || stateName === "active" || stateName === "installed") return "ok";
  if (stateName === "missing" || stateName === "failed") return "bad";
  if (stateName === "unknown" || stateName === "paused") return "warn";
  return "";
}

function setBadge(selector, label, value, tone) {
  const node = $(selector);
  node.classList.remove("ok", "warn", "bad");
  if (tone) node.classList.add(tone);
  node.replaceChildren(
    document.createTextNode(`${label} `),
    el("b", { text: value }),
  );
}

function setStatusDot(selector, tone) {
  const node = $(selector);
  node.classList.remove("ok", "warn", "bad");
  if (tone) node.classList.add(tone);
}

/* Status ------------------------------------------------------------------ */

async function loadStatus({ quiet = false } = {}) {
  if (state.quitting) return;
  try {
    const data = await api("status");
    state.status = data;
    state.lastError = "";
    $("#footer-status").textContent = "connecté";
    renderStatus(data);
  } catch (error) {
    $("#footer-status").textContent = "hors ligne";
    if (!quiet || state.lastError !== error.message) {
      toast(error.message, true);
    }
    state.lastError = error.message;
  }
}

function renderStatus(data) {
  const vm = data.vm || {};
  const tunnel = data.tunnel || {};
  const config = data.config || {};
  const services = data.services || [];
  const lan = data.lan || {};

  const vmTone = vm.running ? "ok" : vm.exists ? "warn" : "bad";
  setBadge("#vm-badge", "VM", vm.running ? "running" : (vm.state || "unknown"), vmTone);
  setStatusDot("#vm-dot", vmTone);
  $("#vm-name").textContent = vm.name || "—";
  $("#vm-state").textContent = vm.state || "—";
  $("#vm-address").textContent = vm.ip || "—";
  $("#vm-ip").textContent = vm.ip || "—";

  const vmActive = vm.running || vm.state === "paused";
  const vmStart = $('[data-vm="start"]');
  const vmRestart = $('[data-vm="restart"]');
  const vmShutdown = $('[data-vm="shutdown"]');
  vmStart.disabled = vmActive || !vm.exists;
  vmStart.title = !vm.exists ? "La VM n'existe pas encore" : vmActive ? "La VM est déjà démarrée" : "";
  vmRestart.disabled = !vmActive;
  vmRestart.title = vmActive ? "" : "La VM n'est pas démarrée";
  vmShutdown.disabled = !vmActive;
  vmShutdown.title = vmActive ? "" : "La VM n'est pas démarrée";
  $("#vm-force").disabled = !vmActive;

  const tunnelTone = tunnel.active ? "ok" : tunnel.installed ? "warn" : "bad";
  setBadge("#tunnel-badge", "TUNNEL", tunnel.active ? "active" : (tunnel.status || "inactive"), tunnelTone);
  setStatusDot("#tunnel-dot", tunnelTone);
  $("#tunnel-status").textContent = tunnel.status || "—";
  $("#tunnel-count").textContent = String(services.length);
  $("#lan-count").textContent = `${lan.permanent || 0} permanent / ${lan.temporary || 0} temporaire`;

  const tunnelStart = $('[data-tunnel="start"]');
  const tunnelRestart = $('[data-tunnel="restart"]');
  const tunnelStop = $('[data-tunnel="stop"]');
  tunnelStart.disabled = tunnel.active || !tunnel.installed;
  tunnelStart.title = !tunnel.installed ? "Le service tunnel n'est pas installé" : tunnel.active ? "Le tunnel est déjà démarré" : "";
  tunnelRestart.disabled = !tunnel.installed;
  tunnelRestart.title = tunnel.installed ? "" : "Le service tunnel n'est pas installé";
  tunnelStop.disabled = !tunnel.active;
  tunnelStop.title = tunnel.active ? "" : "Le tunnel n'est pas démarré";

  state.services = services;
  renderOverviewServices(services);
  renderServices(services);
  renderSettings(config);
}

function statusPill(mode) {
  if (mode === "permanent") return el("span", { className: "pill lan", text: "lan permanent" });
  if (mode === "temporary") return el("span", { className: "pill lan", text: "lan temporaire" });
  return el("span", { className: "pill", text: "localhost" });
}

function serviceActions(service, compact = false) {
  const actions = el("div", { className: "actions" });
  const local = el("button", { className: "btn btn-sm", type: "button", text: "local" });
  local.addEventListener("click", () => openService(service.name, "local"));
  actions.append(local);

  if (service.lan !== "local") {
    const lan = el("button", { className: "btn btn-sm", type: "button", text: "lan" });
    lan.addEventListener("click", () => openService(service.name, "lan"));
    actions.append(lan);
  }

  if (!compact) {
    const edit = el("button", { className: "btn btn-sm btn-ghost", type: "button", text: "éditer" });
    edit.addEventListener("click", () => openServiceDialog(service));
    const remove = el("button", { className: "btn btn-sm btn-danger", type: "button", text: "supprimer" });
    remove.addEventListener("click", () => removeService(service.name));
    actions.append(edit, remove);
  }

  return actions;
}

function renderOverviewServices(services) {
  const body = $("#overview-services");
  body.replaceChildren();
  $("#services-summary").textContent = `${services.length} configuré(s)`;

  if (services.length === 0) {
    body.append(el("tr", {}, el("td", { className: "empty", colspan: "5", text: "aucun service configuré" })));
    return;
  }

  for (const service of services) {
    body.append(
      el("tr", {},
        el("td", { className: "name", text: service.name }),
        el("td", { className: "mono muted", text: service.port }),
        el("td", {}, statusPill(service.lan)),
        el("td", { className: "url", text: service.url_local || "—" }),
        el("td", {}, serviceActions(service, true)),
      ),
    );
  }
}

function renderServices(services) {
  const body = $("#services-body");
  body.replaceChildren();

  if (services.length === 0) {
    body.append(el("tr", {}, el("td", { className: "empty", colspan: "5", text: "aucun service configuré" })));
    return;
  }

  for (const service of services) {
    const urls = el("div", { className: "url" },
      el("div", { text: service.url_local || "—" }),
      service.url_lan ? el("div", { className: "muted", text: service.url_lan }) : null,
    );

    body.append(
      el("tr", {},
        el("td", { className: "name", text: service.name }),
        el("td", { className: "mono", text: service.port }),
        el("td", {}, statusPill(service.lan)),
        el("td", {}, urls),
        el("td", {}, serviceActions(service)),
      ),
    );
  }
}

/* Services ---------------------------------------------------------------- */

async function openService(name, target) {
  const service = (state.services || []).find((item) => item.name === name);
  if (!service) {
    toast("service introuvable", true);
    return;
  }

  const plainUrl = target === "lan" ? service.url_lan : service.url_local;
  if (!plainUrl) {
    toast("ce service n'est pas exposé sur le LAN", true);
    return;
  }

  if (name !== "dsh" && name !== "opencode") {
    window.open(plainUrl, "_blank", "noopener");
    return;
  }

  try {
    const details = await api(`service-url?name=${encodeURIComponent(name)}`);
    const url = target === "lan" ? details.url_lan : details.url_local;
    if (!url) {
      toast("URL indisponible pour ce service", true);
      return;
    }

    const body = el("div");
    if (details.password) {
      body.append(
        el("p", { className: "hint", text: "opencode génère un mot de passe à chaque démarrage." }),
        el("p", { className: "mono", text: `mot de passe : ${details.password}` }),
      );
    } else {
      body.append(el("p", { className: "hint", text: "L'URL contient un jeton d'authentification généré par le service." }));
    }
    body.append(el("p", { className: "mono url", text: url }));

    openDialog({
      title: `ouvrir ${name}`,
      body,
      actions: [
        {
          label: "copier l'url",
          onClick: async () => {
            await navigator.clipboard.writeText(url);
            toast("URL copiée");
          },
        },
        {
          label: "ouvrir",
          className: "btn-primary",
          onClick: () => {
            window.open(url, "_blank", "noopener");
            closeDialog();
          },
        },
      ],
    });
  } catch (error) {
    toast(error.message, true);
  }
}

function field(labelText, input) {
  return el("div", { className: "field" },
    el("label", { for: input.id, text: labelText }),
    input,
  );
}

function openServiceDialog(service = null) {
  const editing = Boolean(service);
  const nameInput = el("input", {
    className: "input mono",
    id: "service-name",
    value: service?.name || "",
    placeholder: "opencode",
    autocomplete: "off",
    spellcheck: "false",
  });
  const portInput = el("input", {
    className: "input mono",
    id: "service-port",
    value: service?.port || "",
    placeholder: "4096 ou 8080:9000",
    autocomplete: "off",
    spellcheck: "false",
  });

  const lanSelect = el("select", { className: "input mono", id: "service-lan" },
    el("option", { value: "local", text: "localhost" }),
    el("option", { value: "permanent", text: "LAN permanent" }),
    el("option", { value: "temporary", text: "LAN temporaire" }),
  );
  lanSelect.value = service?.lan || "local";

  const timeoutInput = el("input", {
    className: "input mono",
    id: "service-timeout",
    value: "2h",
    placeholder: "2h",
    autocomplete: "off",
    spellcheck: "false",
  });
  const timeoutField = field("durée (30m, 2h)", timeoutInput);
  timeoutField.hidden = lanSelect.value !== "temporary";
  lanSelect.addEventListener("change", () => {
    timeoutField.hidden = lanSelect.value !== "temporary";
  });

  const form = el("div", { className: "form-grid" },
    field("nom", nameInput),
    field("port invité ou hôte:invité", portInput),
    field("exposition", lanSelect),
    timeoutField,
  );

  openDialog({
    title: editing ? `éditer ${service.name}` : "ajouter un service",
    body: form,
    actions: [
      { label: "annuler", onClick: closeDialog },
      {
        label: editing ? "enregistrer" : "ajouter",
        className: "btn-primary",
        onClick: async () => {
          const name = nameInput.value.trim();
          const port = portInput.value.trim();
          const lan = lanSelect.value;
          const timeout = timeoutInput.value.trim() || "2h";

          if (!/^[A-Za-z0-9._-]+$/.test(name)) {
            toast("nom invalide : lettres, chiffres, '.', '_' ou '-'", true);
            return;
          }
          if (!/^[0-9]+(:[0-9]+)?$/.test(port)) {
            toast("port invalide : 4096 ou 8080:9000", true);
            return;
          }

          if (editing) {
            await api("services/update", {
              method: "POST",
              body: { name: service.name, new_name: name, port, lan, timeout },
            });
            toast(`service ${name} mis à jour`);
          } else {
            await api("services/add", {
              method: "POST",
              body: { name, port, lan, timeout },
            });
            toast(`service ${name} ajouté`);
          }

          closeDialog();
          await loadStatus({ quiet: true });
        },
      },
    ],
  });
}

async function removeService(name) {
  const confirmed = await confirmDialog(
    `supprimer ${name}`,
    "Le service sera retiré de services.json et le tunnel sera rechargé. Cette action ne supprime pas le logiciel dans la VM.",
    "supprimer",
    true,
  );
  if (!confirmed) return;

  try {
    await api("services/remove", { method: "POST", body: { name } });
    toast(`service ${name} supprimé`);
    await loadStatus({ quiet: true });
  } catch (error) {
    toast(error.message, true);
  }
}

/* VM / tunnel ------------------------------------------------------------- */

async function vmAction(action) {
  const force = $("#vm-force").checked;
  if (action !== "start") {
    const verb = action === "shutdown" ? "arrêter" : "redémarrer";
    const confirmed = await confirmDialog(
      `${verb} la VM`,
      force ? "Mode forcé : la VM sera arrêtée immédiatement." : "La VM sera arrêtée proprement.",
      verb,
      action === "shutdown",
    );
    if (!confirmed) return;
  }

  try {
    const data = await api("vm", { method: "POST", body: { action, force } });
    startJob(data);
  } catch (error) {
    toast(error.message, true);
  }
}

async function tunnelAction(action) {
  if (action === "stop") {
    const confirmed = await confirmDialog(
      "arrêter le tunnel",
      "Les services ne seront plus accessibles depuis l'hôte, mais la VM continuera de tourner.",
      "arrêter",
      true,
    );
    if (!confirmed) return;
  }
  try {
    const data = await api("tunnel", { method: "POST", body: { action } });
    startJob(data);
  } catch (error) {
    toast(error.message, true);
  }
}

/* Updates ----------------------------------------------------------------- */

async function loadUpdates({ quiet = false } = {}) {
  try {
    state.updates = await api("updates");
    renderUpdates(state.updates);
  } catch (error) {
    if (!quiet) toast(error.message, true);
  }
}

function renderUpdates(data) {
  const repo = data.repo || {};
  const vm = data.vm || {};
  const updates = vm.updates;

  $("#check-updates").disabled = !vm.running;
  $$("[data-update]").forEach((button) => {
    button.disabled = !vm.running;
  });

  if (!repo.is_git) {
    $("#update-repo").textContent = "non git";
    $("#update-repo-detail").textContent = "dépôt local";
  } else if (repo.behind > 0) {
    $("#update-repo").textContent = `${repo.behind} commit(s)`;
    $("#update-repo-detail").textContent = repo.upstream || "en retard";
  } else {
    $("#update-repo").textContent = "à jour";
    $("#update-repo-detail").textContent = repo.upstream || "—";
  }

  if (!vm.running) {
    $("#update-apt").textContent = "VM arrêtée";
    $("#update-reboot").textContent = "pas de données";
    $("#update-npm").textContent = "—";
    $("#update-vscode").textContent = "—";
    return;
  }

  if (!updates) {
    $("#update-apt").textContent = "—";
    $("#update-reboot").textContent = "aucun cache";
    $("#update-npm").textContent = "—";
    $("#update-vscode").textContent = "—";
    return;
  }

  $("#update-apt").textContent = String(updates.apt ?? 0);
  $("#update-reboot").textContent = updates.reboot ? "reboot requis" : `vérifié ${formatEpoch(updates.timestamp)}`;
  $("#update-npm").textContent = updates.npm || "à jour";
  $("#update-vscode").textContent = updates.vscode ? "vscode-server : mise à jour" : "vscode-server : à jour";
}

async function checkUpdates() {
  try {
    const data = await api("updates/check", { method: "POST" });
    startJob(data, { reload: "updates" });
  } catch (error) {
    toast(error.message, true);
  }
}

async function applyUpdate(target) {
  let sudoPassword = null;

  if (target === "os" || target === "all") {
    sudoPassword = await promptSudoPassword(target);
    if (sudoPassword === null) return;
  }

  try {
    const body = { target };
    if (sudoPassword !== null) body.sudo_password = sudoPassword;
    const data = await api("updates/apply", { method: "POST", body });
    startJob(data, { reload: "updates" });
  } catch (error) {
    toast(error.message, true);
  }
}

async function selfUpdate() {
  const confirmed = await confirmDialog(
    "mettre à jour aibox",
    "Le dépôt sera mis à jour et les scripts seront renvoyés dans la VM si nécessaire.",
    "mettre à jour",
    false,
  );
  if (!confirmed) return;
  try {
    const data = await api("self-update", { method: "POST" });
    startJob(data, { reload: "updates" });
  } catch (error) {
    toast(error.message, true);
  }
}

/* Setup ------------------------------------------------------------------- */

async function loadSetup({ quiet = false } = {}) {
  try {
    state.setup = await api("setup");
    renderSetup(state.setup);
  } catch (error) {
    if (!quiet) toast(error.message, true);
  }
}

function renderSetup(data) {
  const body = $("#setup-body");
  body.replaceChildren();
  const steps = data.steps || [];

  if (steps.length === 0) {
    body.append(el("tr", {}, el("td", { className: "empty", colspan: "4", text: "aucune étape" })));
    return;
  }

  for (const step of steps) {
    const tone = {
      installed: "ok",
      missing: "bad",
      unknown: "warn",
      disabled: "",
    }[step.status] || "";
    const status = el("span", { className: `pill ${tone}`, text: step.status });

    let action;
    if (step.web_runnable) {
      const run = el("button", { className: "btn btn-sm", type: "button", text: "lancer" });
      run.disabled = !data.vm.running && step.name !== "tunnel" && step.name !== "cli";
      run.addEventListener("click", () => runSetup(step.name));
      action = run;
    } else {
      action = el("span", { className: "mono dim", text: "cli", title: step.reason || "" });
    }

    const description = el("div", {},
      el("div", { text: step.description }),
      step.reason ? el("div", { className: "mono dim", text: step.reason }) : null,
    );

    body.append(
      el("tr", {},
        el("td", { className: "name", text: step.name }),
        el("td", {}, status),
        el("td", {}, description),
        el("td", {}, action),
      ),
    );
  }
}

async function runSetup(step) {
  const withDeps = $("#setup-with-deps").checked;
  try {
    const data = await api("setup/run", {
      method: "POST",
      body: { step, with_deps: withDeps },
    });
    startJob(data, { reload: "setup" });
  } catch (error) {
    toast(error.message, true);
  }
}

/* Settings ---------------------------------------------------------------- */

function renderSettings(config) {
  const effective = config.lan_hostname || "";
  const configured = config.lan_hostname_configured || "";
  $("#lan-auto").textContent = effective || "—";
  $("#lan-hostname").placeholder = effective || "desk.local";
  $("#settings-current").textContent = configured
    ? `valeur configurée : ${configured}`
    : `automatique : ${effective || "—"}`;
  if (document.activeElement !== $("#lan-hostname")) {
    $("#lan-hostname").value = configured;
  }
}

async function saveLanHostname(value) {
  try {
    await api("config", { method: "POST", body: { lan_hostname: value } });
    toast(value ? "nom d'hôte LAN enregistré" : "nom d'hôte LAN remis en automatique");
    await loadStatus({ quiet: true });
  } catch (error) {
    toast(error.message, true);
  }
}

async function quitWeb() {
  const confirmed = await confirmDialog(
    "quitter l'interface",
    "Le service aibox web va s'arrêter. Aucun processus ne restera en arrière-plan. Tu pourras le relancer avec `aibox web`.",
    "quitter",
    true,
  );
  if (!confirmed) return;

  try {
    await api("quit", { method: "POST", body: { session_id: state.sessionId } });
    state.quitting = true;
    if (state.jobTimer) clearTimeout(state.jobTimer);
    $("#footer-status").textContent = "service arrêté";
    document.body.classList.add("stopped");
    openDialog({
      title: "service arrêté",
      body: "Le serveur aibox web est arrêté. L'onglet va se fermer ; sinon, tu peux le fermer manuellement.",
      actions: [{ label: "fermer", onClick: closeDialog }],
    });
    setTimeout(() => {
      try {
        window.close();
      } catch {
        // Browsers may refuse to close a tab they did not open.
      }
    }, 800);
  } catch (error) {
    toast(error.message, true);
  }
}

/* Jobs -------------------------------------------------------------------- */

function jobStateLabel(stateName) {
  return {
    running: "en cours",
    done: "terminé",
    failed: "échec",
    cancelled: "annulé",
  }[stateName] || stateName;
}

function startJob(response, options = {}) {
  if (!response || !response.id) {
    toast("opération non démarrée", true);
    return;
  }

  state.activeJob = {
    id: response.id,
    title: response.title || "opération",
    reload: options.reload || "all",
    done: false,
  };

  $("#active-job-panel").hidden = false;
  $("#active-job-title").textContent = state.activeJob.title;
  $("#active-job-state").textContent = "en cours…";
  $("#active-job-bar").style.display = "block";

  openJobDialog(state.activeJob);
  pollJob();
}

async function pollJob() {
  if (state.quitting || !state.activeJob || state.activeJob.done) return;

  try {
    const data = await api(`job?id=${encodeURIComponent(state.activeJob.id)}`);
    const logText = stripAnsi((data.log || []).join("\n"));
    if (state.jobLogEl) {
      state.jobLogEl.textContent = logText || "en attente de sortie…";
      state.jobLogEl.scrollTop = state.jobLogEl.scrollHeight;
    }

    $("#active-job-state").textContent = `${jobStateLabel(data.state)}${data.exit !== null ? ` (code ${data.exit})` : ""}`;

    if (data.state === "running") {
      state.jobTimer = setTimeout(pollJob, 1000);
      return;
    }

    state.activeJob.done = true;
    $("#active-job-bar").style.display = "none";
    $("#active-job-panel").hidden = true;

    if (data.state === "done" && data.exit === 0) {
      toast(`${state.activeJob.title} terminé`);
    } else if (data.state !== "cancelled") {
      toast(`${state.activeJob.title} en échec${data.exit !== null ? ` (code ${data.exit})` : ""}`, true);
    }

    const reload = state.activeJob.reload;
    state.activeJob = null;

    await loadStatus({ quiet: true });
    if (reload === "updates" || reload === "all") await loadUpdates({ quiet: true });
    if (reload === "setup" || reload === "all") await loadSetup({ quiet: true });
  } catch (error) {
    state.activeJob.done = true;
    $("#active-job-bar").style.display = "none";
    $("#active-job-panel").hidden = true;
    toast(error.message, true);
  }
}

function openJobDialog(job) {
  const pre = el("pre", { text: "en attente de sortie…" });
  state.jobLogEl = pre;

  openDialog({
    title: job.title,
    body: pre,
    actions: [
      {
        label: "masquer",
        onClick: closeDialog,
      },
    ],
  });
}

/* Tabs -------------------------------------------------------------------- */

function currentTabFromLocation() {
  const name = new URLSearchParams(window.location.search).get("tab");
  return ["overview", "services", "updates", "setup", "settings"].includes(name) ? name : "overview";
}

function switchTab(name, updateUrl = true) {
  $$(".tab").forEach((tab) => tab.classList.toggle("active", tab.dataset.tab === name));
  $$(".tab-panel").forEach((panel) => panel.classList.toggle("active", panel.id === `tab-${name}`));

  if (updateUrl) {
    const next = name === "overview" ? window.location.pathname : `${window.location.pathname}?tab=${name}`;
    history.replaceState(null, "", next);
  }

  if (name === "updates" && !state.updates) loadUpdates();
  if (name === "setup" && !state.setup) loadSetup();
}

function initEvents() {
  $$(".tab").forEach((tab) => {
    tab.addEventListener("click", () => switchTab(tab.dataset.tab));
  });

  $("#refresh-overview").addEventListener("click", () => loadStatus());
  $("#refresh-services").addEventListener("click", () => loadStatus());
  $("#refresh-updates").addEventListener("click", () => loadUpdates());
  $("#refresh-setup").addEventListener("click", () => loadSetup());
  $("#refresh-settings").addEventListener("click", () => loadStatus());
  $("#add-service").addEventListener("click", () => openServiceDialog());
  $("#check-updates").addEventListener("click", checkUpdates);
  $("#self-update").addEventListener("click", selfUpdate);
  $("#quit-web").addEventListener("click", quitWeb);
  $("#quit-web-top").addEventListener("click", quitWeb);
  $("#dialog-close").addEventListener("click", closeDialog);

  $$("[data-vm]").forEach((button) => {
    button.addEventListener("click", () => vmAction(button.dataset.vm));
  });
  $$("[data-tunnel]").forEach((button) => {
    button.addEventListener("click", () => tunnelAction(button.dataset.tunnel));
  });
  $$("[data-update]").forEach((button) => {
    button.addEventListener("click", () => applyUpdate(button.dataset.update));
  });

  $("#settings-form").addEventListener("submit", (event) => {
    event.preventDefault();
    saveLanHostname($("#lan-hostname").value.trim());
  });
  $("#lan-hostname-auto").addEventListener("click", () => {
    $("#lan-hostname").value = "";
    saveLanHostname("");
  });

  $("#active-job-log").addEventListener("click", () => {
    if (state.activeJob) openJobDialog(state.activeJob);
  });

  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) loadStatus({ quiet: true });
  });

  window.addEventListener("pagehide", (event) => {
    if (event.persisted || state.quitting || !state.token) return;
    // Closing the tab stops the server after a short grace period. A reload
    // or a new page cancels it before it fires.
    fetch("/cgi-bin/api.sh/quit?delay=5", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${state.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ session_id: state.sessionId }),
      keepalive: true,
    }).catch(() => {});
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && $("#dialog").open) closeDialog();
    if (event.target instanceof Element && event.target.matches("input, select, textarea")) return;
    const tabs = ["overview", "services", "updates", "setup", "settings"];
    if (event.key >= "1" && event.key <= "5") switchTab(tabs[Number(event.key) - 1]);
  });
}

async function init() {
  initToken();
  initEvents();

  if (!state.token) {
    $("#footer-status").textContent = "token absent";
    openDialog({
      title: "token absent",
      body: "Relance `aibox web` : l'interface ouvre automatiquement le lien avec le token.",
      actions: [{ label: "fermer", onClick: closeDialog }],
    });
    return;
  }

  await registerSession();
  await cancelPendingQuit();
  await loadStatus();
  await Promise.allSettled([loadUpdates({ quiet: true }), loadSetup({ quiet: true })]);
  switchTab(currentTabFromLocation(), false);
  setInterval(() => {
    if (!document.hidden && !state.quitting) loadStatus({ quiet: true });
  }, 5000);
}

init();
