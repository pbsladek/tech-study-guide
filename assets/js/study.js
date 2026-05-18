(function () {
  const root = document.documentElement;
  const shell = document.querySelector(".app-shell");
  const storage = window.localStorage;
  const baseUrl = document.body.dataset.baseurl || "";
  const studyModal = document.querySelector("#study-modal");
  const studyTopicList = document.querySelector("#study-topic-list");
  const studyAllTopics = document.querySelector("#study-all-topics");
  const studyModeSelect = document.querySelector("#study-mode-select");
  const studySizeSelect = document.querySelector("#study-size-select");
  const studyStatus = document.querySelector("#study-status");
  const studyProgressText = document.querySelector("#study-progress-text");
  const studyScoreText = document.querySelector("#study-score-text");
  const studyCardLabel = document.querySelector("#study-card-label");
  const studyCardText = document.querySelector("#study-card-text");
  const studyStageCard = document.querySelector("#study-stage-card");
  const studyTestControls = document.querySelector("#study-test-controls");
  const studyReport = document.querySelector("#study-report");
  let studyDecks = null;
  let studyCards = [];
  let studyIndex = 0;
  let studyRevealed = false;
  let studyResults = [];

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

  function shuffle(items) {
    const shuffled = items.slice();
    for (let index = shuffled.length - 1; index > 0; index -= 1) {
      const swapIndex = Math.floor(Math.random() * (index + 1));
      [shuffled[index], shuffled[swapIndex]] = [shuffled[swapIndex], shuffled[index]];
    }
    return shuffled;
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
      const cardCount = studyDecks[deckName].cards.length;

      checkbox.type = "checkbox";
      checkbox.value = deckName;
      checkbox.checked = preferredDeck ? deckName === preferredDeck : true;

      label.appendChild(checkbox);
      label.appendChild(document.createTextNode(`${titleize(deckName)} (${cardCount})`));
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

  function updateStudyAllTopics() {
    if (!studyAllTopics || !studyTopicList) return;
    const checkboxes = Array.from(studyTopicList.querySelectorAll("input[type='checkbox']"));
    studyAllTopics.checked = checkboxes.length > 0 && checkboxes.every((checkbox) => checkbox.checked);
  }

  function openStudy(preferredDeck) {
    if (!studyModal) return;

    studyModal.hidden = false;
    document.body.classList.add("study-open");
    studyStatus.textContent = "Loading decks.";

    loadStudyDecks()
      .then(() => {
        renderStudyTopics(preferredDeck);
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

  function resetStudy() {
    studyCards = [];
    studyIndex = 0;
    studyRevealed = false;
    studyResults = [];
    if (studyStageCard) studyStageCard.dataset.revealed = "false";
    if (studyStageCard) studyStageCard.setAttribute("aria-pressed", "false");
    if (studyCardLabel) studyCardLabel.textContent = "Question";
    if (studyCardText) studyCardText.textContent = "Start a study session.";
    if (studyProgressText) studyProgressText.textContent = "0 / 0";
    if (studyScoreText) studyScoreText.textContent = "Score: 0 right, 0 wrong";
    if (studyReport) {
      studyReport.hidden = true;
      studyReport.textContent = "";
    }
    if (studyTestControls) studyTestControls.hidden = true;
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
  }

  function renderStudyCard() {
    if (!studyCardLabel || !studyCardText || !studyStageCard) return;

    if (studyCards.length === 0) {
      resetStudy();
      return;
    }

    const card = studyCards[studyIndex];
    studyCardLabel.textContent = studyRevealed ? "Answer" : `Question - ${titleize(card.deck)}`;
    studyCardText.textContent = studyRevealed ? card.a : card.q;
    studyStageCard.dataset.revealed = studyRevealed ? "true" : "false";
    studyStageCard.setAttribute("aria-pressed", studyRevealed ? "true" : "false");
    updateStudyProgress();
  }

  function startStudy() {
    if (!studyDecks) return;

    const decks = selectedStudyDecks();
    const allCards = decks.flatMap((deckName) => {
      return studyDecks[deckName].cards.map((card) => ({ ...card, deck: deckName }));
    });
    const size = studySizeSelect?.value || "all";
    const shouldShuffle = size !== "all" || studyModeSelect?.value === "test";

    studyCards = shouldShuffle ? shuffle(allCards) : allCards;
    if (size !== "all") {
      studyCards = studyCards.slice(0, Number(size));
    }

    studyIndex = 0;
    studyRevealed = false;
    studyResults = new Array(studyCards.length).fill(null);

    if (studyTestControls) {
      studyTestControls.hidden = studyModeSelect?.value !== "test";
    }
    if (studyReport) {
      studyReport.hidden = true;
      studyReport.textContent = "";
    }
    if (studyStatus) {
      studyStatus.textContent = `${studyCards.length} cards from ${decks.length} topic${decks.length === 1 ? "" : "s"}.`;
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

  function markStudyCard(isRight) {
    if (studyCards.length === 0) return;

    studyResults[studyIndex] = isRight;
    updateStudyProgress();

    const answered = studyResults.filter((result) => result !== null).length;
    if (answered === studyCards.length && studyReport) {
      const right = studyResults.filter((result) => result === true).length;
      const percent = Math.round((right / studyCards.length) * 100);
      studyReport.hidden = false;
      studyReport.textContent = `Complete: ${right} of ${studyCards.length} correct (${percent}%).`;
      return;
    }

    moveStudyCard(1);
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
    if (!action) return;

    if (action === "toggle-theme") {
      setTheme(root.dataset.theme === "dark" ? "light" : "dark");
    }

    if (action === "toggle-reader") {
      document.body.classList.toggle("reader-mode");
      storage.setItem("readerMode", document.body.classList.contains("reader-mode") ? "on" : "off");
    }

    if (action === "open-study") {
      openStudy(event.target.closest("[data-study-deck]")?.dataset.studyDeck);
    }

    if (action === "close-study") {
      closeStudy();
    }

    if (action === "start-study") {
      startStudy();
    }

    if (action === "reset-study") {
      resetStudy();
    }

    if (action === "previous-card") {
      moveStudyCard(-1);
    }

    if (action === "next-card") {
      moveStudyCard(1);
    }

    if (action === "reveal-card") {
      revealStudyCard();
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

  if (studyAllTopics && studyTopicList) {
    studyAllTopics.addEventListener("change", () => {
      studyTopicList.querySelectorAll("input[type='checkbox']").forEach((checkbox) => {
        checkbox.checked = studyAllTopics.checked;
      });
    });

    studyTopicList.addEventListener("change", updateStudyAllTopics);
  }

  if (studyStageCard) {
    studyStageCard.addEventListener("click", () => revealStudyCard());
    studyStageCard.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        revealStudyCard();
      }
    });
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
    });
  });

  const searchInput = document.querySelector("#site-search");
  const searchResults = document.querySelector("#search-results");

  if (searchInput && searchResults) {
    fetch(`${baseUrl}/assets/js/search-index.json`)
      .then((response) => response.json())
      .then((items) => {
        searchInput.addEventListener("input", () => {
          const query = searchInput.value.trim().toLowerCase();
          searchResults.innerHTML = "";

          if (query.length < 2) return;

          const matches = items
            .filter((item) => {
              return [item.title, item.summary, item.content, item.tags.join(" ")]
                .join(" ")
                .toLowerCase()
                .includes(query);
            })
            .slice(0, 8);

          matches.forEach((item) => {
            const link = document.createElement("a");
            link.href = item.url;
            link.innerHTML = `<strong>${item.title}</strong><span>${item.summary || item.tags.join(", ")}</span>`;
            searchResults.appendChild(link);
          });
        });
      })
      .catch(() => {
        searchResults.innerHTML = "";
      });
  }
})();
