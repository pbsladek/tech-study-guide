(function () {
  const root = document.documentElement;
  const shell = document.querySelector(".app-shell");
  const storage = window.localStorage;
  const baseUrl = document.body.dataset.baseurl || "";
  const pageProgressKey = "pageProgress";
  const studyStatsKey = "studyStats";
  const studyFiltersKey = "studyFilters";
  const studyLastMissedKey = "studyLastMissed";
  const studyModal = document.querySelector("#study-modal");
  const studyTopicList = document.querySelector("#study-topic-list");
  const studyAllTopics = document.querySelector("#study-all-topics");
  const studyModeInputs = Array.from(document.querySelectorAll("input[name='study-mode']"));
  const studySizeSelect = document.querySelector("#study-size-select");
  const studyWeakOnly = document.querySelector("#study-weak-only");
  const studyMissedOnly = document.querySelector("#study-missed-only");
  const studyLastMissed = document.querySelector("#study-last-missed");
  const studyDueCounts = document.querySelector("#study-due-counts");
  const studyStatus = document.querySelector("#study-status");
  const studySummary = document.querySelector("#study-summary");
  const studyProgressText = document.querySelector("#study-progress-text");
  const studyProgressFill = document.querySelector("#study-progress-fill");
  const studyScoreText = document.querySelector("#study-score-text");
  const studyCardLabel = document.querySelector("#study-card-label");
  const studyCardState = document.querySelector("#study-card-state");
  const studyCardText = document.querySelector("#study-card-text");
  const studyCardHint = document.querySelector("#study-card-hint");
  const studyStageCard = document.querySelector("#study-stage-card");
  const studyBuryCard = document.querySelector("#study-bury-card");
  const studyTestControls = document.querySelector("#study-test-controls");
  const studyReport = document.querySelector("#study-report");
  const searchInput = document.querySelector("#site-search");
  const searchResults = document.querySelector("#search-results");
  const searchFilters = document.querySelector("#search-filters");
  const graphFilter = document.querySelector("#graph-filter");
  let studyDecks = null;
  let studyCards = [];
  let studyIndex = 0;
  let studyRevealed = false;
  let studyResults = [];
  let activeSearchTag = "";
  let activeSearchIndex = -1;
  let searchItems = [];
  let searchMatches = [];
  let studyTouchStartX = 0;
  let studyTouchStartY = 0;

  function readJson(key, fallback) {
    try {
      return JSON.parse(storage.getItem(key)) || fallback;
    } catch (error) {
      return fallback;
    }
  }

  function writeJson(key, value) {
    storage.setItem(key, JSON.stringify(value));
  }

  function applyPreference(name, value, fallback) {
    const selected = value || storage.getItem(name) || fallback;
    if (selected) {
      root.dataset[name] = selected;
    }
    return selected;
  }

  function setTheme(theme) {
    root.dataset.theme = theme;
    storage.setItem("theme", theme);
  }

  function setFont(font) {
    root.dataset.font = font;
    storage.setItem("font", font);
  }

  function setTextSize(size) {
    root.style.setProperty("--reader-size", `${size}%`);
    storage.setItem("textSize", size);
  }

  function titleize(value) {
    return value
      .split(/[-_]/)
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(" ");
  }

  function slugify(value) {
    return value
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "");
  }

  function normalizePath(value) {
    const link = document.createElement("a");
    link.href = value || window.location.pathname;
    let path = link.pathname;
    if (baseUrl && path.startsWith(baseUrl)) {
      path = path.slice(baseUrl.length) || "/";
    }
    return path.endsWith("/") ? path : `${path}/`;
  }

  function shuffle(items) {
    const shuffled = items.slice();
    for (let index = shuffled.length - 1; index > 0; index -= 1) {
      const swapIndex = Math.floor(Math.random() * (index + 1));
      [shuffled[index], shuffled[swapIndex]] = [shuffled[swapIndex], shuffled[index]];
    }
    return shuffled;
  }

  function copyText(value) {
    if (navigator.clipboard?.writeText) {
      return navigator.clipboard.writeText(value);
    }

    const textarea = document.createElement("textarea");
    textarea.value = value;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand("copy");
    textarea.remove();
    return Promise.resolve();
  }

  function tomorrowIsoDate() {
    const date = new Date();
    date.setDate(date.getDate() + 1);
    return date.toISOString().slice(0, 10);
  }

  function todayIsoDate() {
    return new Date().toISOString().slice(0, 10);
  }

  function pageProgress() {
    return readJson(pageProgressKey, {});
  }

  function isPageComplete(url) {
    return pageProgress()[normalizePath(url)] === true;
  }

  function updateCompleteButtons() {
    document.querySelectorAll("[data-action='mark-complete']").forEach((button) => {
      const complete = isPageComplete(button.dataset.pageUrl);
      button.classList.toggle("page-complete", complete);
      button.textContent = complete ? "Complete" : "Mark complete";
      button.setAttribute("aria-pressed", complete ? "true" : "false");
    });
  }

  function togglePageComplete(url) {
    const progress = pageProgress();
    const path = normalizePath(url);
    progress[path] = !progress[path];
    writeJson(pageProgressKey, progress);
    updateCompleteButtons();
    renderPathProgress();
  }

  function renderPathProgress() {
    const progress = pageProgress();
    document.querySelectorAll("[data-path-card]").forEach((card) => {
      const steps = Array.from(card.querySelectorAll("[data-path-step-url]"));
      const completeCount = steps.filter((step) => progress[normalizePath(step.dataset.pathStepUrl)]).length;
      const percent = steps.length > 0 ? Math.round((completeCount / steps.length) * 100) : 0;

      steps.forEach((step) => {
        const complete = progress[normalizePath(step.dataset.pathStepUrl)] === true;
        step.classList.toggle("is-complete", complete);
        const state = step.querySelector("[data-path-step-state]");
        if (state) state.textContent = complete ? "Complete" : "Not started";
      });

      const fill = card.querySelector("[data-path-progress-fill]");
      const text = card.querySelector("[data-path-progress-text]");
      if (fill) fill.style.width = `${percent}%`;
      if (text) text.textContent = `${completeCount} of ${steps.length} complete`;
    });
  }

  function renderPageToc() {
    const tocSection = document.querySelector("#page-toc-section");
    const toc = document.querySelector("#page-toc");
    const article = document.querySelector("article.content-card");
    if (!tocSection || !toc || !article) return;

    const headings = Array.from(article.querySelectorAll("h2, h3")).filter((heading) => heading.textContent.trim());
    if (headings.length < 2) return;

    toc.innerHTML = "";
    headings.forEach((heading) => {
      if (!heading.id) {
        heading.id = slugify(heading.textContent.trim());
      }
      const link = document.createElement("a");
      link.href = `#${heading.id}`;
      link.textContent = heading.textContent.trim();
      link.className = heading.tagName === "H3" ? "toc-depth-3" : "toc-depth-2";
      toc.appendChild(link);
    });
    tocSection.hidden = false;
  }

  function addCopyButtons() {
    document.querySelectorAll(".content-card pre").forEach((pre) => {
      const wrapper = pre.closest(".highlight, div[class^='language-']") || pre;
      if (wrapper.querySelector(":scope > .copy-code-button")) return;

      const button = document.createElement("button");
      button.type = "button";
      button.className = "copy-code-button";
      button.textContent = "Copy";
      button.addEventListener("click", () => {
        copyText(pre.innerText).then(() => {
          button.textContent = "Copied";
          window.setTimeout(() => {
            button.textContent = "Copy";
          }, 1200);
        });
      });
      wrapper.prepend(button);
    });
  }

  function cardId(card) {
    return `${card.deck}:${card.q}`;
  }

  function studyStats() {
    const stats = readJson(studyStatsKey, {});
    stats.cards ||= {};
    stats.decks ||= {};
    return stats;
  }

  function cardStats(card) {
    return studyStats().cards[cardId(card)] || { seen: 0, right: 0, wrong: 0, state: "new" };
  }

  function isWeakCard(card) {
    const stats = cardStats(card);
    return stats.state === "weak" || stats.wrong > stats.right;
  }

  function isMissedCard(card) {
    return cardStats(card).wrong > 0;
  }

  function isBuriedCard(card) {
    const buriedUntil = cardStats(card).buriedUntil;
    return buriedUntil && buriedUntil >= todayIsoDate();
  }

  function updateStudyStats(card, isRight) {
    const stats = studyStats();
    const id = cardId(card);
    const current = stats.cards[id] || { seen: 0, right: 0, wrong: 0, state: "new" };
    const deck = stats.decks[card.deck] || { seen: 0, right: 0, wrong: 0 };

    current.seen += 1;
    current.right += isRight ? 1 : 0;
    current.wrong += isRight ? 0 : 1;
    current.lastSeen = new Date().toISOString();
    current.state = current.wrong > current.right ? "weak" : current.right - current.wrong >= 3 ? "mastered" : "learning";

    deck.seen += 1;
    deck.right += isRight ? 1 : 0;
    deck.wrong += isRight ? 0 : 1;

    stats.cards[id] = current;
    stats.decks[card.deck] = deck;
    writeJson(studyStatsKey, stats);
  }

  function deckAccuracySummary(decks) {
    const stats = studyStats();
    return decks.map((deckName) => {
      const deck = stats.decks[deckName] || { seen: 0, right: 0, wrong: 0 };
      const answered = deck.right + deck.wrong;
      const percent = answered > 0 ? Math.round((deck.right / answered) * 100) : 0;
      return `${titleize(deckName)}: ${percent}% over ${answered} cards`;
    });
  }

  function loadStudyDecks() {
    if (studyDecks) return Promise.resolve(studyDecks);

    return fetch(`${baseUrl}/assets/js/study-decks.json`)
      .then((response) => response.json())
      .then((decks) => {
        studyDecks = decks;
        return studyDecks;
      });
  }

  function renderStudyTopics(preferredDeck) {
    if (!studyTopicList || !studyDecks) return;

    studyTopicList.innerHTML = "";

    Object.keys(studyDecks).forEach((deckName) => {
      const label = document.createElement("label");
      const checkbox = document.createElement("input");
      const name = document.createElement("span");
      const meter = document.createElement("span");
      const meterFill = document.createElement("span");
      const metric = document.createElement("small");
      const cardCount = studyDecks[deckName].cards.length;
      const stats = studyStats();
      const cards = studyDecks[deckName].cards.map((card) => ({ ...card, deck: deckName }));
      const mastered = cards.filter((card) => (stats.cards[cardId(card)] || {}).state === "mastered").length;
      const answered = cards.reduce((count, card) => {
        const cardRecord = stats.cards[cardId(card)] || {};
        return count + (cardRecord.right || 0) + (cardRecord.wrong || 0);
      }, 0);
      const right = cards.reduce((count, card) => count + ((stats.cards[cardId(card)] || {}).right || 0), 0);
      const accuracy = answered > 0 ? Math.round((right / answered) * 100) : 0;
      const masteredPercent = cardCount > 0 ? Math.round((mastered / cardCount) * 100) : 0;

      label.className = "study-topic-chip";
      label.dataset.deckName = deckName;
      checkbox.type = "checkbox";
      checkbox.value = deckName;
      checkbox.checked = preferredDeck ? deckName === preferredDeck : true;

      name.className = "study-topic-name";
      name.textContent = `${titleize(deckName)} (${cardCount})`;
      meter.className = "study-topic-meter";
      meterFill.style.width = `${masteredPercent}%`;
      metric.textContent = answered > 0 ? `${accuracy}% accuracy` : "new deck";

      label.appendChild(checkbox);
      label.appendChild(name);
      meter.appendChild(meterFill);
      label.appendChild(meter);
      label.appendChild(metric);
      studyTopicList.appendChild(label);
    });

    if (studyAllTopics) {
      studyAllTopics.checked = !preferredDeck;
    }
  }

  function selectedStudyDecks() {
    if (!studyTopicList || !studyDecks) return [];
    const checked = Array.from(studyTopicList.querySelectorAll("input[type='checkbox']:checked")).map((input) => input.value);
    return checked.length > 0 ? checked : Object.keys(studyDecks);
  }

  function selectedStudyMode() {
    return studyModeInputs.find((input) => input.checked)?.value || "review";
  }

  function lastMissedActive() {
    return studyLastMissed?.getAttribute("aria-pressed") === "true";
  }

  function saveStudyFilters() {
    if (!studyTopicList) return;
    writeJson(studyFiltersKey, {
      decks: selectedStudyDecks(),
      mode: selectedStudyMode(),
      size: studySizeSelect?.value || "all",
      weakOnly: studyWeakOnly?.checked || false,
      missedOnly: studyMissedOnly?.checked || false,
      lastMissedOnly: lastMissedActive()
    });
  }

  function applySavedStudyFilters(preferredDeck) {
    const filters = readJson(studyFiltersKey, {});

    if (studyTopicList) {
      const deckSelection = preferredDeck ? [preferredDeck] : filters.decks;
      if (Array.isArray(deckSelection) && deckSelection.length > 0) {
        studyTopicList.querySelectorAll("input[type='checkbox']").forEach((checkbox) => {
          checkbox.checked = deckSelection.includes(checkbox.value);
        });
      }
    }

    if (filters.mode) {
      studyModeInputs.forEach((input) => {
        input.checked = input.value === filters.mode;
      });
    }
    if (studySizeSelect && filters.size) studySizeSelect.value = filters.size;
    if (studyWeakOnly) studyWeakOnly.checked = Boolean(filters.weakOnly);
    if (studyMissedOnly) studyMissedOnly.checked = Boolean(filters.missedOnly);
    if (studyLastMissed) studyLastMissed.setAttribute("aria-pressed", filters.lastMissedOnly ? "true" : "false");
    updateStudyAllTopics();
  }

  function updateStudyAllTopics() {
    if (!studyAllTopics || !studyTopicList) return;
    const checkboxes = Array.from(studyTopicList.querySelectorAll("input[type='checkbox']"));
    studyAllTopics.checked = checkboxes.length > 0 && checkboxes.every((checkbox) => checkbox.checked);
  }

  function selectedPoolCards() {
    if (!studyDecks) return [];
    const lastMissed = readJson(studyLastMissedKey, []);
    return selectedStudyDecks()
      .flatMap((deckName) => studyDecks[deckName].cards.map((card) => ({ ...card, deck: deckName })))
      .filter((card) => !isBuriedCard(card))
      .filter((card) => !studyWeakOnly?.checked || isWeakCard(card))
      .filter((card) => !studyMissedOnly?.checked || isMissedCard(card))
      .filter((card) => !lastMissedActive() || lastMissed.includes(cardId(card)));
  }

  function updateStudySummary() {
    if (!studyDecks) return;
    const cards = selectedPoolCards();
    const weak = cards.filter(isWeakCard).length;
    const missed = cards.filter(isMissedCard).length;
    const fresh = cards.filter((card) => cardStats(card).state === "new").length;
    const minutes = cards.length > 0 ? Math.max(1, Math.ceil(cards.length * 0.35)) : 0;

    if (studySummary) {
      const set = (name, value) => {
        const target = studySummary.querySelector(`[data-study-summary="${name}"]`);
        if (target) target.textContent = value;
      };
      set("selected", cards.length);
      set("weak", weak);
      set("missed", missed);
      set("time", `${minutes}m`);
    }

    if (studyDueCounts) {
      studyDueCounts.textContent = `Due next: ${fresh} new, ${weak} weak, ${missed} missed`;
    }
  }

  function refreshStudySetup() {
    updateStudyAllTopics();
    updateStudySummary();
    saveStudyFilters();
  }

  function openStudy(preferredDeck) {
    if (!studyModal) return;

    studyModal.hidden = false;
    document.body.classList.add("study-open");
    studyStatus.textContent = "Loading decks.";

    loadStudyDecks()
      .then(() => {
        renderStudyTopics(preferredDeck);
        applySavedStudyFilters(preferredDeck);
        updateStudySummary();
        resetStudy();
        studyStatus.textContent = preferredDeck ? `${titleize(preferredDeck)} deck selected.` : "All topics selected.";
      })
      .catch(() => {
        studyStatus.textContent = "Study decks are unavailable.";
      });
  }

  function closeStudy() {
    if (!studyModal) return;
    studyModal.hidden = true;
    document.body.classList.remove("study-open");
  }

  function renderStudyStartCard() {
    if (studyStageCard) {
      studyStageCard.dataset.revealed = "false";
      studyStageCard.setAttribute("aria-pressed", "false");
      studyStageCard.classList.remove("is-advancing");
    }
    if (studyCardLabel) studyCardLabel.textContent = "Ready";
    if (studyCardState) studyCardState.textContent = "New";
    if (studyCardText) studyCardText.textContent = "Click card to start";
    if (studyCardHint) {
      studyCardHint.hidden = false;
      studyCardHint.textContent = "Filters are on the left. Click to begin.";
    }
  }

  function resetStudy() {
    studyCards = [];
    studyIndex = 0;
    studyRevealed = false;
    studyResults = [];
    renderStudyStartCard();
    if (studyProgressText) studyProgressText.textContent = "0 / 0";
    if (studyProgressFill) studyProgressFill.style.width = "0%";
    if (studyScoreText) studyScoreText.textContent = "Score: 0 right, 0 wrong";
    if (studyReport) {
      studyReport.hidden = true;
      studyReport.textContent = "";
    }
    if (studyTestControls) studyTestControls.hidden = true;
    if (studyBuryCard) studyBuryCard.hidden = true;
    updateStudySummary();
  }

  function updateStudyProgress() {
    const total = studyCards.length;
    const right = studyResults.filter((result) => result === true).length;
    const wrong = studyResults.filter((result) => result === false).length;

    if (studyProgressText) {
      studyProgressText.textContent = total > 0 ? `${studyIndex + 1} / ${total}` : "0 / 0";
    }
    if (studyScoreText) {
      studyScoreText.textContent = `Score: ${right} right, ${wrong} wrong`;
    }
    if (studyProgressFill) {
      studyProgressFill.style.width = total > 0 ? `${Math.round(((studyIndex + 1) / total) * 100)}%` : "0%";
    }
  }

  function renderStudyCard() {
    if (!studyCardLabel || !studyCardText || !studyStageCard) return;

    if (studyCards.length === 0) {
      resetStudy();
      return;
    }

    const card = studyCards[studyIndex];
    const stats = cardStats(card);
    studyCardLabel.textContent = studyRevealed ? `Answer - ${titleize(card.deck)}` : `Question - ${titleize(card.deck)}`;
    if (studyCardState) studyCardState.textContent = titleize(stats.state || "new");
    studyCardText.textContent = studyRevealed ? card.a : card.q;
    if (studyCardHint) {
      studyCardHint.hidden = false;
      studyCardHint.textContent = studyRevealed
        ? selectedStudyMode() === "test"
          ? "Mark this card below."
          : "Click again for the next card."
        : "Click to reveal the answer.";
    }
    studyStageCard.dataset.revealed = studyRevealed ? "true" : "false";
    studyStageCard.setAttribute("aria-pressed", studyRevealed ? "true" : "false");
    if (studyTestControls) {
      studyTestControls.hidden = selectedStudyMode() !== "test" || !studyRevealed;
    }
    if (studyBuryCard) studyBuryCard.hidden = false;
    updateStudyProgress();
  }

  function startStudy() {
    if (!studyDecks) return;

    const decks = selectedStudyDecks();
    let allCards = selectedPoolCards();

    const size = studySizeSelect?.value || "all";
    const shouldShuffle = size !== "all" || selectedStudyMode() === "test" || studyWeakOnly?.checked || studyMissedOnly?.checked;

    studyCards = shouldShuffle ? shuffle(allCards) : allCards;
    if (size !== "all") {
      studyCards = studyCards.slice(0, Number(size));
    }

    studyIndex = 0;
    studyRevealed = false;
    studyResults = new Array(studyCards.length).fill(null);

    if (studyTestControls) {
      studyTestControls.hidden = true;
    }
    if (studyReport) {
      studyReport.hidden = true;
      studyReport.textContent = "";
    }
    if (studyStatus) {
      const filteredText = studyMissedOnly?.checked ? " missed cards" : studyWeakOnly?.checked ? " weak cards" : " cards";
      studyStatus.textContent = `${studyCards.length}${filteredText} from ${decks.length} topic${decks.length === 1 ? "" : "s"}.`;
    }

    if (studyCards.length === 0) {
      renderStudyStartCard();
      if (studyStatus) studyStatus.textContent = "No cards match the current filters.";
      return;
    }

    renderStudyCard();
  }

  function moveStudyCard(direction) {
    if (studyCards.length === 0) return;
    studyIndex = (studyIndex + direction + studyCards.length) % studyCards.length;
    studyRevealed = false;
    renderStudyCard();
  }

  function revealStudyCard() {
    if (studyCards.length === 0) return;
    studyRevealed = !studyRevealed;
    renderStudyCard();
  }

  function startOrRevealStudyCard() {
    if (studyCards.length === 0) {
      startStudy();
      return;
    }

    if (studyRevealed && selectedStudyMode() === "review") {
      moveStudyCard(1);
      return;
    }

    if (studyRevealed && selectedStudyMode() === "test") {
      return;
    }

    revealStudyCard();
  }

  function markStudyCard(isRight) {
    if (studyCards.length === 0) return;

    const card = studyCards[studyIndex];
    studyResults[studyIndex] = isRight;
    updateStudyStats(card, isRight);
    updateStudyProgress();
    updateStudySummary();

    const answered = studyResults.filter((result) => result !== null).length;
    if (answered === studyCards.length && studyReport) {
      const right = studyResults.filter((result) => result === true).length;
      const percent = Math.round((right / studyCards.length) * 100);
      const decks = [...new Set(studyCards.map((item) => item.deck))];
      const missed = studyCards.filter((item, index) => studyResults[index] === false).map(cardId);
      writeJson(studyLastMissedKey, missed);
      renderStudyTopics();
      applySavedStudyFilters();
      updateStudySummary();
      studyReport.hidden = false;
      studyReport.innerHTML = `<strong>Complete:</strong> ${right} of ${studyCards.length} correct (${percent}%).<br>${deckAccuracySummary(decks).join("<br>")}`;
      return;
    }

    if (studyTestControls) studyTestControls.hidden = true;
    studyStageCard?.classList.add("is-advancing");
    window.setTimeout(() => {
      studyStageCard?.classList.remove("is-advancing");
      moveStudyCard(1);
    }, 220);
  }

  function buryCurrentCard() {
    if (studyCards.length === 0) return;
    const card = studyCards[studyIndex];
    const stats = studyStats();
    const id = cardId(card);
    stats.cards[id] ||= { seen: 0, right: 0, wrong: 0, state: "new" };
    stats.cards[id].buriedUntil = tomorrowIsoDate();
    writeJson(studyStatsKey, stats);

    studyCards.splice(studyIndex, 1);
    studyResults.splice(studyIndex, 1);
    if (studyIndex >= studyCards.length) studyIndex = Math.max(0, studyCards.length - 1);
    updateStudySummary();

    if (studyCards.length === 0) {
      resetStudy();
      if (studyStatus) studyStatus.textContent = "All remaining cards are buried for today.";
      return;
    }

    studyRevealed = false;
    renderStudyCard();
  }

  function renderSearchFilters() {
    if (!searchFilters || searchItems.length === 0) return;
    const tagCounts = new Map();
    searchItems.forEach((item) => {
      item.tags.forEach((tag) => tagCounts.set(tag, (tagCounts.get(tag) || 0) + 1));
    });

    const topTags = Array.from(tagCounts.entries())
      .sort((left, right) => right[1] - left[1] || left[0].localeCompare(right[0]))
      .slice(0, 12);

    searchFilters.innerHTML = "";
    topTags.forEach(([tag, count]) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "search-filter-chip";
      button.textContent = `${tag} ${count}`;
      button.dataset.searchTag = tag;
      button.setAttribute("aria-pressed", "false");
      searchFilters.appendChild(button);
    });
    searchFilters.hidden = false;
  }

  function renderSearch() {
    if (!searchInput || !searchResults) return;
    const query = searchInput.value.trim().toLowerCase();
    searchResults.innerHTML = "";
    activeSearchIndex = -1;

    if (query.length < 2 && !activeSearchTag) return;

    searchMatches = searchItems
      .filter((item) => {
        const matchesQuery =
          query.length < 2 ||
          [item.title, item.summary, item.content, item.tags.join(" ")]
            .join(" ")
            .toLowerCase()
            .includes(query);
        const matchesTag = !activeSearchTag || item.tags.includes(activeSearchTag);
        return matchesQuery && matchesTag;
      })
      .slice(0, 8);

    searchMatches.forEach((item) => {
      const link = document.createElement("a");
      link.href = item.url;
      link.innerHTML = `<strong>${item.title}</strong><span>${item.summary || item.tags.join(", ")}</span>`;
      searchResults.appendChild(link);
    });
  }

  function moveSearchFocus(direction) {
    const links = Array.from(searchResults?.querySelectorAll("a") || []);
    if (links.length === 0) return;
    activeSearchIndex = (activeSearchIndex + direction + links.length) % links.length;
    links.forEach((link, index) => link.classList.toggle("is-active", index === activeSearchIndex));
    links[activeSearchIndex].focus();
  }

  function renderGraphFilters() {
    const query = graphFilter?.value.trim().toLowerCase() || "";
    const activeCluster = document.querySelector(".graph-clusters [data-graph-cluster][aria-pressed='true']")?.dataset.graphCluster || "";

    document.querySelectorAll("[data-graph-node]").forEach((node) => {
      const clusterMatches = !activeCluster || node.dataset.graphCluster === activeCluster;
      const textMatches = !query || node.textContent.toLowerCase().includes(query);
      node.hidden = !(clusterMatches && textMatches);
    });
  }

  function highlightCurrentGraphLinks() {
    const currentPath = normalizePath(window.location.pathname);
    document.querySelectorAll("[data-graph-edge], .graph-title").forEach((link) => {
      link.classList.toggle("is-current-page", normalizePath(link.href) === currentPath);
    });
  }

  applyPreference("theme", null, window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
  applyPreference("font", null, "sans");
  setTextSize(storage.getItem("textSize") || "100");

  const fontControl = document.querySelector("#font-family-control");
  if (fontControl) {
    fontControl.value = root.dataset.font || "sans";
    fontControl.addEventListener("change", () => setFont(fontControl.value));
  }

  const sizeControl = document.querySelector("#text-size-control");
  if (sizeControl) {
    sizeControl.value = storage.getItem("textSize") || "100";
    sizeControl.addEventListener("input", () => setTextSize(sizeControl.value));
  }

  document.addEventListener("click", (event) => {
    const action = event.target.closest("[data-action]")?.dataset.action;
    const searchTag = event.target.closest("[data-search-tag]")?.dataset.searchTag;

    if (searchTag) {
      activeSearchTag = activeSearchTag === searchTag ? "" : searchTag;
      document.querySelectorAll("[data-search-tag]").forEach((button) => {
        button.setAttribute("aria-pressed", button.dataset.searchTag === activeSearchTag ? "true" : "false");
      });
      renderSearch();
      return;
    }

    const graphCluster = event.target.closest(".graph-clusters [data-graph-cluster]")?.dataset.graphCluster;
    if (graphCluster !== undefined) {
      document.querySelectorAll(".graph-clusters [data-graph-cluster]").forEach((button) => {
        button.setAttribute("aria-pressed", button.dataset.graphCluster === graphCluster ? "true" : "false");
      });
      renderGraphFilters();
      return;
    }

    if (!action) return;

    if (action === "toggle-theme") {
      setTheme(root.dataset.theme === "dark" ? "light" : "dark");
    }

    if (action === "toggle-reader") {
      document.body.classList.toggle("reader-mode");
      storage.setItem("readerMode", document.body.classList.contains("reader-mode") ? "on" : "off");
    }

    if (action === "toggle-runbook") {
      document.body.classList.toggle("runbook-mode");
      storage.setItem("runbookMode", document.body.classList.contains("runbook-mode") ? "on" : "off");
    }

    if (action === "mark-complete") {
      togglePageComplete(event.target.closest("[data-page-url]")?.dataset.pageUrl || window.location.pathname);
    }

    if (action === "copy-page-link") {
      copyText(window.location.href);
    }

    if (action === "open-study") {
      openStudy(event.target.closest("[data-study-deck]")?.dataset.studyDeck);
    }

    if (action === "close-study") {
      closeStudy();
    }

    if (action === "reset-study") {
      resetStudy();
    }

    if (action === "toggle-last-missed") {
      const pressed = studyLastMissed?.getAttribute("aria-pressed") === "true";
      studyLastMissed?.setAttribute("aria-pressed", pressed ? "false" : "true");
      refreshStudySetup();
      resetStudy();
    }

    if (action === "bury-card") {
      buryCurrentCard();
    }

    if (action === "mark-right") {
      markStudyCard(true);
    }

    if (action === "mark-wrong") {
      markStudyCard(false);
    }

    if (action === "collapse-sidebar" && shell) {
      shell.dataset.sidebarState = shell.dataset.sidebarState === "closed" ? "open" : "closed";
    }

    if (action === "toggle-sidebar" && shell) {
      shell.dataset.mobileSidebar = shell.dataset.mobileSidebar === "open" ? "closed" : "open";
    }
  });

  if (storage.getItem("readerMode") === "on") {
    document.body.classList.add("reader-mode");
  }

  if (storage.getItem("runbookMode") === "on") {
    document.body.classList.add("runbook-mode");
  }

  if (studyAllTopics && studyTopicList) {
    studyAllTopics.addEventListener("change", () => {
      studyTopicList.querySelectorAll("input[type='checkbox']").forEach((checkbox) => {
        checkbox.checked = studyAllTopics.checked;
      });
      refreshStudySetup();
      resetStudy();
    });

    studyTopicList.addEventListener("click", (event) => {
      const label = event.target.closest(".study-topic-chip");
      if (!label || event.target.matches("input")) return;

      const checkbox = label.querySelector("input[type='checkbox']");
      const checkboxes = Array.from(studyTopicList.querySelectorAll("input[type='checkbox']"));
      const checked = checkboxes.filter((item) => item.checked);
      event.preventDefault();

      if (checkbox.checked && checked.length === 1) {
        checkboxes.forEach((item) => {
          item.checked = true;
        });
      } else {
        checkboxes.forEach((item) => {
          item.checked = item === checkbox;
        });
      }

      refreshStudySetup();
      resetStudy();
    });

    studyTopicList.addEventListener("change", () => {
      refreshStudySetup();
      resetStudy();
    });
  }

  studyModeInputs.forEach((input) =>
    input.addEventListener("change", () => {
      refreshStudySetup();
      resetStudy();
    })
  );
  [studySizeSelect, studyWeakOnly, studyMissedOnly].forEach((control) => {
    control?.addEventListener("change", () => {
      refreshStudySetup();
      resetStudy();
    });
  });

  if (studyStageCard) {
    studyStageCard.addEventListener("click", () => startOrRevealStudyCard());
    studyStageCard.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        startOrRevealStudyCard();
      }

      if (event.key === "ArrowLeft") {
        event.preventDefault();
        moveStudyCard(-1);
      }

      if (event.key === "ArrowRight") {
        event.preventDefault();
        moveStudyCard(1);
      }

      if (event.key === "ArrowUp" || event.key === "ArrowDown") {
        event.preventDefault();
        revealStudyCard();
      }

      if (selectedStudyMode() === "test" && studyRevealed && (event.key === "1" || event.key === "2")) {
        event.preventDefault();
        markStudyCard(event.key === "2");
      }
    });

    studyStageCard.addEventListener(
      "touchstart",
      (event) => {
        const touch = event.changedTouches[0];
        studyTouchStartX = touch.clientX;
        studyTouchStartY = touch.clientY;
      },
      { passive: true }
    );

    studyStageCard.addEventListener(
      "touchend",
      (event) => {
        const touch = event.changedTouches[0];
        const deltaX = touch.clientX - studyTouchStartX;
        const deltaY = touch.clientY - studyTouchStartY;
        if (Math.abs(deltaX) < 45 || Math.abs(deltaX) < Math.abs(deltaY)) return;
        if (studyCards.length === 0 || selectedStudyMode() !== "review") return;
        event.preventDefault();
        moveStudyCard(deltaX < 0 ? 1 : -1);
      },
      { passive: false }
    );
  }

  document.querySelectorAll(".study-card").forEach((card) => {
    const flip = () => {
      card.classList.toggle("flipped");
      card.setAttribute("aria-pressed", card.classList.contains("flipped") ? "true" : "false");
    };

    card.addEventListener("click", flip);
    card.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        flip();
      }

      if (event.key === "ArrowUp" || event.key === "ArrowDown") {
        event.preventDefault();
        flip();
      }

      if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
        const cards = Array.from(document.querySelectorAll(".study-card"));
        const offset = event.key === "ArrowLeft" ? -1 : 1;
        const nextIndex = (cards.indexOf(card) + offset + cards.length) % cards.length;

        event.preventDefault();
        cards[nextIndex]?.focus();
      }
    });
  });

  if (searchInput && searchResults) {
    fetch(`${baseUrl}/assets/js/search-index.json`)
      .then((response) => response.json())
      .then((items) => {
        searchItems = items;
        renderSearchFilters();
        searchInput.addEventListener("input", renderSearch);
        searchInput.addEventListener("keydown", (event) => {
          if (event.key === "ArrowDown") {
            event.preventDefault();
            moveSearchFocus(1);
          }

          if (event.key === "Escape") {
            searchInput.value = "";
            activeSearchTag = "";
            document.querySelectorAll("[data-search-tag]").forEach((button) => button.setAttribute("aria-pressed", "false"));
            renderSearch();
          }
        });
        searchResults.addEventListener("keydown", (event) => {
          if (event.key === "ArrowDown") {
            event.preventDefault();
            moveSearchFocus(1);
          }

          if (event.key === "ArrowUp") {
            event.preventDefault();
            moveSearchFocus(-1);
          }
        });
        searchResults.dataset.ready = "true";
      })
      .catch(() => {
        searchResults.innerHTML = "";
      });
  }

  if (graphFilter) {
    graphFilter.addEventListener("input", renderGraphFilters);
    highlightCurrentGraphLinks();
    renderGraphFilters();
  }

  updateCompleteButtons();
  renderPathProgress();
  renderPageToc();
  addCopyButtons();
})();
