# Implementatieplan Aanbiedingspan

## 1. Doel en afbakening

Aanbiedingspan is een mobiel bruikbare singlepage-zoekmachine voor recepten. De
eerste sessie begint met een wizard. Daarna blijven dezelfde keuzes als filters
beschikbaar en wordt de resultatenlijst zonder volledige paginaverversing
bijgewerkt.

Het primaire doel van de sortering is voedselverspilling tegengaan: een ingrediënt
dat de gebruiker al in huis heeft telt zwaarder dan een ingrediënt dat alleen in de
aanbieding is.

### Bevestigde productkeuzes

- Een recept verwijst naar een externe bron; Aanbiedingspan toont metadata en geen
  volledige, auteursrechtelijk beschermde recepttekst.
- De gebruiker kiest uit een algemene lijst met supermarktketens. Aanbiedingspan
  vraagt, verwerkt of bewaart geen locatie, postcode, adres of browsergeolocatie.
- Er komen geen consumentenaccounts. Alleen na een expliciete, vooraf uitgevinkte
  opt-in worden wizardkeuzes blijvend in de browser opgeslagen via `localStorage`.
  Zonder opt-in blijven ze alleen voor het actuele bezoek beschikbaar. Een duidelijke
  actie “Wizard opnieuw starten” wist deze gegevens en begint bij stap één.
- Wizardkeuzes mogen voor een zoekopdracht naar de server worden gestuurd en worden
  daar alleen tijdelijk verwerkt. Ze worden niet server-side opgeslagen, gelogd of
  aan een bezoekersprofiel gekoppeld.
- Alle zichtbare teksten krijgen correct Nederlands, onafhankelijk van de spelling
  in invoer, tickets of prompts; voorbeelden zijn “vegetarisch” en “glutenvrij”.
- Toegankelijkheid is essentieel. Schrijf zichtbare teksten waar mogelijk op
  taalniveau B2 of eenvoudiger. De toon mag warm en thematisch zijn, maar een
  woordgrap, metafoor of vakterm mag begrip en bediening nooit moeilijker maken.
- Alle broncode en technische namen zijn Engels. Dit omvat identifiers, typen,
  bestandsnamen, databaseschema’s, API-velden, routes, codecomments, logs en
  testnamen. Alleen de merknaam `Aanbiedingspan` blijft Nederlands. Alle zichtbare
  gebruikersinterface, inclusief het adminportaal en validatiemeldingen, is Nederlands.
- Recepten en aanbiedingen zijn beide volledig handmatig te beheren. Een automatische
  importadapter voor een externe bron wordt uitsluitend gebouwd, toegevoegd en
  ingeschakeld nadat die bron daarvoor aantoonbaar expliciete toestemming heeft
  gegeven. Zonder toestemming wordt niet gescrapet of automatisch geïmporteerd.

## 2. Functionele ervaring

### 2.1 Wizard

De startpagina toont een toegankelijke wizard met een voortgangsindicator en drie
stappen:

1. **Gerechtswensen**: kies nul of meer wensen, zoals veganistisch,
   vegetarisch, glutenvrij, lactosevrij of halal. Een admin beheert deze lijst.
2. **Ingrediënten**: zoek en selecteer ingrediënten in twee duidelijk gescheiden
   groepen: “in huis” en “uitsluiten”. Eenzelfde ingrediënt kan nooit in beide
   groepen staan. Uitsluitingen kunnen allergieën, dieetbeperkingen of smaak zijn.
3. **Supermarkten**: kies één of meer supermarktketens uit een beheerde algemene
   lijst. Er is geen locatie-, afstands- of filiaalselectie.

Elke stap ondersteunt teruggaan, overslaan waar dat zinvol is, toetsenbordbediening
en een heldere foutmelding. Na “Toon recepten” verandert de pagina naar de
resultaatweergave.

Onderaan de laatste stap staat een niet vooraf aangevinkte bewaaroptie:

> **Onthoud mijn keuzes voor een volgend bezoek**
> Aanbiedingspan bewaart je keuzes dan alleen in deze browser. Geen account, geen
> locatie en geen reclameprofiel.

Naast de optie staat een informatieknop. De korte uitleg verschijnt bij hover,
toetsenbordfocus en klik, en bevat de link “Lees hoe dit werkt”. Die link opent
`/privacy#keuzes-bewaren` in een nieuw tabblad. De checkbox en informatielink hebben
losse, begrijpelijke toegankelijke namen; hover is nooit de enige informatiedrager.

Tekst in de korte uitleg:

> Met dit vinkje bewaren we je wizardkeuzes 90 dagen in deze browser. Zonder vinkje
> kun je gewoon zoeken, maar begin je een volgend bezoek opnieuw. Je kunt dit altijd
> wissen. [Lees hoe dit werkt (opent in een nieuw tabblad).]

