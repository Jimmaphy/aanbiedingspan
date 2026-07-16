(() => {
    "use strict";

    const storageKey = "aanbiedingspan.wizard.v1";
    const storageVersion = 1;
    const storageLifetimeMilliseconds = 90 * 24 * 60 * 60 * 1000;

    function readStoredPreferences() {
        try {
            const value = window.localStorage.getItem(storageKey);
            if (!value) return null;

            const preferences = JSON.parse(value);
            if (preferences.version !== storageVersion || preferences.expiresAt <= Date.now()) {
                window.localStorage.removeItem(storageKey);
                return null;
            }
            return preferences;
        } catch {
            window.localStorage.removeItem(storageKey);
            return null;
        }
    }

    function selectedValues(form, name) {
        return Array.from(form.querySelectorAll(`input[name="${name}"]:checked`)).map(
            (input) => input.value
        );
    }

    function storePreferences(form) {
        const consent = form.querySelector("[data-storage-consent]");
        if (!consent?.checked) return;

        const now = Date.now();
        const preferences = {
            version: storageVersion,
            consentedAt: now,
            expiresAt: now + storageLifetimeMilliseconds,
            dietaryPreferences: selectedValues(form, "dietaryPreferences[]"),
            pantryIngredients: selectedValues(form, "pantryIngredients[]"),
            excludedIngredients: selectedValues(form, "excludedIngredients[]"),
            supermarkets: selectedValues(form, "supermarkets[]"),
        };
        window.localStorage.setItem(storageKey, JSON.stringify(preferences));
    }

    function applyStoredPreferences(form, preferences) {
        if (!preferences) return;

        const groups = [
            "dietaryPreferences",
            "pantryIngredients",
            "excludedIngredients",
            "supermarkets",
        ];
        groups.forEach((group) => {
            const selected = new Set(preferences[group] || []);
            form.querySelectorAll(`input[name="${group}[]"]`).forEach((input) => {
                input.checked = selected.has(input.value);
            });
        });

        const consent = form.querySelector("[data-storage-consent]");
        if (consent) consent.checked = true;
    }

    function initializeWizard(main, form) {
        const isResultsPage = main.dataset.searchState === "results";
        const steps = Array.from(form.querySelectorAll("[data-step]"));
        const indicators = Array.from(form.querySelectorAll("[data-step-indicator]"));
        const previousButton = form.querySelector("[data-previous]");
        const nextButton = form.querySelector("[data-next]");
        const submitButton = form.querySelector("[data-submit]");
        const progress = form.querySelector(".wizard-progress");
        let currentStep = 1;

        function showStep(stepNumber) {
            currentStep = Math.max(1, Math.min(steps.length, stepNumber));
            steps.forEach((step) => {
                step.hidden = Number(step.dataset.step) !== currentStep;
            });
            indicators.forEach((indicator) => {
                if (Number(indicator.dataset.stepIndicator) === currentStep) {
                    indicator.setAttribute("aria-current", "step");
                } else {
                    indicator.removeAttribute("aria-current");
                }
            });
            previousButton.hidden = currentStep === 1;
            nextButton.hidden = currentStep === steps.length;
            submitButton.hidden = false;
        }

        function showFilterMode() {
            form.hidden = false;
            form.classList.add("filter-mode");
            steps.forEach((step) => (step.hidden = false));
            progress.hidden = true;
            previousButton.hidden = true;
            nextButton.hidden = true;
            submitButton.hidden = false;
            form.scrollIntoView({ behavior: "smooth", block: "start" });
        }

        previousButton?.addEventListener("click", () => showStep(currentStep - 1));
        nextButton?.addEventListener("click", () => showStep(currentStep + 1));
        main.querySelector("[data-edit-filters]")?.addEventListener("click", showFilterMode);

        if (isResultsPage) {
            form.hidden = true;
        } else {
            showStep(1);
        }
    }

    function initializeExclusiveIngredients(form) {
        form.querySelectorAll("[data-exclusive-group]").forEach((input) => {
            input.addEventListener("change", () => {
                if (!input.checked) return;
                const oppositeGroup = input.dataset.exclusiveGroup === "pantry" ? "excluded" : "pantry";
                const opposite = form.querySelector(
                    `[data-exclusive-group="${oppositeGroup}"][value="${CSS.escape(input.value)}"]`
                );
                if (opposite) opposite.checked = false;
            });
        });
    }

    function initializeStorage(form) {
        const storedPreferences = readStoredPreferences();
        applyStoredPreferences(form, storedPreferences);

        const consent = form.querySelector("[data-storage-consent]");
        consent?.addEventListener("change", () => {
            if (consent.checked) {
                storePreferences(form);
            } else {
                window.localStorage.removeItem(storageKey);
            }
        });

        form.addEventListener("change", () => storePreferences(form));
        form.querySelector("[data-reset]")?.addEventListener("click", () => {
            window.localStorage.removeItem(storageKey);
            window.location.assign("/");
        });

        const informationButton = form.querySelector("[data-storage-info]");
        const explanation = form.querySelector("#storage-explanation");
        informationButton?.addEventListener("click", () => {
            const willOpen = explanation.hidden;
            explanation.hidden = !willOpen;
            informationButton.setAttribute("aria-expanded", String(willOpen));
        });
    }

    function initializeAsyncSearch(main, form) {
        const status = form.querySelector("[data-form-status]");
        form.addEventListener("submit", async (event) => {
            event.preventDefault();
            storePreferences(form);
            status.textContent = "We zoeken recepten die bij je keuzes passen…";

            const submitButton = form.querySelector("[data-submit]");
            submitButton.disabled = true;
            try {
                const body = new URLSearchParams(new FormData(form));
                const response = await fetch(form.action, {
                    method: "POST",
                    body,
                    headers: { Accept: "text/html" },
                });
                if (!response.ok) throw new Error("Search failed");

                const documentText = await response.text();
                const nextDocument = new DOMParser().parseFromString(documentText, "text/html");
                const nextMain = nextDocument.querySelector("#main-content");
                if (!nextMain) throw new Error("Search response is incomplete");

                main.replaceWith(nextMain);
                document.title = nextDocument.title;
                initializeSearchPage();
                nextMain.querySelector("#results-heading")?.focus({ preventScroll: true });
                nextMain.scrollIntoView({ behavior: "smooth", block: "start" });
            } catch {
                status.textContent = "Zoeken lukt nu niet. Probeer het nog een keer.";
                submitButton.disabled = false;
            }
        });
    }

    function initializeSearchPage() {
        const main = document.querySelector("#main-content[data-search-state]");
        const form = main?.querySelector("[data-search-form]");
        if (!main || !form || form.dataset.initialized === "true") return;

        form.dataset.initialized = "true";
        initializeStorage(form);
        initializeExclusiveIngredients(form);
        initializeWizard(main, form);
        initializeAsyncSearch(main, form);
    }

    initializeSearchPage();
})();
