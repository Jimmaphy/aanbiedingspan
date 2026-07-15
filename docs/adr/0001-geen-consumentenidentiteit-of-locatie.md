# ADR 0001: geen consumentenidentiteit of locatie

- Status: geaccepteerd
- Datum: 2026-07-15

## Context

Aanbiedingspan heeft voor de receptzoekfunctie geen consumentenaccount of locatie
nodig. Wizardkeuzes zijn wel nodig om een zoekopdracht te beantwoorden en mogen in
de browser worden onthouden.

## Besluit

- Er komen geen consumentenaccounts, bezoekersprofielen of publieke sessies.
- De applicatie vraagt, verwerkt en bewaart geen locatie, postcode of adres.
- Gebruikers kiezen supermarktketens uit een algemene lijst, zonder filialen.
- Wizardkeuzes mogen pas na een expliciete, vooraf uitgevinkte opt-in in
  `localStorage` staan en mogen in een POST-request naar Vapor gaan.
- De server verwerkt wizardkeuzes alleen voor de actuele response en bewaart of
  logt ze niet.
- “Wizard opnieuw starten” wist de lokale keuzes en opent stap één.
- Weigering wordt niet opgeslagen; zonder opt-in begint een volgend bezoek opnieuw.
- Alleen administratoraccounts gebruiken authenticatie en server-side sessies.

## Gevolgen

Zoeken en ranking kunnen centraal in een pure Swift-service worden getest. Een
POST-flow biedt progressive enhancement zonder keuzes in de URL te plaatsen. Er is
geen cookiewall nodig: de optionele lokale opslag wordt in de wizard uitgelegd en
de zoekfunctie blijft volledig beschikbaar wanneer de gebruiker weigert.
Applicatie-, proxy- en platformlogs moeten requestbodies en bezoekerskenmerken
uitsluiten. Automatische tests controleren resetgedrag en dat er geen publieke
profielen, locaties of persistente wizardkeuzes ontstaan.
