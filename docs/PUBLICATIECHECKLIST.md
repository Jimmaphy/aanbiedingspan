# Publicatiechecklist Aanbiedingspan

Dit document beschrijft concreet wat nodig is om de huidige versie correct en
veilig openbaar te maken. Het vult het algemene [uitrolplan](UITROLPLAN.md) aan met
de beperkingen en instellingen van de code die nu in deze repository staat.

## 1. Aanbevolen eerste productieopstelling

Publiceer de eerste versie met deze onderdelen:

- één Linux-app-instance voor de Vapor-app;
- een beheerde PostgreSQL-database in hetzelfde private netwerk;
- een persistent volume voor `Public/uploads/recipes`;
- een reverse proxy of hostingplatform dat TLS beëindigt;
- een secretmanager voor database- en beheergegevens;
- externe monitoring voor de healthchecks en back-ups.

Gebruik voorlopig **één app-instance**. Beheersessies staan in het geheugen van de
app en receptafbeeldingen worden op het lokale volume geschreven. Meerdere instances
kunnen daardoor verschillende sessies of afbeeldingsbestanden zien. Horizontaal
schalen kan pas veilig na de invoering van gedeelde sessieopslag en gedeelde
objectopslag.

## 2. Wat je vóór publicatie moet regelen

### Hosting en domein

- [ ] Kies een hostingplatform dat een Swift 6 releasebuild of een eigen Linux-image
  kan uitvoeren.
- [ ] Zorg dat de werkmap van het proces de projectroot is en dat `Public` en
  `Resources/Views` in het releaseartifact staan.
- [ ] Reserveer één persistent volume en koppel dit aan
  `Public/uploads/recipes`. Bij een container met werkmap `/app` is het mountpad
  bijvoorbeeld `/app/Public/uploads/recipes`.
- [ ] Koppel het productiedomein en laat al het HTTP-verkeer permanent doorsturen
  naar HTTPS.
- [ ] Gebruik een geldig TLS-certificaat met automatische vernieuwing.
- [ ] Voeg na een geslaagde TLS-controle bij de proxy HSTS toe, bijvoorbeeld
  `Strict-Transport-Security: max-age=31536000; includeSubDomains`. Gebruik
  `preload` pas als alle subdomeinen blijvend HTTPS ondersteunen.

Deze repository bevat nog geen productie-Dockerfile of CI/CD-configuratie. Maak
daarom vóór de eerste uitrol een reproduceerbaar releaseartifact met een vastgelegde
Swift-toolchain. Promoveer daarna exact hetzelfde artifact van staging naar
productie.

### PostgreSQL

- [ ] Maak een aparte productiedatabase en databasegebruiker aan. Geef die gebruiker
  alleen rechten op deze database.
- [ ] Gebruik een uniek databasewachtwoord uit de secretmanager.
- [ ] Plaats app en database in hetzelfde afgeschermde private netwerk. Stel
  PostgreSQL niet rechtstreeks open voor het internet.
- [ ] Schakel automatische back-ups en point-in-time recovery in.
- [ ] Kies een bewaartermijn, bijvoorbeeld 30 dagen, en voer vóór livegang één
  echte hersteltest uit.
- [ ] Maak vóór iedere migratie een herstelpunt en voer de migratie eerst uit op
  staging met een recente, geschoonde databasekopie.

De applicatie gebruikt momenteel een PostgreSQL-verbinding met TLS uitgeschakeld.
Dit is alleen verantwoord binnen een aantoonbaar afgeschermd privénetwerk. Vereist
de gekozen databaseprovider TLS of loopt het verkeer over een gedeeld of openbaar
netwerk, publiceer dan nog niet: voeg eerst configureerbare certificaatcontrole aan
de databaseclient toe.

### Secrets en beheeraccount

Stel onderstaande variabelen in via de secretmanager van het platform. Plaats ze
niet in Git, een image, buildlog of productie-`.env` op schijf.

