# ADR 0002: expliciete brontoestemming voor automatische imports

- Status: geaccepteerd
- Datum: 2026-07-15

## Context

Recepten en aanbiedingen kunnen handmatig door administrators worden beheerd.
Automatische imports maken beheer efficiënter, maar mogen niet worden gebouwd of
gebruikt zonder toestemming van de externe bron.

## Besluit

- Zowel recepten als aanbiedingen blijven volledig handmatig invoerbaar.
- Een automatische adapter wordt alleen ontworpen, gebouwd, toegevoegd en
  geactiveerd na aantoonbare expliciete toestemming van de betreffende bron.
- Toestemming wordt per bron en contenttype vastgelegd, inclusief reikwijdte,
  bewijsreferentie, ingangsdatum, eventuele vervaldatum en intrekking.
- Toestemming voor recepten geldt niet automatisch voor aanbiedingen en omgekeerd.
- Iedere automatische run controleert vooraf of de toestemming nog geldig en passend
  is. Bij ontbreken, verlopen of intrekken stopt de import veilig.
- Zonder toestemming wordt een bron niet gescrapet en niet automatisch bevraagd.

## Gevolgen

Handmatige invoer is de standaard en vormt geen afhankelijkheid van externe
integraties. Adapterwerk kan pas worden ingepland nadat de autorisatie is
geregistreerd. Het adminportaal toont de autorisatiestatus en het auditlog registreert
wijzigingen en geblokkeerde runs. Contract- en autorisatietests zijn verplicht voor
iedere recept- en aanbodadapter.
