# ADR 0008: gepubliceerde beheercatalogus als publieke bron

- Status: geaccepteerd
- Datum: 2026-08-01

## Context

De publieke zoekpagina en zoek-API lezen nog uit een vaste democatalogus. Het
beheerportaal schrijft ingrediënten, supermarkten, recepten en aanbiedingen naar
PostgreSQL, maar kent nog geen expliciet onderscheid tussen een concept en
publieke inhoud. Rechtstreeks alle beheerdata tonen zou onvolledige invoer meteen
zichtbaar maken.

## Besluit

In normale omgevingen bouwen de publieke pagina- en API-routes per request één
begrensde `Catalog` uit PostgreSQL. Alleen niet-verwijderde, expliciet
gepubliceerde recepten met een actieve receptbron worden opgenomen. Aanbiedingen tellen alleen mee als ze
expliciet gepubliceerd zijn en het huidige UTC-tijdstip binnen hun geldigheid valt.
Ingrediënten, gerechtswensen en supermarktketens blijven beschikbaar als
zoekkeuzes, ook als er nog geen gepubliceerd recept of actuele aanbieding is.

Een beheerder kiest publicatie bewust in het recept- of aanbiedingsformulier.
Bestaande en nieuwe records zijn standaard niet gepubliceerd. De testomgeving kan
een vaste catalogus gebruiken voor snelle HTTP-tests; de PostgreSQL-integratietest
controleert de echte adapter.

De adapter haalt relaties vooraf op en begrenst elk publiek resultaat. UUID's uit
de database zijn de stabiele technische identifiers in zoekrequests. Omdat het
huidige beheermodel geen hoeveelheden bewaart, krijgt ieder receptingrediënt voor
de bestaande 3/2/1/0-formule gewicht 1.

## Gevolgen

- Handmatig opgeslagen concepten lekken niet naar de publieke site.
- Wijzigingen in beheer zijn na publicatie bij het volgende request zichtbaar;
  caching en expliciete cache-invalidering zijn nog niet nodig.
- Een lege beheerdatabase geeft een bruikbare lege catalogus en geen demodata.
- De limieten beschermen de publieke routes, maar vragen later om een expliciete
  schaalstrategie als de catalogus ze nadert.
- De rankingformule en sorteervolgorde wijzigen niet.