Zonder opt-in blijft de wizard volledig werken, maar begint een nieuw browserbezoek
weer bij stap één. Met opt-in bewaart `localStorage` de keuzes, het moment van
toestemming en een schemaversie. De applicatie verwijdert verouderde of onleesbare
data automatisch. De maximale bewaartermijn in de eerste versie is 90 dagen.

### 2.2 Resultaten en filters

- Boven of naast de resultaten staat een inklapbaar filterpaneel met alle
  wizardkeuzes. Op mobiel opent dit als dialoog/bottom sheet.
- Na opt-in worden filterwijzigingen in `localStorage` bewaard. Met of zonder opt-in
  mogen ze in een requestbody naar de zoek-API worden gestuurd. Ze komen niet in
  URL-queryparameters, cookies of serversessies terecht en worden niet server-side
  opgeslagen.
- De pagina biedt altijd “Wizard opnieuw starten”. Deze wist uitsluitend de publieke
  voorkeuren uit `localStorage`, reset de filters en opent stap één.
- Zonder JavaScript blijven zoeken en filteren werken via een normale POST-submit;
  de server verwerkt de keuzes voor die response zonder ze te bewaren.
- Elke receptkaart toont afbeelding, titel, korte beschrijving, tijdsduur,
  gerechtswensen, matchpercentage en een korte verklaring van de score.
- Ingrediënten krijgen een status: **in huis**, **in aanbieding**, **nodig** of
  **uitgesloten**. Een recept met een uitgesloten ingrediënt verschijnt standaard
  niet.
- De primaire actie “Bekijk recept” opent de externe bron. Externe links krijgen
  passende `rel`-attributen en de bron/domeinnaam is zichtbaar.
- Lege resultaten geven bruikbare suggesties om filters te versoepelen.

### 2.3 Adminportaal

Het portaal is bereikbaar onder `/admin`, vereist authenticatie en heeft minimaal
de rollen `admin` en `editor`.

Beheer omvat:

- recepten, afbeeldingen en externe bronlinks;
- canonieke ingrediënten en synoniemen;
- recept-ingrediënten met hoeveelheid en eenheid;
- gerechtswensen en koppelingen aan recepten;
- supermarktketens;
- aanbiedingen, geldigheidsperiode en gekoppelde ingrediënten;
- handmatige invoer voor zowel recepten als aanbiedingen;
- geautoriseerde recept- en aanbodimports, validatiefouten en publicatiestatus;
- bronregistraties met toestemmingsstatus, bewijs, reikwijdte en geldigheidsduur;
- beheerders en rollen (alleen voor de rol `admin`);
- auditlog van aanmaken, wijzigen, publiceren en verwijderen.

Verwijderen is waar mogelijk soft-delete. Publicatie is gescheiden van opslaan,
zodat onvolledige imports niet publiek zichtbaar worden.

### 2.4 Over Aanbiedingspan

`GET /about` is een korte, server-renderde informatiepagina. Gebruik
de volgende concepttekst, waarbij het contactadres vóór publicatie wordt bevestigd:

> # Koken met wat er al is
>
> Aanbiedingspan helpt je een recept te vinden met ingrediënten die je al in huis
> hebt. Wat nog ontbreekt, zoeken we zoveel mogelijk bij de aanbiedingen van de
> supermarkten die jij kiest. Zo wordt kiezen makkelijker en belandt er hopelijk
> minder eten in de afvalbak.
>
> ## Onze missie
>
> Eerst opmaken, dan slim aanvullen. Aanbiedingspan geeft ingrediënten uit je eigen
> voorraad daarom meer gewicht dan aanbiedingen. Je keuzes blijven van jou: er is
> geen consumentenaccount en we vragen niet waar je woont.
>
> ## Zo komt je match tot stand
>
> We bekijken ieder ingrediënt van een recept en geven het punten:
>
> - **3 punten** als je het in huis hebt én het in de aanbieding is;
> - **2 punten** als je het alleen in huis hebt;
> - **1 punt** als het alleen in de aanbieding is bij een supermarkt die je hebt
>   gekozen;
> - **0 punten** als geen van deze situaties geldt.
>
> Ingrediënten die je al hebt wegen dus zwaarder. Dat helpt om eerst op te maken wat
> er in je keuken ligt. We tellen de punten op en vergelijken ze met de hoogst
> mogelijke score. Zo ontstaat het matchpercentage.
>
> Een simpel voorbeeld: een recept met vier even belangrijke ingrediënten kan
> maximaal 12 punten krijgen. Scoort het recept 6 punten, dan is de match 50%.
> Gerechtswensen en ingrediënten die je uitsluit controleren we eerst. Een recept
> dat daar niet aan voldoet, komt niet in de resultaten.
>
> ## Even overleggen?
>
> Heb je een vraag, een goed recept of zie je iets dat niet klopt? Mail ons via
> [contact@aanbiedingspan.nl](mailto:contact@aanbiedingspan.nl).

