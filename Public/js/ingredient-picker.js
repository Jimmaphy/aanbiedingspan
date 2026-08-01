(() => {
    "use strict";

    const states = new WeakMap();

    function normalize(value) {
        return value.toLocaleLowerCase("nl").normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    }

    function render(picker) {
        const state = states.get(picker);
        if (!state) return;
        const focusedInput = picker.contains(document.activeElement)
            && document.activeElement.matches("input[type='checkbox']")
            ? document.activeElement
            : null;
        const query = normalize(state.search.value.trim());
        let resultCount = 0;
        let selectedCount = 0;

        state.options.forEach((option) => {
            const checkbox = option.querySelector("input[type='checkbox']");
            if (checkbox.checked) {
                selectedCount += 1;
                option.hidden = false;
                state.selected.append(option);
            } else {
                const matches = query !== "" && normalize(option.dataset.ingredientName || "").includes(query);
                option.hidden = !matches;
                if (matches) resultCount += 1;
                state.results.append(option);
            }
        });

        state.results.hidden = query === "" || resultCount === 0;
        state.empty.hidden = selectedCount > 0;
        const selectedText = selectedCount === 1 ? "1 ingrediënt gekozen." : `${selectedCount} ingrediënten gekozen.`;
        const resultText = resultCount === 1 ? "1 zoekresultaat." : `${resultCount} zoekresultaten.`;
        state.status.textContent = query === "" ? selectedText : `${resultText} ${selectedText}`;
        focusedInput?.focus();
    }

    function visibleResultInputs(state) {
        return state.options
            .filter((option) => option.parentElement === state.results && !option.hidden)
            .map((option) => option.querySelector("input[type='checkbox']"))
            .filter(Boolean);
    }

    function initialize(root = document) {
        root.querySelectorAll("[data-ingredient-picker]").forEach((picker) => {
            if (states.has(picker)) return;
            const state = {
                search: picker.querySelector("[data-ingredient-search]"),
                status: picker.querySelector("[data-ingredient-status]"),
                results: picker.querySelector("[data-ingredient-results]"),
                selected: picker.querySelector("[data-ingredient-selected]"),
                empty: picker.querySelector("[data-ingredient-empty]"),
                options: Array.from(picker.querySelectorAll("[data-ingredient-option]")),
            };
            if (Object.values(state).some((value) => !value)) return;
            states.set(picker, state);
            state.search.addEventListener("input", () => render(picker));
            state.search.addEventListener("keydown", (event) => {
                if (event.key !== "ArrowDown") return;
                const firstResult = visibleResultInputs(state)[0];
                if (!firstResult) return;
                event.preventDefault();
                firstResult.focus();
            });
            state.results.addEventListener("mousedown", (event) => {
                if (event.button === 0 && event.target.closest("[data-ingredient-option]")) {
                    event.preventDefault();
                }
            });
            state.results.addEventListener("keydown", (event) => {
                if ([" ", "Spacebar", "Enter"].includes(event.key)) {
                    const input = event.target.closest("input[type='checkbox']");
                    if (!input) return;
                    event.preventDefault();
                    input.checked = !input.checked;
                    input.dispatchEvent(new Event("change", { bubbles: true }));
                    return;
                }
                if (!["ArrowDown", "ArrowUp"].includes(event.key)) return;
                const inputs = visibleResultInputs(state);
                const currentIndex = inputs.indexOf(event.target);
                if (currentIndex < 0) return;
                const nextIndex = event.key === "ArrowDown"
                    ? Math.min(currentIndex + 1, inputs.length - 1)
                    : Math.max(currentIndex - 1, 0);
                event.preventDefault();
                inputs[nextIndex].focus();
            });
            picker.addEventListener("change", (event) => {
                const input = event.target.closest("input[type='checkbox']");
                if (input?.checked && input.dataset.exclusiveGroup) {
                    const oppositeGroup = input.dataset.exclusiveGroup === "pantry" ? "excluded" : "pantry";
                    const opposite = root.querySelector(
                        `[data-exclusive-group="${oppositeGroup}"][value="${CSS.escape(input.value)}"]`
                    );
                    if (opposite) {
                        opposite.checked = false;
                        render(opposite.closest("[data-ingredient-picker]"));
                    }
                }
                render(picker);
            });
            render(picker);
        });
    }

    function addIngredient(root, ingredient) {
        root.querySelectorAll("[data-ingredient-picker]").forEach((picker) => {
            const state = states.get(picker);
            if (!state || state.options.some((option) => option.querySelector("input")?.value === ingredient.id)) return;
            const label = document.createElement("label");
            label.dataset.ingredientOption = "";
            label.dataset.ingredientName = ingredient.name;
            label.dataset.ingredientId = ingredient.id;
            const input = document.createElement("input");
            input.type = "checkbox";
            input.name = "ingredientIDs[]";
            input.value = ingredient.id;
            input.checked = true;
            const name = document.createElement("span");
            name.textContent = ingredient.name;
            label.append(input, name);
            state.options.push(label);
            state.results.append(label);
            render(picker);
        });
    }

    window.AanbiedingspanIngredientPicker = { initialize, addIngredient };
})();
