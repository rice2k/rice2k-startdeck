"use strict";
/* Rice2K Project Explorer. Public data only; no API tokens or paid dependencies. */
(function () {
  const OWNER = "rice2k";
  const API = "https://api.github.com";
  const TTL = 2 * 60 * 60 * 1000;
  const PER_PAGE = 100;
  const PAGE_SIZE = 24;
  const FEATURED = ["r2k-rescuedesk-usb","rice2k-magic-tasks","old-free-online-resources","Cyber-Tool-Atlas","rice2k-rainmeter-control-bar","Graalians-Discord-Server-Tool-Hub","Rice2k-Folder-Vault","CoolKids-Archive-Website"];
  const ALIASES = {
    "gs2":["graal","script"], "graalscript":["graal","script"], "gmap":["graal","map"],
    "gani":["graal","animation"], "pc":["computer","windows"], "repair":["rescue","windows"],
    "win11":["windows"], "win10":["windows"], "oldweb":["retro","archive"],
    "retro":["archive"], "powershell":["ps1"], "scripting":["scripts"], "vault":["encryption"],
    "discord":["graalians"], "startpage":["dashboard"]
  };
  const SEEDS = [
    ["r2k-rescuedesk-usb","Service-bench USB command center for Windows repair, WinPE, triage and backups.","PowerShell","pc-repair windows-repair technician-toolkit usb-toolkit"],
    ["rice2k-magic-tasks","Windows task planner with reminders, calendar, focus mode and themes.","Python","productivity task-planner windows"],
    ["old-free-online-resources","Searchable archive of 1990s and 2000s free websites and recovered links.","HTML","retro-web web-archive link-directory"],
    ["Cyber-Tool-Atlas","Searchable directory of cybersecurity utilities and learning resources.","JavaScript","cybersecurity security-tools directory"],
    ["rice2k-rainmeter-control-bar","Custom Windows desktop Rainmeter system monitoring and shortcuts.","PowerShell","rainmeter windows desktop"],
    ["Graalians-Discord-Server-Tool-Hub","GraalOnline development tools for GMAP, NW levels, GANI and GS2.","PHP","graal graalonline gmap gani gs2"],
    ["Graal-Level-Viewer","Preserved GraalOnline level viewer with C# source and build notes.","C#","graal graalonline level-editor"],
    ["gs2-scripts","Graal Script 2 code examples and guild-management resources.","","graal graalonline gs2 scripts"],
    ["Rice2k-Folder-Vault","Experimental encrypted Windows folder vault with read-only Explorer integration.","C#","windows encrypted-vault alpha"],
    ["CoolKids-Archive-Website","Preservation of the original early-2000s CoolKid website and recovered software.","","web-preservation retro-web archive"],
    ["rice2k-startdeck","RiceDeck customizable startpage with weather, bookmarks and gaming links.","HTML","startpage dashboard"],
    ["Computer-Asset-System-Info","Windows computer asset and system information utilities.","","windows inventory"],
    ["AOL-Progz","AOL-era programs and retro internet research collection.","","retro-web archive"],
    ["Rice2k-Macro-Studio","Macro scripting and automation tools.","","automation macro"],
    ["rice2k-computer-cleaner","Windows maintenance and cleanup utility.","","windows tools"],
    ["BTK-Graal-Guild-site-Remake-Archive","Preserved GraalOnline guild site reconstruction.","","graal archive"],
    ["rice2ks-web-directory-recreation","Preservation and showcase of a classic web directory.","PHP","retro-web archive"]
  ];
  const $ = (s) => document.querySelector(s);
  const els = {
    input: $("#search"), clear: $("#clear-search"), cat: $("#category"), lang: $("#language"),
    sort: $("#sort"), grid: $("#project-grid"), summary: $("#results-summary"), warning: $("#warning"),
    empty: $("#empty"), more: $("#load-more"), refresh: $("#refresh"), copy: $("#copy-link")
  };
  let state = {scope:"owned", q:"", category:"all", language:"all", sort:"relevance", count:PAGE_SIZE};
  let data = [];
  let source = "";
  let requestIndex = 0;

  const safeStr = (v) => typeof v === "string" ? v : "";
  const lower = (s) => safeStr(s).toLowerCase();
  const normalize = (s) => lower(s).normalize("NFKD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9+#]+/g," ").trim();
  const readable = (s) => safeStr(s).replace(/[-_]+/g," ");
  const node = (tag, className, text) => {
    const n = document.createElement(tag);
    if (className) n.className = className;
    if (text !== undefined) n.textContent = text;
    return n;
  };
  const ownedLink = (r) => "https://github.com/" + encodeURIComponent(safeStr(r.owner && r.owner.login) || OWNER) + "/" + encodeURIComponent(safeStr(r.name));
  const safeWebsite = (value) => {
    try { const url = new URL(value); return (url.protocol === "https:" || url.protocol === "http:") ? url.href : null; }
    catch (_) { return null; }
  };
  const link = (label, href, className) => {
    const a = node("a", className || "", label);
    a.href = href;
    a.target = "_blank";
    a.rel = "noopener noreferrer";
    return a;
  };
  const dateValue = (r) => Date.parse(r.pushed_at || r.updated_at || "") || 0;
  const dateLabel = (r) => {
    const d = dateValue(r); return d ? new Date(d).toLocaleDateString(undefined,{year:"numeric",month:"short",day:"numeric"}) : "Date unavailable";
  };
  const categories = ["GraalOnline","Windows & IT","Web Archives","Security","Discord","Automation","Web Projects","Productivity","Other"];
  function classify(r) {
    const name = normalize(r.name);
    const hay = normalize([r.name,r.description,...(r.topics || [])].join(" "));
    if (/\b(graal|graalians|gmap|gani|gs2|nw2png)\b/.test(hay) || /graal/.test(name)) return "GraalOnline";
    if (/\b(discord|bot|chatbot)\b/.test(hay)) return "Discord";
    if (/\b(archive|preservation|retro|old web|old internet|history|web directory|wayback|aol)\b/.test(hay)) return "Web Archives";
    if (/\b(security|cyber|malware|password|encrypt|privacy|vault|hacker)\b/.test(hay)) return "Security";
    if (/\b(automation|macro|script runner|batch)\b/.test(hay)) return "Automation";
    if (/\b(task planner|task manager|productivity|calendar|reminder)\b/.test(hay)) return "Productivity";
    if (/\b(windows|powershell|winpe|pc repair|rainmeter|computer|desktop|sysinfo)\b/.test(hay)) return "Windows & IT";
    if (/\b(website|web site|html|web|startpage|dashboard|php|javascript)\b/.test(hay)) return "Web Projects";
    return "Other";
  }
  function prepare(r) {
    if (!r || typeof r.name !== "string" || !r.name) return null;
    const o = r.owner && r.owner.login;
    if (state.scope === "owned" && o && lower(o) !== OWNER) return null;
    if (r.private) return null;
    const prepared = Object.assign({},r,{
      description:safeStr(r.description),
      topics:Array.isArray(r.topics) ? r.topics.filter(x=>typeof x==="string") : [],
      language:safeStr(r.language),
      stargazers_count:Number(r.stargazers_count)||0
    });
    prepared.category = classify(prepared);
    prepared.url = ownedLink(prepared);
    prepared.site = safeWebsite(r.homepage);
    return prepared;
  }
  function starterData() {
    return SEEDS.map(x=>({name:x[0],description:x[1],language:x[2],topics:x[3].split(" "),owner:{login:OWNER},private:false,stargazers_count:0,html_url:"https://github.com/"+OWNER+"/"+x[0]}));
  }
  function cacheKey() { return "rice2k-project-explorer-v2-"+state.scope; }
  function getCached() {
    try {
      const c = JSON.parse(localStorage.getItem(cacheKey()) || "null");
      return c && Array.isArray(c.items) && Date.now()-c.savedAt < TTL ? c.items : null;
    } catch (_) { return null; }
  }
  function setCached(items) {
    try { localStorage.setItem(cacheKey(),JSON.stringify({items:items,savedAt:Date.now()})); } catch (_) { /* browser storage may be disabled */ }
  }
  function warn(text) { els.warning.textContent = text; els.warning.hidden = !text; }
  async function fetchGithub(scope) {
    const found = [];
    for (let page=1;page<=10;page++) {
      const route = scope === "owned" ? "/users/"+OWNER+"/repos" : "/users/"+OWNER+"/starred";
      const joiner = scope === "owned" ? "&sort=updated&type=owner" : "";
      const url = API+route+"?per_page="+PER_PAGE+"&page="+page+joiner;
      const control = new AbortController();
      const timer = setTimeout(()=>control.abort(),14000);
      let response;
      try { response = await fetch(url,{headers:{"Accept":"application/vnd.github+json"},signal:control.signal}); }
      finally { clearTimeout(timer); }
      if (!response.ok) throw new Error("GitHub API HTTP "+response.status);
      const items = await response.json();
      if (!Array.isArray(items)) throw new Error("Unexpected GitHub response");
      found.push(...items.filter(r=>r && r.private !== true && typeof r.name === "string"));
      if (items.length < PER_PAGE) break;
    }
    return found;
  }
  function tokens(q) {
    const result = normalize(q).split(/\s+/).filter(Boolean);
    return result.flatMap(t=>[t,...(ALIASES[t]||[])]);
  }
  function fuzzyToken(token, words) {
    if (token.length<5) return false;
    return words.some(w=>Math.abs(w.length-token.length)<=1 && (w.startsWith(token.slice(0,Math.max(3,token.length-2))) || editDistanceAtMostOne(token,w)));
  }
  function editDistanceAtMostOne(a,b) {
    if (Math.abs(a.length-b.length)>1) return false;
    let i=0,j=0,edits=0;
    while (i<a.length && j<b.length) {
      if (a[i]===b[j]) {i++;j++;continue;}
      if (++edits>1) return false;
      if (a.length>b.length)i++; else if (b.length>a.length)j++; else{i++;j++;}
    }
    return edits+(a.length-i)+(b.length-j)<=1;
  }
  function rank(r,q) {
    if (!q) return 0;
    const terms = tokens(q);
    const name = normalize(readable(r.name));
    const description = normalize(r.description);
    const topics = normalize((r.topics||[]).join(" "));
    const category = normalize(r.category);
    const lang = normalize(r.language);
    const all = name+" "+description+" "+topics+" "+category+" "+lang;
    const words = all.split(" ");
    let score = 0;
    for (const t of terms) {
      if (name.includes(t)) score += 12;
      else if (topics.includes(t)) score += 9;
      else if (category.includes(t) || lang.includes(t)) score += 7;
      else if (description.includes(t)) score += 4;
      else if (fuzzyToken(t,words)) score += 2;
      else return -1;
    }
    return score;
  }
  function syncUrl() {
    const u = new URL(location.href);
    for (const key of ["q","category","language","sort","scope"]) u.searchParams.delete(key);
    if (state.q) u.searchParams.set("q",state.q);
    if (state.category!=="all") u.searchParams.set("category",state.category);
    if (state.language!=="all") u.searchParams.set("language",state.language);
    if (state.sort!=="relevance") u.searchParams.set("sort",state.sort);
    if (state.scope!=="owned") u.searchParams.set("scope",state.scope);
    history.replaceState(null,"",u.pathname+u.search+u.hash);
  }
  function getMatches() {
    const q = state.q.trim();
    return data.map(r=>({r:r,score:rank(r,q)})).filter(x=>
      x.score>=0 && (state.category==="all" || x.r.category===state.category) &&
      (state.language==="all" || x.r.language===state.language))
      .sort((a,b)=>{
        if (state.sort==="az") return a.r.name.localeCompare(b.r.name);
        if (state.sort==="stars") return b.r.stargazers_count-a.r.stargazers_count || a.r.name.localeCompare(b.r.name);
        if (state.sort==="updated") return dateValue(b.r)-dateValue(a.r) || a.r.name.localeCompare(b.r.name);
        if (q && b.score!==a.score) return b.score-a.score;
        const featuredA = FEATURED.some(n=>lower(n)===lower(a.r.name))?1:0;
        const featuredB = FEATURED.some(n=>lower(n)===lower(b.r.name))?1:0;
        return featuredB-featuredA || dateValue(b.r)-dateValue(a.r) || a.r.name.localeCompare(b.r.name);
      }).map(x=>x.r);
  }
  function makeCard(r) {
    const card = node("article","project-card");
    const head = node("div","card-head");
    head.append(node("div","repo-icon", (r.name||"R").slice(0,1).toUpperCase()));
    const flags = node("div","card-flags");
    if (FEATURED.some(n=>lower(n)===lower(r.name))) flags.append(node("span","","Featured"));
    if (r.archived) flags.append(node("span","","Archived"));
    if (r.fork) flags.append(node("span","","Fork"));
    head.append(flags);card.append(head);
    const heading = node("h3");
    heading.append(link(readable(r.name),r.url));
    card.append(heading);
    card.append(node("p","card-description",r.description || "Browse project source, files, and documentation on GitHub."));
    const tags = node("div","card-tags");
    [r.category,r.language,...r.topics].filter(Boolean).slice(0,4).forEach(t=>tags.append(node("span","",t)));
    card.append(tags);
    const foot=node("div","card-footer");
    foot.append(node("span","","★ "+r.stargazers_count+" stars"));
    foot.append(node("span","","Updated "+dateLabel(r)));
    card.append(foot);
    const links=node("div","card-links");
    links.append(link("View code",r.url));
    if (r.site) links.append(link("Live site",r.site));
    links.append(link("README",r.url+"#readme"));
    card.append(links);
    return card;
  }
  function options(select,values,selected,firstText) {
    select.replaceChildren();
    const initial = node("option","",firstText);initial.value="all";select.append(initial);
    values.forEach(value=>{const option=node("option","",value);option.value=value;select.append(option);});
    select.value=values.includes(selected)?selected:"all";
    return select.value;
  }
  function drawFilters() {
    state.category=options(els.cat,categories,state.category,"All categories");
    const langs=Array.from(new Set(data.map(r=>r.language).filter(Boolean))).sort((a,b)=>a.localeCompare(b));
    state.language=options(els.lang,langs,state.language,"All languages");
    els.sort.value=state.sort;
    document.querySelectorAll("[data-scope]").forEach(button=>{
      const active=button.dataset.scope===state.scope;
      button.classList.toggle("active",active);
      button.setAttribute("aria-pressed",String(active));
    });
  }
  function render() {
    const matches = getMatches();
    const visible = matches.slice(0,state.count);
    const frag=document.createDocumentFragment();
    visible.forEach(r=>frag.append(makeCard(r)));
    els.grid.replaceChildren(frag);
    els.more.hidden=matches.length<=visible.length;
    els.empty.hidden=matches.length>0;
    els.clear.hidden=!state.q;
    els.summary.textContent=matches.length+" matching "+(state.scope==="owned"?"public repositories":"public starred repositories")+
      " · "+data.length+" indexed"+(source?" · "+source:"");
  }
  function filtersChanged() {state.count=PAGE_SIZE;syncUrl();render();}
  async function load(force) {
    const ticket=++requestIndex;
    const scope=state.scope;
    warn("");
    els.refresh.disabled=true;
    els.summary.textContent="Loading "+(scope==="owned"?"public projects":"starred repositories")+"...";
    if (!force) {
      const cached=getCached();
      if (cached) {
        data=cached.map(prepare).filter(Boolean);
        source="cached public GitHub data";
        drawFilters();render();
        els.refresh.disabled=false;
        return;
      }
    }
    try {
      const items=await fetchGithub(scope);
      if (ticket!==requestIndex) return;
      setCached(items);
      data=items.map(prepare).filter(Boolean);
      source="live GitHub data";
    } catch(err) {
      if (ticket!==requestIndex) return;
      const fallback=getCached();
      if (fallback) {
        data=fallback.map(prepare).filter(Boolean);source="cached public GitHub data";
        warn("GitHub could not be reached. Showing locally cached public repository details.");
      } else if (scope==="owned") {
        data=starterData().map(prepare).filter(Boolean);source="sample catalog";
        warn("GitHub could not be reached (possibly an API rate limit). Showing a limited starter catalog; try Refresh later.");
      } else {
        data=[];source="temporarily unavailable";
        warn("Starred repositories could not be loaded from GitHub. Try Refresh later or open the Starred link above.");
      }
    } finally {
      if (ticket===requestIndex) {drawFilters();render();els.refresh.disabled=false;}
    }
  }
  function readLocation() {
    const u=new URL(location.href);
    const p=u.searchParams;
    state.scope=p.get("scope")==="starred"?"starred":"owned";
    state.q=(p.get("q")||"").slice(0,200);
    state.category=categories.includes(p.get("category"))?p.get("category"):"all";
    state.language=(p.get("language")||"all").slice(0,100);
    state.sort=["relevance","updated","stars","az"].includes(p.get("sort"))?p.get("sort"):"relevance";
    els.input.value=state.q;
  }
  els.input.addEventListener("input",()=>{state.q=els.input.value.slice(0,200);filtersChanged();});
  els.clear.addEventListener("click",()=>{state.q="";els.input.value="";filtersChanged();els.input.focus();});
  els.cat.addEventListener("change",()=>{state.category=els.cat.value;filtersChanged();});
  els.lang.addEventListener("change",()=>{state.language=els.lang.value;filtersChanged();});
  els.sort.addEventListener("change",()=>{state.sort=els.sort.value;filtersChanged();});
  document.querySelectorAll("[data-scope]").forEach(b=>b.addEventListener("click",()=>{
    if (state.scope===b.dataset.scope) return;
    state.scope=b.dataset.scope;state.category="all";state.language="all";state.count=PAGE_SIZE;
    syncUrl();load(false);
  }));
  document.querySelectorAll("[data-quick]").forEach(b=>b.addEventListener("click",()=>{
    state.q=b.dataset.quick;els.input.value=state.q;filtersChanged();els.input.focus();
  }));
  els.more.addEventListener("click",()=>{state.count+=PAGE_SIZE;render();});
  els.refresh.addEventListener("click",()=>{try{localStorage.removeItem(cacheKey());}catch(_){} load(true);});
  els.copy.addEventListener("click",async()=>{
    syncUrl();
    try {
      await navigator.clipboard.writeText(location.href);
      els.copy.textContent="Copied!";
      setTimeout(()=>els.copy.textContent="Copy search link",1800);
    } catch (_) {window.prompt("Copy the search URL:",location.href);}
  });
  $("#reset").addEventListener("click",()=>{
    state.q="";state.category="all";state.language="all";state.sort="relevance";state.count=PAGE_SIZE;
    els.input.value="";drawFilters();filtersChanged();
  });
  document.addEventListener("keydown",(e)=>{
    const active=document.activeElement;
    const writing=active && ["INPUT","TEXTAREA","SELECT"].includes(active.tagName);
    if (e.key==="/" && !writing && !e.ctrlKey && !e.metaKey){e.preventDefault();els.input.focus();}
    if (e.key==="Escape" && active===els.input){els.input.blur();}
  });
  window.addEventListener("popstate",()=>{readLocation();state.count=PAGE_SIZE;load(false);});
  readLocation();
  load(false);
})();