Gebruik een `mailto:`-link en geen contactformulier, zodat de site zelf geen
contactgegevens verzamelt. Vervang `contact@aanbiedingspan.nl` alleen door een
bevestigd, bewaakt adres en publiceer de pagina niet met een fictief contactadres.

### 2.5 Privacyverklaring

`GET /privacy` is een korte, server-renderde pagina met een inhoudsopgave en een
stabiel anker `#keuzes-bewaren`. Concepttekst:

> # Jouw keuzes blijven van jou
>
> Aanbiedingspan is gemaakt met privacy als uitgangspunt. Je hebt geen account nodig
> en we vragen niet om je naam, adres, postcode of locatie.
>
> ## Zoeken zonder profiel
>
> Om recepten te vinden sturen we je gekozen gerechtswensen, ingrediënten en
> supermarkten naar onze server. We gebruiken die alleen om de resultaten voor dat
> moment te berekenen. We slaan deze keuzes niet op, koppelen ze niet aan een profiel
> en gebruiken ze niet voor advertenties of bezoekersstatistieken.
>
> ## Je keuzes bewaren
>
> Wil je de volgende keer verdergaan waar je gebleven was? Vink dan in de wizard
> “Onthoud mijn keuzes voor een volgend bezoek” aan. We bewaren de keuzes dan met
> `localStorage` in jouw browser. Dat is opslag op je eigen apparaat. Bij een
> zoekopdracht sturen we je actuele keuzes naar de server zoals hierboven beschreven;
> de lokale opslag wordt niet los daarvan uitgelezen. Je toestemming en keuzes
> bewaren we maximaal 90 dagen.
>
> Kies je dit niet, dan werkt Aanbiedingspan gewoon. Bij je volgende bezoek vul je de
> wizard opnieuw in. We slaan ook je weigering niet op. Daarom vragen we het bij een
> volgend bezoek opnieuw.
>
> Je kunt je toestemming altijd intrekken met “Wizard opnieuw starten” of “Vergeet
> mijn keuzes”. Dan verwijderen we de opgeslagen keuzes en de melding dat je
> toestemming gaf direct uit deze browser.
>
> ## Cookies
>
> Voor bezoekers gebruiken we geen tracking- of advertentiecookies. Alleen
> administrators krijgen na het inloggen een beveiligde cookie. Die is nodig om
> ingelogd te blijven. De optionele bewaarfunctie voor bezoekers gebruikt
> `localStorage`, geen cookie.
>
> ## Techniek zonder nieuwsgierigheid
>
> De computer waarop Aanbiedingspan draait ontvangt een verzoek om de website te
> kunnen tonen. We richten onze technische logboeken zo in dat wizardkeuzes,
> volledige IP-adressen en browserprofielen niet worden bewaard. We gebruiken geen
> verborgen trackers of advertentiescripts van anderen.
>
> ## Links naar recepten
>
> Recepten openen op de website van de maker. Vanaf dat moment gelden de privacy- en
> cookievoorwaarden van die website. We laten vooraf duidelijk zien naar welke bron
> je gaat.
>
> ## Als je ons mailt
>
> Als je zelf contact opneemt, ontvangen we je e-mailadres en wat je in je bericht
> zet. We gebruiken dat alleen om je vraag te beantwoorden en bewaren het niet langer
> dan nodig. **[Concrete bewaartermijn en mailprovider vóór publicatie invullen.]**
>
> ## Vragen over privacy
>
> Mail je vraag naar
> [privacy@aanbiedingspan.nl](mailto:privacy@aanbiedingspan.nl). We reageren zo snel
> mogelijk. **[Naam en contactgegevens van de verantwoordelijke vóór publicatie
> invullen.]**
>
> Laatst bijgewerkt: **[publicatiedatum invullen]**.

Laat de definitieve tekst vóór productie juridisch beoordelen en vul eigenaar,
contactadres, e-mailbewaartermijn en datum in. De lichte toon mag nooit verhullen wat er
wordt opgeslagen, waarom, hoe lang en hoe de gebruiker dit verwijdert.

Geef de HTML-heading “Je keuzes bewaren” het expliciete id `keuzes-bewaren`. Open de
informatielink met `target="_blank"` en `rel="noopener noreferrer"` en vermeld in de
zichtbare of toegankelijke linktekst dat een nieuw tabblad opent.

