# ADR 0006: groepeer aanbiedingen per supermarkt en periode

- Status: geaccepteerd
- Datum: 2026-07-31

## Context

Een supermarkt heeft vaak tientallen producten tegelijk in de aanbieding. Het
eerste beheermodel maakte voor ieder ingrediënt een afzonderlijke aanbieding en
bood een niet-relevante prijsinvoer. Dat veroorzaakt herhaald werk en maakt het
overzicht onnodig lang.

## Besluit

Een aanbieding hoort bij precies één supermarkt en één geldigheidsperiode, en wordt
via een koppeltabel aan één of meer canonieke ingrediënten gekoppeld. De beheerder
zoekt ingrediënten op naam en vinkt meerdere resultaten aan. Ontbrekende
ingrediënten en supermarkten kunnen in de bestaande zijbalk worden toegevoegd.

Prijs wordt niet meer gevraagd, gevalideerd of getoond. De bestaande kolommen
`offers.ingredient_id` en `offers.price_cents` blijven tijdens deze expand-fase in
het schema staan. Nieuwe code gebruikt `ingredient_id` alleen als compatibele
verwijzing naar het eerste gekoppelde ingrediënt; `price_cents` blijft leeg. Een
volgende contractmigratie mag beide kolommen verwijderen nadat alle actieve
applicatieversies de koppeltabel gebruiken.

De migratie zet iedere bestaande ingrediëntkoppeling over naar de nieuwe
koppeltabel. Dit verandert de 3/2/1/0-ranking niet: een ingrediënt telt nog steeds
alleen mee als de aanbieding actueel is en bij een geselecteerde supermarkt hoort.

## Gevolgen

- Een actie met 30 tot 40 producten wordt één beheerd record.
- De zoekbediening werkt als JavaScript-verrijking; zonder JavaScript blijft de
  volledige lijst met selectievakjes bruikbaar.
- De koppeltabel voorkomt dubbele ingrediënten binnen dezelfde aanbieding.
- De compatibiliteitskolommen worden nu bewust nog niet destructief verwijderd.
