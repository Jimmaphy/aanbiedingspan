# ADR 0009: één beheerd publiek contactadres

- Status: geaccepteerd
- Datum: 2026-08-01

## Context

De pagina “Over Aanbiedingspan” toont bewust een placeholder zolang een openbaar
contactadres niet bevestigd is. Voor de eerste versie moet een beheerder dit adres
kunnen instellen zonder code of configuratie te wijzigen.

## Besluit

We bewaren maximaal één publiek contactadres in PostgreSQL, onder een vaste
technische sleutel. Alleen een ingelogde `admin` of `editor` kan het adres via een
CSRF-beveiligd formulier wijzigen. De server valideert de invoer als e-mailadres en
legt aanmaken en wijzigen vast in de bestaande auditlog.

De publieke informatiepagina leest het adres via een kleine repository. Ontbreekt
de instelling, dan blijft de bestaande placeholder zichtbaar. Er wordt geen
contactformulier toegevoegd en Aanbiedingspan verzamelt via deze functie dus geen
berichten of persoonsgegevens.

## Gevolgen

- De beheerinstelling is direct zichtbaar op de informatiepagina.
- De migratie is additief en maakt geen standaardrecord aan.
- Een tweede contactrecord kan niet via de applicatie worden aangemaakt; de vaste
  UUID maakt de singleton expliciet en deterministisch.
