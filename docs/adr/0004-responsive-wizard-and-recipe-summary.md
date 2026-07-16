# ADR 0004: Compacte wizardbediening en receptsamenvatting

## Status

Geaccepteerd

## Context

De eerste verticale slice toont op kleine schermen meerdere wizardacties naast
elkaar zonder vaste uitlijning. Het algemene knopontwerp overschrijft bovendien
het HTML-attribuut `hidden`, waardoor “Volgende” ook op de laatste stap zichtbaar
kan blijven. Receptkaarten herhalen alle ingrediënten terwijl de gebruiker in het
resultatenoverzicht vooral snel wil vergelijken.

## Besluit

- “Toon recepten” blijft op iedere wizardstap beschikbaar en gebruikt op mobiel
  de volle breedte. Zo kan de gebruiker ook zonder filters zoeken.
- “Vorige” en “Volgende” delen op mobiel één rij; de resetactie staat op een
  volgende rij. Verborgen acties krijgen altijd `display: none`.
- Korte staptitels blijven op normale ondersteunde viewports op één regel.
- Receptkaarten tonen het matchpercentage over de afbeelding en vatten
  ingrediënten samen met totalen. De volledige ingrediëntenlijst verdwijnt uit
  het overzicht.
- Informatielinks staan alleen in de voettekst. Het beeldmerk en de merknaam
  blijven de enige headernavigatie naar de startpagina.

De rankingformule, filters en sorteervolgorde veranderen niet.

## Gevolgen

Het resultatenoverzicht is compacter en de primaire acties hebben op mobiel een
voorspelbare plek. Een latere receptdetailweergave kan de volledige
ingrediëntenstatus tonen als daar behoefte aan is. De tekstsamenvatting blijft
afgeleid van dezelfde zoekresultaten en introduceert geen nieuwe businessregel.