| Variabele | Productiewaarde |
| --- | --- |
| `DATABASE_HOST` | Private hostnaam van PostgreSQL |
| `DATABASE_PORT` | Meestal `5432` |
| `DATABASE_NAME` | Naam van de aparte productiedatabase |
| `DATABASE_USERNAME` | Gebruiker met minimale rechten |
| `DATABASE_PASSWORD` | Uniek, willekeurig databasewachtwoord |
| `ADMIN_USERNAME` | Niet eenvoudig te raden beheerdersnaam |
| `ADMIN_PASSWORD_HASH` | Bcrypt-hash met cost 12 of hoger; nooit het wachtwoord |
| `ADMIN_ROLE` | `admin` of `editor` |
| `LOG_LEVEL` | `notice` voor de eerste productie-uitrol |

- [ ] Genereer een uniek beheerderswachtwoord met een wachtwoordmanager en deel het
  alleen via een veilig kanaal.
- [ ] Bewaar uitsluitend de bcrypt-hash als `ADMIN_PASSWORD_HASH`.
- [ ] Controleer dat de secretmanager `$`-tekens in de bcrypt-hash ongewijzigd
  doorgeeft.
- [ ] Beperk `/admin` bij voorkeur aanvullend met VPN, een IP-toegangslijst of een
  identity-aware proxy.
- [ ] Stel bij de proxy een limiet in op inlogpogingen, bijvoorbeeld vijf pogingen
  per minuut. Bewaar volledige IP-adressen daarvoor niet langer dan technisch nodig
  en neem ze niet op in permanente logs.

Deze versie ondersteunt één beheeraccount en geen tweefactorauthenticatie. Geef de
beheerroute daarom niet ruimer toegang dan nodig.

### Publieke informatie en rechten

- [ ] Stel na de eerste login onder **Beheer → Contactgegevens** het bewaakte
  openbare e-mailadres in.
- [ ] Vervang vóór livegang de tijdelijke tekst op de privacypagina door de juiste
  naam van de verantwoordelijke en een bewaakt privacyadres. Hiervoor is nog een
  kleine codewijziging nodig; de huidige contactinstelling wijzigt alleen de pagina
  “Over Aanbiedingspan”.
- [ ] Leg een bewaartermijn en werkproces vast voor e-mail die op de openbare
  adressen binnenkomt.
- [ ] Controleer het gebruiksrecht van het logo, de RealGoodAI-afbeelding en iedere
  geüploade receptafbeelding.
- [ ] Controleer per receptbron dat titel, samenvatting, link en afbeelding gebruikt
  mogen worden.
- [ ] Vul recepten en aanbiedingen alleen handmatig in. Activeer geen scraper of
  automatische import zonder aantoonbare toestemming van de bron.
- [ ] Laat de Nederlandse publieke en beheertexten nog één keer menselijk beoordelen
  op juistheid en begrijpelijkheid.

## 3. Proxy- en platforminstellingen

- Luister met de app alleen op de interne interface; laat de proxy publiek verkeer
  afhandelen.
- Sta requestbodies tot maximaal 6 MiB toe voor receptafbeeldingen en stel voor
  andere routes geen hogere limiet in dan nodig.
- Cache geen beheerpagina's, sessiereacties of zoek-POST-responses.
- Laat proxy-, CDN- en platformlogs geen requestbody, querykeuzes, volledig
  IP-adres of user-agentprofiel bewaren.
- Behoud de beveiligingsheaders van de app. Overschrijf de CSP,
  `Permissions-Policy`, `X-Frame-Options`, `Referrer-Policy` of
  `X-Content-Type-Options` niet met zwakkere waarden.
- Controleer dat `/admin` alleen via HTTPS bereikbaar is. De admincookie krijgt
  alleen in Vapors productieomgeving het kenmerk `Secure`.

## 4. Build, migratie en startcommando

Bouw en test vanaf de vastgelegde commit:

```bash
swift package resolve
swift test
swift build -c release
```

Voer migraties als een eenmalige releasejob uit, niet gelijktijdig vanuit meerdere
app-instances:

```bash
.build/release/Run migrate --env production -y
```

Start daarna de webserver expliciet in de productieomgeving:

```bash
.build/release/Run serve --env production --hostname 0.0.0.0 --port "$PORT"
```

