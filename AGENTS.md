# Instructies voor Codex en andere LLM's

Deze instructies gelden voor de volledige repository. Lees ook
`docs/IMPLEMENTATIEPLAN.md` en `docs/UITROLPLAN.md` voordat je architectuur of
productiegedrag wijzigt.

## Opdracht en prioriteiten

Aanbiedingspan helpt voedselverspilling verminderen. Houd bij ontwerpkeuzes deze
volgorde aan:

1. correctheid van dieet-, allergie- en uitsluitfilters;
2. veiligheid, privacy en toegankelijke bediening;
3. meer gewicht voor ingrediënten die de gebruiker al in huis heeft;
4. uitlegbare en deterministische resultaten;
5. eenvoudige onderhoudbare implementatie vóór extra infrastructuur.

Doe nooit medische claims over geschiktheid van een recept. Een gerechtswens is
metadata en geen garantie dat kruisbesmetting is uitgesloten.

## Verplichte werkwijze

1. Lees relevante code, tests en documentatie vóór een wijziging.
2. Controleer `git status`; behoud niet-gerelateerde wijzigingen van de gebruiker.
3. Maak bij niet-triviale ontwerpkeuzes eerst een kort ADR in `docs/adr/`.
4. Werk in een kleine verticale slice met tests en toegankelijke fout-/lege states.
5. Voer formattering, relevante tests en daarna zo mogelijk de volledige suite uit.
6. Werk documentatie en voorbeeldconfiguratie bij als gedrag/configuratie wijzigt.
7. Rapporteer welke checks zijn uitgevoerd en welke niet konden worden uitgevoerd.

Raadpleeg actuele officiële documentatie wanneer Swift-, Vapor- of dependency-
gedrag versiegevoelig is. Verzin geen API’s. Voeg geen dependency of front-end
framework toe zonder concrete noodzaak en een vastgelegde afweging.

## Technische grenzen

- Backend: Swift en Vapor; databasebenadering via Fluent/PostgreSQL.
- Front-end: semantische server-rendered HTML, CSS en native JavaScript.
- Schrijf code en technische namen in het Engels: identifiers, typen, bestanden,
  databaseschema’s, API-velden, routes, comments, logs en tests. Alleen de merknaam
  `Aanbiedingspan` is hiervan uitgezonderd.
- Schrijf alle zichtbare publieke en admininterfacecopy in correct Nederlands,
  inclusief validatiemeldingen en toegankelijkheidslabels. Houd UI-copy buiten
  domeinservices en controllers.
- Schrijf UI-copy waar mogelijk op B2-niveau of eenvoudiger. Gebruik korte, actieve
  zinnen, bekende woorden en concrete acties. Leg noodzakelijke vaktermen meteen uit.
  Houd de toon warm en thematisch, maar laat duidelijkheid altijd voorgaan op
  woordgrappen, metaforen of sfeer.
- Houd businessregels uit controllers en templates; plaats ze in pure services.
- Valideer en autoriseer altijd server-side.
- Gebruik migrations voor alle schemawijzigingen; wijzig productiedata niet ad hoc.
- Houd routes dun, DTO’s expliciet en fouten veilig voor publieke uitvoer.
- Gebruik configuratie/environment voor secrets en omgevingsverschillen.
- Voeg geen consumentenaccounts, locatievelden, postcodezoeking, filialen of
  browsergeolocatie toe.
- Wizardkeuzes mogen pas na expliciete opt-in in `localStorage` staan en tijdelijk
  in zoekrequests worden verwerkt, maar worden niet server-side opgeslagen, gelogd
  of aan een profiel gekoppeld. Weigering wordt niet bewaard.
- Recepten en aanbiedingen moeten handmatig beheerbaar blijven. Bouw, voeg toe of
  activeer geen automatische importadapter zonder aantoonbare expliciete toestemming
  van de betreffende bron voor het juiste contenttype en gebruik. Controleer
  reikwijdte, vervaldatum en intrekking; toestemming voor recepten impliceert geen
  toestemming voor aanbiedingen en andersom. Scrape nooit zonder toestemming.
- Sla geldbedragen op in centen, timestamps in UTC en render lokale tijden bewust.
- Voorkom N+1-queries en onbegrensde resultaten; meet vóór optimalisatie.

## Open productaantekeningen

- Ontwerp vóór uitbreiding van de ingrediëntencatalogus een schaalbare zoek- en
  selectiemethode. Toon een grote catalogus, bijvoorbeeld circa 50 ingrediënten,
  niet als twee volledige lijsten waarin de gebruiker handmatig moet zoeken.