### 2.6 Juridische ontwerpnotitie

De gekozen opt-in is bewust voorzichtiger dan de uitzondering die voor strikt
noodzakelijke functionele opslag kan gelden. Voorkeuren voor een volgend bezoek zijn
niet nodig om de actuele zoekopdracht uit te voeren. Daarom schrijft de site pas na
een actieve keuze naar `localStorage`. De gebruiker kan weigeren zonder functieverlies
en kan toestemming even eenvoudig weer intrekken.

Controleer de implementatie en definitieve tekst vóór livegang opnieuw aan de hand
van de actuele uitleg van de
[Rijksoverheid over cookies](https://www.rijksoverheid.nl/vraag-en-antwoord/telecommunicatie/mag-een-website-ongevraagd-cookies-plaatsen),
de [Autoriteit Persoonsgegevens over cookiebanners](https://autoriteitpersoonsgegevens.nl/actueel/foute-cookiebanners-aangepast-na-ingrijpen-ap)
en artikel 5, lid 3 van de
[Europese ePrivacyrichtlijn](https://eur-lex.europa.eu/legal-content/en/TXT/?uri=CELEX%3A32002L0058).

## 3. Technische architectuur

### 3.1 Stack

- Swift (actuele stabiele toolchain bij start vastleggen in `.swift-version`)
- Vapor voor HTTP, middleware, validatie en server-side services
- Leaf voor server-rendered HTML; dit is een templatesysteem, geen clientframework
- Fluent met PostgreSQL
- Native HTML, CSS en modulair JavaScript zonder bundler in de MVP
- Swift Testing of XCTest voor unit- en integratietests
- Docker voor reproduceerbare lokale en productie-builds

Kies concrete versies pas bij de eerste implementatie en leg ze vast in
`Package.swift` en de lockfile. Controleer vooraf de ondersteunde Swift/Vapor-
combinatie.

### 3.1.1 Taalconventie

Gebruik Engels voor Swift-symbolen, module- en bestandsnamen, databaseobjecten,
migraties, API-contracten, routepaden, JavaScript/CSS-symbolen, codecomments,
technische foutcodes, logs en testnamen. `Aanbiedingspan` is de enige Nederlandse
naam die in code mag blijven staan. Bestaande domeintermen worden dus bijvoorbeeld
`DietaryPreference`, `PantryIngredient`, `SupermarketChain` en `MatchScore`.

Gebruik correct Nederlands voor alle tekst die een bezoeker of administrator ziet:
navigatie, labels, knoppen, hulpteksten, validatiefouten, lege toestanden,
fouttoestanden, e-mailteksten en toegankelijkheidslabels. Houd UI-copy in view- of
localizationresources en niet verspreid als string literals door controllers of
domeinservices. Externe
recepttitels en bronnamen blijven uiteraard zoals de beheerder ze invoert.

Schrijf waar mogelijk op B2-niveau of eenvoudiger:

- gebruik korte, actieve zinnen en bekende woorden;
- geef iedere alinea één hoofdboodschap en iedere knop één duidelijke actie;
- leg noodzakelijke juridische of technische termen direct in gewone taal uit;
- schrijf foutmeldingen die vertellen wat er misging en hoe de gebruiker verder kan;
- gebruik thematische taal alleen wanneer de letterlijke betekenis duidelijk blijft;
- zet belangrijke informatie niet alleen in humor, beeldspraak, tooltip of icoon.

Een leesbaarheidsscore is alleen een signaal. Een menselijke contentreview en tests
met gebruikers wegen zwaarder, omdat automatische B2-metingen context missen.

### 3.2 Voorgestelde structuur

```text
Sources/App/
  Config/             configuratie, routes en middleware
  Domain/             domeintypen en pure regels
  Models/             Fluent-modellen
  Migrations/         databaseschema en referentiedata
  Repositories/       databasecontracten en implementaties
  Services/           zoeken, scoring, import, afbeeldingen
  Controllers/        publieke, API- en adminroutes
  DTOs/               request/response-validatie
  Views/              Leaf-contexten en viewmodellen
Resources/
  Views/               Leaf-templates en partials
  Public/css/          thematische, responsive CSS
  Public/js/           wizard, filters en toegankelijke interacties
Tests/AppTests/
```

Controllers blijven dun. Rangschikking en dieet-/uitsluitlogica horen in pure,
goed testbare services. Repositories schermen Fluent af zodat zoeklogica zonder
HTTP en waar nodig zonder database getest kan worden.

### 3.3 Domeinmodel

| Entiteit | Belangrijkste velden |
| --- | --- |
| `Recipe` | id, title, slug, summary, image, sourceURL, sourceName, durationMinutes, status, timestamps |
| `Ingredient` | id, canonicalName, slug, category, allergenTags, timestamps |
| `IngredientAlias` | ingredientID, alias, normalizedAlias |
| `RecipeIngredient` | recipeID, ingredientID, displayText, quantity, unit, optional, weightFactor |
| `DietaryPreference` | id, name, slug, description, active |
| `RecipeDietaryPreference` | recipeID, preferenceID, verificationSource |
| `SupermarketChain` | id, name, slug, logo, active |
| `Offer` | id, ingredientID, chainID, title, price, originalPrice, startsAt, endsAt, source, status |
| `AdminUser` | id, username, passwordHash, role, active, lastLoginAt |
| `AuditEvent` | actorID, action, entityType, entityID, safeChanges, createdAt |
| `ImportSource` | id, name, contentType, authorizationStatus, scope, evidenceReference, grantedAt, expiresAt, revokedAt |
| `ImportRun` | source, status, counters, startedAt, finishedAt, errorSummary |

Gebruik UUID’s als primaire sleutels. Normaliseer ingrediënten bij invoer naar een
canoniek ingrediënt, maar bewaar `displayText` om de oorspronkelijke formulering te
kunnen tonen. Bedragen worden als integer in eurocenten opgeslagen; tijden in UTC.

### 3.4 Publieke routes

| Methode en route | Functie |
| --- | --- |
| `GET /` | server-renderde wizard of resultatenpagina |
| `GET /about` | missie, score-uitleg en contactinformatie |
| `GET /privacy` | privacyverklaring en uitleg over lokale opslag |
| `POST /search` | volledige HTML-response voor progressive enhancement |
| `POST /api/search` | JSON of HTML-partial voor dynamische resultaten |
| `GET /api/ingredients` | openbare ingrediëntenlijst voor lokale autocomplete |
| `GET /api/supermarkets` | algemene lijst met supermarktketens |
| `GET /health/live` | proces leeft, zonder afhankelijkheidscheck |
| `GET /health/ready` | database en vereiste services zijn gereed |

Filterparameters krijgen een gedocumenteerde bovengrens en server-side validatie.
Zoekrequests gebruiken POST zodat keuzes niet in URLs, browsergeschiedenis of
standaard accesslogs belanden. De requestdata wordt na de response niet bewaard.
Gebruik UUID’s/slugs in queries, nooit vrije SQL-fragmenten. De externe recept-URL
wordt uitsluitend als gewone link weergegeven; de server haalt die URL niet op
namens een bezoeker.

### 3.5 Zoek- en scoringsmodel

Definieer per recept de **relevante** ingrediënten als alle niet-optionele
ingrediënten. Optionele ingrediënten kunnen later met een lagere factor meetellen.

Voor ingrediënt `i`:

```text
weight(i) = max(0, RecipeIngredient.weightFactor; default 1)
statusScore(i) = 3 when in pantry and on offer
                 2 when only in pantry
                 1 when only on offer at a selected supermarket
                 0 otherwise

earnedScore     = sum(weight(i) * statusScore(i))
maximumScore    = sum(weight(i) * 3)
matchPercentage = floor(100 * earnedScore / maximumScore)
```

Hierdoor telt “alleen in huis” tweemaal zo zwaar als “alleen in aanbieding”; de
combinatie krijgt de maximale score 3. Maak de gewichten configureerbaar, maar
wijzig ze alleen met tests en een vastgelegde productbeslissing. Recepten worden in
deze volgorde gesorteerd:

1. geen uitgesloten ingrediënten en voldoen aan alle gekozen gerechtswensen;
2. aflopend matchpercentage;
3. aflopend gewogen aandeel ingrediënten in huis;
4. oplopend aantal nog benodigde ingrediënten;
5. oplopende tijdsduur;
6. titel en id als stabiele tie-breakers.

Toon naast het percentage ook `x van y in huis` en `z in aanbieding`, zodat de
score uitlegbaar is. Een recept met nul relevante ingrediënten krijgt 0% en wordt
onderaan geplaatst. Kies in de MVP voor “voldoet aan alle wensen” (AND-semantiek).

Bereken de score in een pure Swift-service voor correctheid en hergebruik deze in de
HTML- en API-flow. Voeg pas na meting precomputatie of een zoekengine toe.
PostgreSQL-indexen zijn minimaal nodig op slugs, genormaliseerde ingrediëntnamen,
koppelvelden, receptstatus en geldigheidsvelden van aanbiedingen.

## 4. Front-end en visueel thema

Gebruik semantische HTML met server-renderde basisinhoud. JavaScript verzorgt de
verbeterde wizardervaring, autocomplete, filterrequests en `localStorage`. Elke
module is klein, heeft geen globale mutable state en gebruikt `AbortController` om
achterhaalde zoekrequests te annuleren.

De globale footer linkt op iedere publieke pagina naar “Over Aanbiedingspan” en
“Privacy”. Er verschijnt geen algemene cookiewall: vóór opt-in wordt voor bezoekers
niets persistent opgeslagen en de bewaaroptie staat op het relevante moment in de
wizard. Accepteren en weigeren zijn visueel gelijkwaardig; de checkbox is standaard
uit en weigeren beperkt de zoekfunctie niet.

Het thematische uiterlijk is “warme voorraadkast/markt”: aardse groenen, warme
crèmeachtergrond en één contrasterende aanbiedingskleur. Leg kleuren, typografie,
ruimte en radii vast als CSS custom properties. Visuele voedselstatus mag nooit
alleen met kleur worden overgebracht; voeg tekst en iconen toe.

Ontwerp mobile-first vanaf 320 px, met onder andere:

- aanraakdoelen van minimaal ongeveer 44 × 44 px;
- éénkoloms kaarten op smalle schermen;
- vaste maar niet inhoudbedekkende primaire actie in de wizard;
- responsieve afbeeldingen met vaste verhouding om layoutverspringing te beperken;
- ondersteuning voor `prefers-reduced-motion`, zoom en hoog contrast;
- zichtbare focus, skiplink, correcte labels en live-regio voor resultaataantallen.

WCAG 2.2 niveau AA is een releasecriterium, geen vrijblijvende wens. Een bekende
afwijking blokkeert de release totdat deze is opgelost of aantoonbaar niet van
toepassing is. Neem naast technische toegankelijkheid ook begrijpelijke taal,
voorspelbare interacties en herstelbare fouten mee.

## 5. Beveiliging, privacy en betrouwbaarheid

- Gebruik Vapor Sessions uitsluitend voor administrators, met veilige, `HttpOnly`,
  `SameSite=Lax` cookies en `Secure` in productie. Publieke bezoekers krijgen geen
  account, sessiecookie of server-side profiel.
- Hash wachtwoorden met een actueel, door Vapor ondersteund wachtwoordalgoritme;
  nooit zelf cryptografie implementeren.
- Bescherm alle muterende adminrequests met CSRF-tokens.
- Voeg login-rate-limiting, generieke foutmeldingen en tijdelijke vertraging toe.
- Autoriseer op iedere adminroute server-side; het verbergen van knoppen is niet
  voldoende.
- Valideer afbeeldingsuploads op type, grootte en gedecodeerde dimensies; genereer
  veilige bestandsnamen en serveer uploads buiten executable paden.
- Sanitize/escape beheerinvoer bij uitvoer. Sta geen willekeurige HTML toe.
- Laat secrets alleen via environment/secrets-management binnenkomen.
- Log geen wachtwoorden, sessies, CSRF-tokens, IP-adressen, user-agentstrings,
  filterkeuzes of andere bezoekerskenmerken. Richt ook proxy- en platformlogs zo in.
- Gebruik geen analytics, trackingpixels of third-party scripts die bezoekersdata
  verzamelen. De applicatie vraagt nooit om locatie.
- Schrijf vóór actieve opt-in niets naar `localStorage`. Bij opt-in worden alleen de
  gedocumenteerde wizardkeuzes, toestemmingsdatum, vervaldatum en schemaversie
  opgeslagen. Bij intrekken, verlopen of ongeldige data wordt alles verwijderd.
- Voeg securityheaders toe, waaronder een strikte Content Security Policy.
- Maak databaseback-ups en test herstel periodiek.

## 6. Implementatiefasen

### Fase 0 — Besluiten en technische basis

- Bevestig productkeuzes, databronnen, licenties en aanboddekking.
- Leg per beoogde automatische recept- of aanbodbron de expliciete toestemming,
  reikwijdte, geldigheidsduur en contactpersoon vast voordat adapterwerk start.
- Leg ondersteunde Swift/Vapor/PostgreSQL-versies vast.
- Initialiseer Vapor-app, configuratie, formatter/linter, tests en CI.
- Voeg developmentcontainer of Docker Compose met PostgreSQL toe.
- Maak een minimale design-token- en HTML-prototype van wizard plus kaart.
- Leg een contentreview vast voor correct Nederlands, B2 of eenvoudiger en behoud
  van de thematische maar duidelijke toon.
- Bevestig naam en contactgegevens van de verantwoordelijke, contactmailboxen en de
  bewaartermijnen voor lokale keuzes en inkomende e-mail.

**Gereed wanneer:** app en database lokaal reproduceerbaar starten, CI groen is en
open productbesluiten als issues/ADR’s zijn vastgelegd.

### Fase 1 — Datamodel en adminbasis

- Implementeer migraties, repositories en seeddata.
- Voeg adminlogin, rollen, CSRF, sessies en auditlogging toe.
- Bouw CRUD en publicatieworkflow voor gerechtswensen, ingrediënten en recepten.
- Maak recepten volledig handmatig invoerbaar; bouw geen receptadapter zonder een
  geautoriseerde `ImportSource`.
- Voeg validatie voor unieke slugs, geldige URLs en positieve tijdsduur toe.

**Gereed wanneer:** een editor veilig een conceptrecept kan invoeren, koppelen en
publiceren en een onbevoegde gebruiker geen adminactie kan uitvoeren.

### Fase 2 — Wizard en toegankelijke basiszoekfunctie

- Bouw server-rendered wizard en filtermodel.
- Implementeer autocomplete en conflictregel “in huis” versus “uitsluiten”.
- Maak een pure Swift-zoekservice met dieet- en uitsluitfilters.
- Bouw resultatenkaarten en een no-JavaScript POST-flow.
- Bewaar/restaureer filters na opt-in via `localStorage` en voeg “Wizard opnieuw
  starten” toe; zonder opt-in blijft de state alleen voor het actuele bezoek bestaan.
- Bouw de opt-in standaard uit, inclusief hover/focus/click-uitleg, privacylink en
  gelijkwaardige werking bij weigeren.
- Voeg de pagina’s “Over Aanbiedingspan” en “Privacy” en globale footerlinks toe.

**Gereed wanneer:** de complete flow op mobiel, met toetsenbord en zonder JavaScript
bruikbaar is, reset aantoonbaar alle lokale wizarddata wist en server-/logcontrole
aantoont dat keuzes na verwerking niet bewaard blijven.

### Fase 3 — Supermarkten, aanbiedingen en ranking

- Implementeer een algemene lijst met supermarktketens en adminbeheer, zonder
  filialen, locatievelden of geo/postcodezoeking.
- Maak aanbiedingen volledig handmatig invoerbaar.
- Definieer afzonderlijke `RecipeProvider`- en `OfferProvider`-contracten. Bouw en
  activeer een concrete adapter alleen voor een bron met geldige, expliciete
  toestemming voor het betreffende contenttype en gebruik.
- Controleer de autorisatie opnieuw vóór iedere automatische importrun; een verlopen
  of ingetrokken toestemming blokkeert de taak direct.
- Koppel aanbiedingen deterministisch aan canonieke ingrediënten; stuur twijfel naar
  een admin-reviewqueue.
- Implementeer en test het scoringsmodel en de score-uitleg.
- Voeg verval van aanbiedingen en periodieke importtaken toe.

**Gereed wanneer:** alleen actuele aanbiedingen van gekozen supermarktketens
meetellen en tests de exacte scores 3/2/1/0 aantonen.

### Fase 4 — Hardening en beheer

- Voeg paginering, lege/error/loading-states en afbeeldingsfallback toe.
- Voer toegankelijkheids-, beveiligings-, performance- en browsertests uit.
- Maak dashboards voor fouten, latency, imports en mislukte logins.
- Test back-up/restore, migratie-forward en operationele runbooks.
- Laat alle UI-copy, privacytekst en bronvermeldingen beoordelen op inhoud,
  toegankelijkheid, correct Nederlands en B2 of eenvoudiger.

**Gereed wanneer:** alle MVP-acceptatiecriteria zijn bewezen, kritieke bevindingen
zijn opgelost en het uitrolplan met stagingdata is geoefend.

## 7. Teststrategie

- **Unit:** normalisatie, conflicten, AND-filtering, scores 3/2/1/0, tie-breakers,
  tijdzones, aanbodgeldigheid, lokale opt-in/reset/verval en rollen.
- **Repository/integratie:** migraties op een echte PostgreSQL-testdatabase,
  transacties, constraints en queryresultaten.
- **HTTP:** validatie, statuscodes, redirects, sessies, CSRF, autorisatie,
  rate-limits en content negotiation.
- **Contract:** per aanbodadapter vaste fixtures voor geldige, gewijzigde en kapotte
  brondata; pas dezelfde tests toe op receptadapters.
- **Importautorisatie:** zonder geldige toestemming start geen adapter; verlopen,
  ingetrokken of inhoudelijk te beperkte toestemming wordt veilig geweigerd.
- **End-to-end:** wizard → filters → reset → externe link en admin login →
  publiceren; controleer dat wizardkeuzes niet server-side bewaard worden.
- **Privacy-opslag:** vóór opt-in geen `localStorage`; na opt-in alleen toegestane
  sleutels; weigeren blijft werken; intrekken en verlopen wissen alles; weigering
  wordt niet onthouden.
- **Content:** footerlinks werken, privacy-anker opent in een nieuw tabblad en
  contactlinks gebruiken bevestigde adressen; de Over-pagina legt de score 3/2/1/0,
  het percentage en harde filters correct uit.
- **Taal:** statische controle/code-review bevestigt Engelse technische namen en
  Nederlandse UI-copy; UI-tests controleren belangrijke Nederlandse teksten. Een
  menselijke contentreview controleert B2 of eenvoudiger en thematische helderheid.
- **Toegankelijkheid:** geautomatiseerde controle plus handmatig toetsenbord,
  screenreader, zoom, reduced motion, begrijpelijke foutmeldingen en een korte test
  met representatieve gebruikers. Automatiseerbare WCAG 2.2 AA-fouten blokkeren CI.
- **Performance:** representatieve dataset; meet p95 zoektijd, databasequeries en
  payloadgrootte. Stel de definitieve budgetten vast na een staging-baseline; eerste
  richtwaarde is p95 serverrespons onder 500 ms voor zoeken.
- **Security:** dependency-audit, OWASP-georiënteerde routecontrole en uploadtests.

Belangrijke scoringsgevallen worden als tabelgestuurde tests vastgelegd, inclusief
gelijke scores, ontbrekende duur, nul ingrediënten en verlopen aanbiedingen.

## 8. MVP-acceptatiecriteria

- Een nieuwe bezoeker doorloopt de drie stappen en kan ze later als filters wijzigen.
- Resultaten voldoen aan alle gekozen gerechtswensen en bevatten geen uitgesloten
  ingrediënten.
- De score is deterministisch en zichtbaar verklaard met exact 3 voor in huis én
  aanbieding, 2 voor in huis, 1 voor aanbieding en 0 anders.
- Alleen aanbiedingen die nu geldig zijn en bij een gekozen supermarktketen horen
  beïnvloeden de score.
- Er zijn geen consumentenaccounts, locatievelden of publieke sessiecookies;
  wizardkeuzes worden alleen voor de actuele request verwerkt en niet bewaard.
- “Wizard opnieuw starten” wist de lokale wizardkeuzes en opent stap één.
- De opt-in is standaard uit, duidelijk uitgelegd en niet nodig om te zoeken; zonder
  opt-in begint een volgend bezoek opnieuw bij de wizard.
- “Over Aanbiedingspan” en “Privacy” zijn mobiel en met toetsenbord bereikbaar vanaf
  elke publieke pagina. De Over-pagina bevat de definitieve contactgegevens en een
  begrijpelijke, rekenkundig correcte uitleg van score en filters.
- Publieke en adminteksten zijn correct Nederlands, waar mogelijk B2 of eenvoudiger,
  en blijven begrijpelijk zonder afhankelijkheid van beeldspraak of tooltips.
- Receptkaarten bevatten alle gevraagde metadata en linken veilig naar de bron.
- Kernfunctionaliteit werkt op recente mobiele browsers en via een HTML POST-flow
  zonder JavaScript.
- Adminfuncties zijn alleen na login en passende rol bereikbaar en mutaties worden
  geaudit.
- Recepten en aanbiedingen zijn handmatig beheerbaar; automatische imports werken
  alleen voor bronnen met vastgelegde, geldige en passende expliciete toestemming.
- Migraties, tests, lint/format en productiebuild slagen in CI.
- Readiness, logging, back-up en rollback zijn aantoonbaar ingericht.

## 9. Niet in de eerste versie

- Consumentenaccounts, locaties en synchronisatie tussen apparaten
- Zelflerende of gepersonaliseerde ranking
- Automatisch importeren of scrapen zonder expliciete toestemming van de bron
- Betalen, boodschappenmand of voorraadhoeveelheden
- Native mobiele apps
- Een aparte zoekcluster voordat PostgreSQL aantoonbaar tekortschiet

## 10. Open beslissingen

Leg deze vóór de betreffende fase vast in korte Architecture Decision Records:

1. Welke recept- en aanbiedingbronnen zijn juridisch en technisch toegestaan?
2. Welke gerechtswensen zijn redactionele labels en welke kunnen betrouwbaar uit
   allergenen/ingrediënten worden afgeleid?
3. Waar worden receptafbeeldingen opgeslagen en welke gebruiksrechten gelden?
4. Welke naam en contactgegevens worden voor de verantwoordelijke gepubliceerd?
5. Welke mailprovider wordt gebruikt en hoe lang worden afgehandelde berichten
   bewaard?
