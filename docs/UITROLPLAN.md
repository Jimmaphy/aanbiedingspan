# Uitrolplan Aanbiedingspan

## 1. Omgevingen

Gebruik gescheiden configuratie, databases, secrets en opslag voor:

- **local**: Docker Compose, seeddata en een lokale mail-/opslagvervanger;
- **test/CI**: tijdelijke PostgreSQL-database per run;
- **staging**: productieachtige infrastructuur met synthetische of geschoonde data;
- **production**: minimaal twee app-instances achter TLS/load balancer indien het
  gekozen platform dat toelaat.

Het buildartifact is een immutable containerimage op basis van een vastgelegde
Swift-toolchain. Promoveer hetzelfde geteste image van staging naar productie.

## 2. Benodigde productieonderdelen

- Vapor-webproces zonder lokale state
- PostgreSQL met versleuteling, point-in-time recovery en automatische back-ups
- Objectopslag/CDN voor beheerde afbeeldingen
- TLS, DNS, reverse proxy/load balancer en veilige headers
- Secrets manager voor database, sessies en broncredentials
- Scheduler/worker voor geautoriseerde recept- en aanbodimports en onderhoudstaken
- Centrale gestructureerde logs, metrics, traces en foutmeldingen

Leg providerkeuze en infrastructure-as-code in een ADR vast. Productiesecrets staan
nooit in de repository of het containerimage.

## 3. CI/CD-pijplijn

Bij iedere pull request:

1. controleer formattering en lint;
2. controleer de Engelse codeconventie en Nederlandse UI-copy; laat gewijzigde copy
   menselijk beoordelen op B2 of eenvoudiger en thematische helderheid;
3. resolveer dependencies uitsluitend vanaf de lockfile;
4. voer unit-, integratie- en HTTP-tests uit;
5. bouw in releaseconfiguratie;
6. voer dependency- en container-scans uit;
7. draai waar mogelijk een korte toegankelijkheids-/browser-smoketest.

Bij merge naar de hoofdbranch:

1. bouw en signeer/tag het image met commit-SHA;
2. genereer herleidbare buildmetadata/SBOM;
3. deploy automatisch naar staging;
4. voer migraties, seeds die idempotent zijn en smoketests uit;
5. wacht op expliciete productiegoedkeuring;
6. promoveer exact hetzelfde image;
7. verifieer healthchecks en kernflow.

## 4. Databasewijzigingen

Gebruik het expand/contract-patroon:

1. voeg compatibele tabellen/kolommen/indexen toe;
2. deploy code die oud en nieuw schema verdraagt;
3. vul data in een begrensde achtergrondtaak;
4. schakel lezen naar het nieuwe schema;
5. verwijder oude velden pas in een latere release.

Voer vóór productie automatisch een back-up uit en test migraties vooraf op een
recente, geschoonde databasekopie. Vermijd lang blokkerende indexoperaties. Een
rollback van code mag nooit afhankelijk zijn van een destructieve down-migratie.

## 5. Eerste productierelease

### Vooraf

- MVP-acceptatiecriteria en open releaseblokkers zijn afgetekend.
- DNS, TLS, cookies, CSP, robots/sitemap en externe links zijn gecontroleerd.
- Privacy-informatie, bronvermelding, gebruiksrechten en bewaartermijnen voor de
  strikt noodzakelijke administratorgegevens zijn gereed.
- Naam en contactgegevens van de verantwoordelijke, publieke contactmailboxen en
  bewaartermijnen voor lokale keuzes en ontvangen e-mail zijn bevestigd.
- Browserinspectie bevestigt dat vóór opt-in niets persistent wordt opgeslagen en
  dat intrekken, verlopen en reset alle lokale wizarddata verwijderen.
- WCAG 2.2 AA-controles zijn geslaagd en publieke plus adminteksten zijn menselijk
  beoordeeld op correct Nederlands, B2 of eenvoudiger en begrijpelijkheid.
- Minimaal één hersteltest van database en afbeeldingen is geslaagd.
- Adminaccounts gebruiken unieke wachtwoorden; initiële credentials zijn veilig
  overgedragen en moeten bij eerste gebruik worden gewijzigd.
- Voor iedere automatische recept- en aanbodbron zijn expliciete toestemming,
  reikwijdte, geldigheidsduur en intrekkingsstatus gecontroleerd; aanbodverval en
  tijdzone Europe/Amsterdam zijn met actuele fixtures getest.
- Dashboards, alerts en eigenaar/escalatiepad zijn actief.

### Releasevolgorde

1. Zet een onderhoudsvenster alleen indien een compatibele migratie niet mogelijk is.
2. Maak en verifieer back-up/herstelpunt.
3. Voer expand-migraties uit via een eenmalige releasejob.
4. Deploy eerst een canary of klein deel van het verkeer.
5. Test `/health/ready`, homepage, wizard, zoeken, externe link en adminlogin.
6. Verhoog verkeer stapsgewijs terwijl foutpercentage en latency worden bewaakt.
7. Start uitsluitend geautoriseerde recept- en aanbodimports nadat de applicatie
   stabiel is en de toestemming opnieuw is gecontroleerd.
8. Noteer image-SHA, migratieversie, uitvoerder en tijdstip in het releaselog.

## 6. Observability en alerts

Meet minimaal:

- requestaantal, p50/p95/p99-latency en 4xx/5xx-percentage per routegroep;
- databasepool, trage queries, locks, opslag en replicatie/back-upstatus;
- actuele versus verlopen aanbiedingen, leeftijd van laatste geslaagde import en
  naderende vervaldatums van bronautorisaties;
- loginmislukkingen, rate-limitactivaties en onverwachte adminautorisatiefouten;
- workerfouten, wachtrijlengte en afbeeldingsfouten.

Log geen IP-adressen, user-agentstrings, ingrediëntkeuzes, gerechtswensen,
supermarktkeuzes of locatiegegevens; controleer dit ook voor load balancer,
hostingplatform en CDN. Operationele alerts moeten een eigenaar, ernst, runbooklink
en duidelijke herstelconditie hebben. Stel concrete drempels na een stagingbaseline
vast om ruis te voorkomen.

## 7. Rollback en incidenten

Rollback bij verhoogde 5xx, corrupte zoekresultaten, authenticatieproblemen of
onjuist aanbod:

1. stop verdere uitrol en pauzeer imports;
2. zet bij een geïsoleerde functie de featureflag uit;
3. stuur verkeer terug naar het vorige compatibele image;
4. laat additieve databasewijzigingen staan;
5. herstel data uit auditlog/backup alleen na impactanalyse;
6. verifieer kernflow, leg tijdlijn vast en communiceer status;
7. maak na herstel een postmortem met concrete vervolgacties.

Bij een foutieve aanbieding kan deze direct worden gedepubliceerd zonder volledige
app-rollback. Bij gelekte credentials: intrekken/roteren, sessies ongeldig maken,
logs veiligstellen en het incidentproces volgen.

## 8. Beheer na livegang

- Dagelijks: recept- en aanbodimportstatus, verlopen aanbiedingen, bronautorisaties
  en kritieke alerts controleren.
- Wekelijks: kapotte externe receptlinks, reviewqueue en fouttrends behandelen.
- Maandelijks: dependencies, adminaccounts, opslag, performance en kosten reviewen.
- Per kwartaal: restore-oefening, rechtenreview, incidentrunbooks en een
  toegankelijkheids- en begrijpelijkheidssteekproef.
- Voor elke release: changelog, migratierisico, rollbackstap en supportimpact noteren.