## Rankingregels

De specificatie in `docs/IMPLEMENTATIEPLAN.md` is leidend. Wijzig het gewicht of de
sorteervolgorde niet stilzwijgend. Elke wijziging vereist:

- tabelgestuurde unit-tests met oude en nieuwe randgevallen;
- uitleg waarom voedselverspilling nog steeds prioriteit krijgt;
- een ADR en aanpassing van zichtbare score-uitleg;
- controle dat de score deterministisch en stabiel gepagineerd blijft.

Uitgesloten ingrediënten en niet-voldane gerechtswensen zijn filters, geen zachte
negatieve score. Alleen actuele aanbiedingen bij de geselecteerde supermarkt(en)
mogen meetellen. De ingrediëntscore is exact: 3 voor in huis én in aanbieding, 2
voor in huis, 1 voor in aanbieding en 0 anders.

De pagina “Over Aanbiedingspan” legt deze punten, het matchpercentage en de harde
dieet-/uitsluitfilters in eenvoudige Nederlandse taal uit en blijft gelijk aan de
geïmplementeerde formule.

## Security en privacy

- Plaats nooit secrets, tokens, echte persoonsgegevens of productiegegevens in
  broncode, prompts, fixtures, logs of commits.
- Muterende adminroutes vereisen authenticatie, rolcontrole, CSRF en validatie.
- Voeg tests toe voor zowel toegestane als geweigerde acties.
- Vermijd SSRF: haal een door gebruikers ingevoerde recept-URL niet server-side op.
- Behandel uploads, imports en CSV-formules als onbetrouwbare invoer.
- Een importtaak controleert vóór iedere run de vastgelegde bronautorisatie en stopt
  veilig wanneer die ontbreekt, verlopen is of werd ingetrokken.
- Vraag of verwerk geen locatiegegevens van publieke bezoekers.
- Publieke bezoekers krijgen geen sessiecookie. Sessies zijn alleen voor admins.
- Log geen wizardkeuzes en gebruik geen bezoekersanalytics die een profiel opbouwen.
- Schrijf vóór opt-in niets naar `localStorage`; intrekken, verlopen en “Wizard
  opnieuw starten” verwijderen keuzes en toestemmingsregistratie.
- Gebruik veilige defaults voor cookies, headers en externe links.

## Test- en kwaliteitsminimum

Voeg voor een gedragswijziging minstens één test toe die vóór de wijziging faalt.
Test ranking als pure logica en databasegedrag ook tegen PostgreSQL. Voor UI-
wijzigingen controleer je minimaal:

- smal mobiel viewport en desktop;
- toetsenbord en zichtbare focus;
- JavaScript aan en waar relevant uit;
- “Wizard opnieuw starten” wist alle lokale wizardkeuzes;
- opt-in is vooraf uitgevinkt en weigeren beperkt de zoekfunctie niet;
- wizardkeuzes blijven na verwerking niet achter in database, sessie of logs;
- loading-, fout- en lege status;
- tekstzoom en statuscommunicatie zonder alleen kleur;
- menselijke controle op correct Nederlands, B2 of eenvoudiger en begrijpelijke
  thematische tekst.

Gebruik geen snapshots als enige bewijs voor businesslogica.

## Git en commits

Maak uitsluitend een lokale Git-commit wanneer de gebruiker daar in een afzonderlijke
prompt expliciet om vraagt. Een verzoek om code te wijzigen impliceert geen verzoek
om te committen. Voordat je commit:

1. controleer diff en status op gebruikerswerk;
2. stage alleen bestanden die bij de opdracht horen;
3. voer relevante tests uit;
4. gebruik een korte, gebiedende commitboodschap, bij voorkeur Conventional Commits
   zoals `feat(search): add pantry-weighted ranking`;
5. meld de commit-hash en teststatus.

Initialiseer geen repository, herschrijf geen geschiedenis, force-push niet en
wijzig geen remote zonder expliciete toestemming. Voeg nooit gegenereerde secrets,
buildoutput of lokale databases toe.

## Definition of Done

Een taak is pas gereed als het gevraagde gedrag is geïmplementeerd, relevante tests
slagen, WCAG 2.2 AA en begrijpelijke B2-tekst zijn gecontroleerd, beveiliging is
meegewogen, migraties achterwaarts veilig zijn en de relevante documentatie klopt.
Noem resterende risico’s of handmatige stappen expliciet in de oplevering.
