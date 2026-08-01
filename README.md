# Aanbiedingspan

Aanbiedingspan wordt een mobiele singlepage-receptzoekmachine die gebruikers helpt
om eerst ingrediënten uit de eigen voorraad op te maken en daarna slim gebruik te
maken van lokale aanbiedingen.

Deze repository bevat vooralsnog de plannen en projectinstructies:

- [Implementatieplan](docs/IMPLEMENTATIEPLAN.md)
- [Uitrolplan](docs/UITROLPLAN.md)
- [Instructies voor Codex en andere LLM's](AGENTS.md)

## Status

De eerste verticale versie bevat de publieke wizard, server-side zoekfilters, de
3/2/1/0-ranking, optionele lokale opslag, receptenresultaten en de pagina’s Over en
Privacy. Onder `/admin` staat een beveiligd administratieportaal voor ingrediënten,
supermarkten, aanbiedingen, recepten, receptbronnen en gerechtswensen. Beheerlijsten
zijn doorzoekbaar. Recepten ondersteunen gekoppelde gerechtswensen, meerdere
ingrediënten en een handmatig geüploade JPEG-, PNG- of WebP-afbeelding van maximaal
5 MB. Recepten en aanbiedingen kunnen als concept worden opgeslagen. Alleen expliciet
gepubliceerde recepten en actuele, expliciet gepubliceerde aanbiedingen komen vanuit
de beheerdatabase op de publieke zoekpagina en in de zoek-API. Het beheerportaal
beheert ook het openbare contactadres voor de pagina “Over Aanbiedingspan”.

## Lokaal starten

Vereisten: Swift 6, Docker en Docker Compose.

```bash
docker compose up -d
swift run Run migrate
swift run
```

Open daarna `http://127.0.0.1:8080`. De database-instellingen hebben veilige lokale
standaardwaarden uit `docker-compose.yml`; gebruik environmentvariabelen uit
`.env.example` voor andere omgevingen. Stel voor `/admin` `ADMIN_USERNAME`, een
bcrypt-hash in `ADMIN_PASSWORD_HASH` en `ADMIN_ROLE` (`admin` of `editor`) in. Bewaar
nooit het leesbare wachtwoord in een configuratiebestand of commit.

Geüploade receptafbeeldingen staan lokaal in `Public/uploads/recipes`. Koppel deze map
in productie aan duurzame opslag en neem haar mee in back-ups; geüploade bestanden
worden bewust niet aan Git toegevoegd.

De lokale waarde van `DATABASE_PASSWORD` moet overeenkomen met
`docker-compose.yml`. De meegeleverde ontwikkelwaarde is `development-only`. Stop en
start de Vapor-server opnieuw nadat je `.env` hebt gewijzigd; bestaande processen
lezen de nieuwe waarde niet automatisch in.

## Controleren

```bash
swift test
swift build -c release
```

De snelle HTTP-tests gebruiken herkenbare demodata; normale omgevingen lezen de
publieke catalogus uit PostgreSQL. Er zijn geen automatische importadapters opgenomen.
