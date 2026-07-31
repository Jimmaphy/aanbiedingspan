# ADR 0005: relationeel beheer van de catalogus

- Status: geaccepteerd
- Datum: 2026-07-31

## Context

De publieke proef gebruikt een catalogus met demodata in het geheugen. Beheerders
moeten ingrediënten, supermarkten, aanbiedingen, recepten en receptbronnen apart
kunnen beheren. Tijdens het invoeren van een aanbieding of recept moeten ontbrekende
gerelateerde gegevens direct kunnen worden toegevoegd. Hoeveelheden, gewichten en
eenheden van receptingrediënten zijn voor deze beheerfase niet nodig.

## Besluit

We slaan de vijf beheertypen en hun koppelingen relationeel op via Fluent en
PostgreSQL. Recept-ingrediënten bevatten alleen de recept- en ingrediëntsleutel.
Aanbiedingen verwijzen naar precies één ingrediënt en één supermarkt en bewaren
bedragen als centen en tijden in UTC. Recepten verwijzen naar één beheerde bron.

Ieder type krijgt een eigen overzicht en formulier. De formulieren voor aanbiedingen
en recepten tonen daarnaast een klein aanmaakformulier voor ontbrekende relaties.
Dit gebruikt normale server-side POST-routes en werkt dus zonder JavaScript.

Adminsessies zijn uitsluitend onder `/admin` actief. Mutaties vereisen een geldige
sessie, de rol `admin` of `editor`, een CSRF-token en server-side validatie. We leggen
aanmaken, wijzigen en verwijderen vast in een auditlog en verwijderen records zacht.
Bronregistraties in deze slice zijn handmatige receptbronnen; ze starten geen import
en leggen geen toestemming voor automatisch ophalen vast.

## Gevolgen

- De migratie is additief en de `down`-stap verwijdert tabellen alleen bij een
  expliciete lokale rollback.
- Inline aanmaken voorkomt dubbel invoerwerk, maar de beheerder moet daarna het
  oorspronkelijke formulier afronden.
- Publicatie en automatische imports blijven buiten deze slice. De bestaande
  publieke democatalogus blijft daardoor ongewijzigd totdat databasepublicatie als
  aparte verticale slice wordt aangesloten.
