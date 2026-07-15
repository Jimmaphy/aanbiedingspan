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
Privacy. De catalogus bevat voorlopig herkenbare demodata en is nog niet via het
adminportaal te beheren.

## Lokaal starten

Vereisten: Swift 6, Docker en Docker Compose.

```bash
docker compose up -d
swift run
```

Open daarna `http://127.0.0.1:8080`. De database-instellingen hebben veilige lokale
standaardwaarden uit `docker-compose.yml`; gebruik environmentvariabelen uit
`.env.example` voor andere omgevingen.

## Controleren

```bash
swift test
swift build -c release
```

De publieke demorecepten linken naar `example.com` en zijn geen productiecontent.
Er zijn geen automatische importadapters opgenomen.
