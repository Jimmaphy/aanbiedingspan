# ADR 0007: Zoekgestuurde selectie en receptmedia

- Status: geaccepteerd
- Datum: 2026-07-31

## Context

Ingrediëntenlijsten groeien snel en zijn daardoor niet geschikt om standaard volledig te tonen.
Daarnaast onderbreken de snelle formulieren in de beheerzijbalk nu het hoofdformulier. Recepten
missen nog een afbeelding en de koppeling met de gerechtswensen uit stap 1 van de publieke wizard.

## Besluit

- Beheer- en wizardformulieren gebruiken dezelfde zoekgestuurde ingrediëntenpicker. Zonder
  zoekterm worden alleen gekozen ingrediënten getoond; tijdens zoeken verschijnen passende,
  nog niet gekozen ingrediënten.
- Snelle zijbalkformulieren worden met native JavaScript verzonden. De server antwoordt op een
  JSON-verzoek met het aangemaakte item, zodat het huidige formulier, inclusief een gekozen
  afbeeldingsbestand, in de pagina blijft staan. Zonder JavaScript blijft de bestaande redirect
  als terugval beschikbaar.
- Alle beheerlijsten ondersteunen een begrensde, server-side zoekterm via `q`. Zoektermen komen
  alleen in beheer-URL's en bevatten geen publieke wizardkeuzes.
- Recepten krijgen een optioneel lokaal afbeeldingspad en een veel-op-veelrelatie met beheerde
  gerechtswensen. De eerste migratie vult de huidige wizardwensen idempotent als beheerde tags.
- Afbeeldingen worden handmatig geüpload als JPEG, PNG of WebP, maximaal 5 MB. Bestandsnamen
  worden server-side willekeurig gemaakt; de oorspronkelijke naam wordt niet gebruikt als pad.
  De standaard lokale opslag is `Public/uploads/recipes`. Een latere productie-uitrol kan dit
  achter een opslagservice vervangen zonder het databaseschema te wijzigen.

## Gevolgen

- Grote catalogi blijven hanteerbaar en de bediening is gelijk in beheer en wizard.
- Inline aanmaken vereist JavaScript om zonder paginawissel te werken; de mutatie blijft ook
  zonder JavaScript bruikbaar, maar dan kan een browser een bestandsveld niet veilig herstellen.
- De migratie is additief. Bestaande recepten houden de tijdelijke standaardafbeelding totdat een
  beheerder een afbeelding toevoegt.
- Uploadmappen moeten in productie duurzaam en alleen voor toegestane afbeeldingsformaten
  beschrijfbaar zijn. Actieve inhoud zoals SVG wordt niet geaccepteerd.
