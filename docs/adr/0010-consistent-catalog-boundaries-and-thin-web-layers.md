# ADR 0010: consistente catalogusgrenzen en dunne web-lagen

- Status: geaccepteerd
- Datum: 2026-08-01

## Context

De eerste beheerde catalogus is bewust begrensd. De losse limieten konden echter
een recept of aanbieding doorlaten met een ingrediënt dat niet meer in de publieke
keuzelijst stond. Bij gelijke sorteervelden was bovendien niet vastgelegd welk
record rond een limiet werd gekozen. De HTTP- en beheerlagen groeiden tegelijk:
lijst-API's laadden de hele catalogus, domeinfouten werden per controller vertaald
en veel Leaf-pagina's herhaalden dezelfde documentstructuur.

## Besluit

De beheerde repository bouwt één intern consistente momentopname. Een publiek recept
wordt alleen opgenomen als al zijn ingrediënten en gerechtswensen in de begrensde
keuzecatalogus staan. Aanbiedingsingrediënten buiten die catalogus worden niet
opgenomen. Iedere begrensde databasequery krijgt een stabiele UUID-sorteersleutel.

De repository biedt daarnaast gerichte leesmethoden voor ingrediënten en
supermarkten. Lijst-API's gebruiken die methoden en laden geen recepten of
aanbiedingen. De zoekservice vertaalt conflicterende ingrediënten via één gedeelde
webfout en berekent de actuele aanbiedingsingrediënten één keer per zoekopdracht.

Gedeelde publieke en ingelogde beheer-HTML verhuist naar Leaf-layouts. Nieuw
websitebeheer krijgt een eigen controller; verdere beheergebieden kunnen volgens
hetzelfde patroon worden afgesplitst zonder routes of businessregels te wijzigen.

## Gevolgen

- Een verborgen keuze kan het matchpercentage niet beïnvloeden.
- Dezelfde database-inhoud levert ook rond limieten dezelfde publieke momentopname.
- Kleine lijst-API's doen minder databasewerk.
- Controllers en templates krijgen kleinere, duidelijkere verantwoordelijkheden.
- Wanneer een cataloguslimiet wordt bereikt kan geldige inhoud bewust buiten de
  publieke momentopname vallen; monitoring en een latere zoekstrategie blijven
  nodig voordat de catalogus structureel tegen die grenzen aanloopt.