Het argument `--env production` is verplicht: het activeert onder andere de veilige
admincookie en Leaf-caching. Gebruik geen automatische migratie bij iedere start.
Een mislukte migratie moet de release stoppen voordat nieuw verkeer naar de app gaat.

## 5. Healthchecks en monitoring

Configureer het platform als volgt:

- liveness: `GET /health/live`, verwacht HTTP 200;
- readiness: `GET /health/ready`, verwacht HTTP 200 en dus een werkende database;
- controlefrequentie: iedere 30 seconden;
- alarm: na drie opeenvolgende fouten;
- externe controle: homepage en `/health/ready` vanaf buiten het platform.

Maak daarnaast meldingen voor:

- verhoogde aantallen 5xx-responses;
- mislukte adminlogins en opvallende rate-limitactiviteit;
- databaseopslag, trage queries en verbroken verbindingen;
- mislukte back-ups of een te oud herstelpunt;
- vol of onbereikbaar afbeeldingsvolume;
- recepten met kapotte externe links en verlopen aanbiedingen.

Wijs voor iedere melding één eigenaar en een bereikbaar escalatiekanaal aan.

## 6. Uitvoerbare releasevolgorde

1. Leg de te publiceren commit-hash en het releaseartifact vast.
2. Voer tests, releasebuild en een dependency-/imagescan uit.
3. Deploy hetzelfde artifact naar staging.
4. Test op staging desktop, mobiel, toetsenbord, JavaScript aan en de normale
   server-submit zonder JavaScript.
5. Controleer dat “Wizard opnieuw starten” alle lokale keuzes en toestemming wist.
6. Maak en verifieer een databaseherstelpunt.
7. Zet het productieartifact klaar zonder er verkeer naartoe te sturen.
8. Voer de migratiejob één keer uit en bewaar de uitvoer bij het releaselog.
9. Start de app met `--env production` en controleer beide healthchecks.
10. Test homepage, zoeken, een externe receptlink, adminlogin, contactgegevens en
    één afbeeldingupload.
11. Zet verkeer open en bewaak gedurende minimaal 30 minuten fouten, latency,
    database en opslag.
12. Noteer commit-hash, uitroltijd, migratieresultaat en uitvoerder.

## 7. Back-up en rollback

- Maak dagelijks een databaseback-up en een back-up van het afbeeldingsvolume.
- Test minimaal ieder kwartaal of beide samen naar een lege omgeving kunnen worden
  hersteld.
- Rol bij applicatiefouten terug naar het vorige releaseartifact dat met het
  actuele databaseschema overweg kan.
- Gebruik `migrate --revert` niet als standaard productierollback; een down-migratie
  kan gegevens verwijderen.
- Depubliceer een fout recept of aanbod via beheer wanneer alleen inhoud onjuist is.
- Roteer database- en beheercredentials direct bij een vermoeden van uitlekken.

## 8. Beslissing vóór livegang

De eerste versie is klaar om verkeer te ontvangen wanneer alle onderstaande punten
waar zijn:

- [ ] Productie draait als exact één app-instance met persistent afbeeldingsvolume.
- [ ] PostgreSQL is privé bereikbaar, geback-upt en succesvol hersteld in een test.
- [ ] Alle secrets staan in een secretmanager en de adminlogin is aanvullend begrensd.
- [ ] TLS, HTTPS-redirect, HSTS en healthchecks werken.
- [ ] Publiek contactadres, privacygegevens en gebruiksrechten zijn bevestigd.
- [ ] Migraties en de volledige kernflow zijn op staging geslaagd.
- [ ] Monitoring, eigenaar en rollbackartifact zijn beschikbaar.

Is één van deze voorwaarden niet vervuld, behandel dat punt dan als releaseblokker.

## 9. Technische referenties

- [Vapor: productieomgeving en procesvariabelen](https://docs.vapor.codes/basics/environment/)
- [Fluent: migraties uitvoeren en terugdraaien](https://docs.vapor.codes/fluent/migration/)
- [Vapor: uitgangspunten voor Docker-uitrol](https://docs.vapor.codes/deploy/docker/)
