(() => {
    "use strict";

    const mainForm = document.querySelector("[data-admin-main-form]");
    window.AanbiedingspanIngredientPicker?.initialize(document);

    function addSelectOption(name, item) {
        const select = mainForm?.querySelector(`select[name="${name}"]`);
        if (!select) return;
        select.querySelectorAll("option").forEach((option) => (option.selected = false));
        const option = document.createElement("option");
        option.value = item.id;
        option.textContent = item.name;
        option.selected = true;
        select.append(option);
        select.focus();
    }

    function addDietaryPreference(item) {
        const choices = mainForm?.querySelector('input[name="dietaryPreferenceIDs[]"]')?.closest(".choice-grid");
        if (!choices) return;
        if (choices.querySelector(`input[value="${CSS.escape(item.id)}"]`)) return;
        const label = document.createElement("label");
        label.className = "choice-card";
        const input = document.createElement("input");
        input.type = "checkbox";
        input.name = "dietaryPreferenceIDs[]";
        input.value = item.id;
        input.checked = true;
        const name = document.createElement("span");
        name.textContent = item.name;
        label.append(input, name);
        choices.append(label);
        input.focus();
    }

    document.querySelectorAll("[data-quick-create]").forEach((form) => {
        form.addEventListener("submit", async (event) => {
            event.preventDefault();
            const status = form.querySelector("[data-quick-status]");
            const button = form.querySelector("button[type='submit']");
            status.textContent = "Bezig met toevoegen…";
            button.disabled = true;

            try {
                const response = await fetch(form.action, {
                    method: "POST",
                    body: new FormData(form),
                    headers: { Accept: "application/json" },
                });
                if (!response.ok) throw new Error("Quick create failed");
                const item = await response.json();
                if (item.kind === "ingredient") {
                    window.AanbiedingspanIngredientPicker?.addIngredient(document, item);
                    mainForm?.querySelector(`input[value="${CSS.escape(item.id)}"]`)?.focus();
                } else if (item.kind === "recipeSource") {
                    addSelectOption("sourceID", item);
                } else if (item.kind === "supermarket") {
                    addSelectOption("supermarketID", item);
                } else if (item.kind === "dietaryPreference") {
                    addDietaryPreference(item);
                }
                form.reset();
                status.textContent = `${item.name} is toegevoegd. Je andere invoer is bewaard.`;
            } catch {
                status.textContent = "Toevoegen lukt nu niet. Controleer de invoer en probeer opnieuw.";
            } finally {
                button.disabled = false;
            }
        });
    });
})();
