# Aanbiedingspan publiceren bij STRATO

Deze tutorial brengt Aanbiedingspan vanaf een lege STRATO-server naar een werkende productiewebsite met HTTPS, database en externe back-ups. Voer de stappen in volgorde uit en ga pas verder als de controle onder een stap slaagt.

De tutorial gaat uit van:

- `aanbiedingspan.nl` als domein bij STRATO;
- een Mac waarop deze repository staat;
- één STRATO Linux-VPS met Ubuntu 24.04 LTS;
- Docker voor de website, PostgreSQL en Caddy;
- STRATO HiDrive met SFTP/rsync voor externe back-ups.

Tekst tussen `<` en `>` moet je vervangen door je eigen waarde; typ de punthaken niet mee.

> **Belangrijk:** maak de website pas bekend nadat hoofdstuk 13 volledig groen is. Vooral juridische gegevens, back-up en hersteltest zijn geen optionele afronding.

## 1. Benodigdheden verzamelen

Zorg voordat je begint voor:

- toegang tot de [STRATO-klantenlogin](https://www.strato.nl/apps/CustomerService);
- toegang tot het DNS-beheer van `aanbiedingspan.nl`;
- een wachtwoordmanager;
- het definitieve openbare contactadres en privacy-e-mailadres;
- de rechten om alle gebruikte afbeeldingen, logo's en teksten te publiceren;
- ongeveer een halve dag zonder tijdsdruk.

Maak in je wachtwoordmanager een item **Aanbiedingspan productie** met ruimte voor:

- IP-adres en rootwachtwoord van de server;
- wachtwoord van servergebruiker `deploy`;
- databasewachtwoord;
- gebruikersnaam en wachtwoord van het beheerpaneel;
- HiDrive-gebruikersnaam;
- locatie van de SSH- en back-upsleutels.

### Server kiezen

Bestel bij STRATO de **Linux VPS M** met:

- 4 virtuele CPU-kernen;
- 4 GB RAM;
- 120 GB NVMe-opslag;
- Ubuntu 24.04 LTS.

Dit is de aanbevolen startconfiguratie voor het hobbyproject. De website,
PostgreSQL en Caddy passen naar verwachting goed binnen 4 GB. Alleen het bouwen van
Swift kan tijdelijk meer geheugen vragen. Daarom maken we in hoofdstuk 4 een
swapbestand van 4 GB en is de Docker-build beperkt tot twee parallelle
compileertaken.

Neem niet direct de VPS L met 8 GB alleen voor de eenmalige buildpiek. Schaal pas
op als monitoring laat zien dat het normale gebruik structureel tegen de grens
loopt, of als builds ondanks swap en de taaklimiet herhaaldelijk mislukken. Kies
geen shared webhostingpakket: deze applicatie heeft een eigen proces, Docker en
PostgreSQL nodig.

Huidige STRATO VPS'en bevatten niet standaard een externe back-up. Regel daarom ook **HiDrive met SFTP/rsync-ondersteuning**, of een gelijkwaardige externe back-updienst. Een kopie op dezelfde VPS telt niet als echte back-up.

## 2. Ubuntu installeren en de STRATO-firewall instellen

1. Log in bij STRATO.
2. Open je VPS en kies de optie om een besturingssysteem te installeren.
3. Kies **Ubuntu 24.04 LTS**.
4. Stel een lang, uniek rootwachtwoord in en bewaar dit in je wachtwoordmanager.
5. Noteer het publieke IPv4-adres van de VPS als `SERVER_IP`.
6. Wacht tot STRATO meldt dat de installatie klaar is.

Open daarna bij dezelfde server het onderdeel **Firewall**. De precieze menunaam kan in de klantenlogin veranderen. Maak een inkomend firewallbeleid met uitsluitend:

| Protocol | Poort | Bron | Doel |
|---|---:|---|---|
| TCP | 22 | bij voorkeur je eigen IP, anders alle | SSH-beheer |
| TCP | 80 | alle | HTTP en certificaatuitgifte |
| TCP | 443 | alle | HTTPS |
| UDP | 443 | alle | HTTP/3, optioneel |

Activeer het beleid. STRATO geeft aan dat wijzigingen doorgaans binnen enkele minuten actief zijn. Open **nooit** poort 5432; PostgreSQL mag niet rechtstreeks vanaf internet bereikbaar zijn.

## 3. Veilige SSH-toegang maken

Open Terminal op je Mac en maak een aparte sleutel:

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/aanbiedingspan_strato -C "aanbiedingspan-productie"
```

Kies een sterke wachtwoordzin en bewaar die. Plaats daarna de publieke sleutel op de server; vervang het IP-adres:

```bash
cat ~/.ssh/aanbiedingspan_strato.pub | ssh root@<SERVER_IP> 'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys'
```

Log met de sleutel in:

```bash
ssh -i ~/.ssh/aanbiedingspan_strato root@<SERVER_IP>
```

Maak op de server een gewone beheerder aan:

```bash
adduser deploy
usermod -aG sudo deploy
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
install -m 600 -o deploy -g deploy /root/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys
```

Kies voor `deploy` opnieuw een uniek wachtwoord. Andere profielvragen van `adduser` mag je leeg laten.

Laat deze rootverbinding openstaan. Open een **tweede** Terminal-venster op je Mac en controleer eerst:

```bash
ssh -i ~/.ssh/aanbiedingspan_strato deploy@<SERVER_IP>
sudo whoami
```

De laatste opdracht moet `root` tonen. Pas daarna schakel je root- en wachtwoordinlog uit. Voer als `deploy` uit:

```bash
sudo nano /etc/ssh/sshd_config.d/99-aanbiedingspan.conf
```

Plak dit in het bestand:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

Sla in nano op met `Ctrl+O`, Enter en sluit met `Ctrl+X`. Controleer en herlaad SSH:

```bash
sudo sshd -t
sudo systemctl reload ssh
```

Sluit de tweede verbinding, log opnieuw in als `deploy` en controleer dat dit lukt. Pas dan mag de oude rootverbinding dicht.

## 4. Ubuntu bijwerken en de lokale firewall activeren

Voer op de server als `deploy` uit:

```bash
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y ca-certificates curl git rsync age ufw unattended-upgrades
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 443/udp
sudo ufw enable
sudo ufw status verbose
```

Controleer vanuit een tweede Terminal-venster dat SSH nog werkt. Herstart daarna indien Ubuntu daarom vraagt:

```bash
sudo reboot
```

Wacht een minuut en log opnieuw in als `deploy`.

### Swap instellen voor de 4 GB-server

Controleer eerst of Ubuntu al swap heeft:

```bash
swapon --show
free -h
```

Geeft `swapon --show` geen regels terug, maak dan één swapbestand van 4 GB:

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-aanbiedingspan.conf
sudo sysctl --system
```

Controleer het resultaat:

```bash
swapon --show
free -h
grep -F '/swapfile none swap sw 0 0' /etc/fstab
```

Je moet ongeveer 4 GB swap zien. Swap is hier een vangnet voor tijdelijke pieken
tijdens een Swift-build; het is geen vervanging voor RAM. Tijdens normaal gebruik
hoort de website niet voortdurend veel swap te gebruiken.

## 5. Docker installeren

Gebruik Docker's officiële Ubuntu-repository. Voer op de VPS uit:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo nano /etc/apt/sources.list.d/docker.sources
```

Plak dit bestand, waarbij `noble` hoort bij Ubuntu 24.04:

```text
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
```

Gebruik je bewust een ARM-server, verander dan `amd64` in `arm64`. Installeer Docker:

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker run --rm hello-world
sudo docker compose version
```

Beide laatste opdrachten moeten zonder fout eindigen. Voeg `deploy` niet toe aan de Docker-groep: lidmaatschap geeft feitelijk rootrechten. De tutorial gebruikt daarom steeds `sudo docker`.

## 6. De applicatie op de server zetten

Maak op de server de applicatiemap:

```bash
sudo mkdir -p /opt/aanbiedingspan
sudo chown deploy:deploy /opt/aanbiedingspan
```

Open daarna op je Mac een Terminal in de lokale repository:

```bash
cd /Users/wesley/Source/Jimmaphy/Aanbiedingspan
git status --short
```

Controleer wat Git toont. Publiceer alleen een versie waarvan de wijzigingen bewust zijn opgeslagen. Zet vervolgens de bestanden over:

```bash
rsync -az \
  --exclude '.git/' \
  --exclude '.build/' \
  --exclude '.env' \
  --exclude '.env.*' \
  ./ deploy@<SERVER_IP>:/opt/aanbiedingspan/
```

Controleer op de server:

```bash
cd /opt/aanbiedingspan
ls Dockerfile compose.production.yml Caddyfile Package.swift
```

Alle vier bestanden moeten worden genoemd. De productieopzet bestaat uit:

- `proxy`: Caddy, voor HTTPS en doorsturen naar de app;
- `app`: Aanbiedingspan;
- `database`: PostgreSQL 17;
- blijvende Docker-volumes voor database en receptafbeeldingen, plus een alleen-lezen
  koppeling naar de door root beveiligde certificaatmap op de VPS.

Er draait bewust maar één `app`-container. De huidige beheersessies zitten in het geheugen en receptafbeeldingen staan lokaal; meerdere instanties zouden zonder extra techniek onbetrouwbaar zijn.

## 7. Productiegeheimen instellen

Genereer op de server een databasewachtwoord:

```bash
openssl rand -hex 32
```

Bewaar de uitkomst onmiddellijk in je wachtwoordmanager.

Genereer een bcrypt-hash voor het beheerderswachtwoord:

```bash
sudo apt install -y whois
mkpasswd -m bcrypt -R 12
```

Typ het gekozen beheerderswachtwoord wanneer daarom wordt gevraagd. Bewaar zowel het wachtwoord als de volledige hash die met `$2` begint.

Maak op de server het geheime configuratiebestand:

```bash
cd /opt/aanbiedingspan
nano .env.production
```

Vul dit in. Zet de bcrypt-hash tussen **enkele** aanhalingstekens, zodat de dollartekens letterlijk blijven:

```dotenv
DOMAIN=aanbiedingspan.nl
DATABASE_NAME=aanbiedingspan
DATABASE_USERNAME=aanbiedingspan
DATABASE_PASSWORD=<LANG_WILLEKEURIG_DATABASEWACHTWOORD>
ADMIN_USERNAME=<GEKOZEN_BEHEERDERSNAAM>
ADMIN_PASSWORD_HASH='$2b$12$<REST_VAN_DE_HASH>'
ADMIN_ROLE=admin
LOG_LEVEL=notice
```

Beveilig het bestand en controleer alleen de variabelenamen, zonder de waarden af te drukken:

```bash
chmod 600 .env.production
sed 's/=.*$/=<ingesteld>/' .env.production
```

Dit bestand mag nooit in Git, een chatbericht of een screenshot terechtkomen.

## 8. Database en website voor het eerst starten

Bouw eerst de app. De eerste Swift-build kan meerdere minuten duren:

```bash
cd /opt/aanbiedingspan
sudo docker compose --env-file .env.production -f compose.production.yml build app
```

De Dockerfile bouwt Swift met maximaal twee parallelle taken, zodat de build op de
4 GB VPS minder geheugen tegelijk gebruikt. Controleer direct na de eerste build:

```bash
free -h
swapon --show
sudo docker stats --no-stream
sudo journalctl -k --grep='Out of memory' --since='30 minutes ago'
```

Een beetje gebruikte swap tijdens de build is acceptabel. Meldingen met
`Out of memory` zijn dat niet. Controleer in dat geval eerst dat de swap actief is
en probeer de build nog één keer. Overweeg pas daarna een grotere VPS of bouw de
Docker-image buiten de productieserver.

Start alleen PostgreSQL:

```bash
sudo docker compose --env-file .env.production -f compose.production.yml up -d database
sudo docker compose --env-file .env.production -f compose.production.yml ps
```

Wacht tot `database` de status `healthy` heeft. Voer daarna de databasemigraties uit:

```bash
sudo docker compose --env-file .env.production -f compose.production.yml run --rm app migrate --env production -y
```

Start de app nog zonder publiek verkeer:

```bash
sudo docker compose --env-file .env.production -f compose.production.yml up -d app
curl --fail http://127.0.0.1:8080/health/live
curl --fail http://127.0.0.1:8080/health/ready
```

Beide controles moeten slagen. Bekijk bij problemen de laatste logregels:

```bash
sudo docker compose --env-file .env.production -f compose.production.yml logs --tail=100 app database
```

De databasepoort wordt nergens naar de host gepubliceerd. Dat is belangrijk, omdat de huidige app PostgreSQL-TLS uitschakelt en daarom alleen via het afgeschermde Docker-netwerk met PostgreSQL mag praten.

## 9. Domein naar de VPS laten wijzen

Doe dit pas als hoofdstuk 8 geslaagd is.

1. Open in de STRATO-klantenlogin **Domeinen** en kies `aanbiedingspan.nl`.
2. Open **DNS-instellingen**.
3. Zet het A-record van het hoofddomein op `<SERVER_IP>`.
4. Laat `www` via een CNAME naar `aanbiedingspan.nl` wijzen, of geef `www` hetzelfde A-record.
5. Verwijder een oud AAAA-record als je IPv6 niet bewust op deze VPS hebt ingesteld.
6. Verander MX-, SPF-, DKIM- en DMARC-records niet; die horen bij e-mail.

DNS-wijzigingen kunnen volgens STRATO tot 24 uur nodig hebben. Controleer vanaf je Mac:

```bash
dig +short aanbiedingspan.nl A
dig +short www.aanbiedingspan.nl A
```

Beide namen moeten uiteindelijk het VPS-adres opleveren. Start de HTTPS-proxy nog
niet: daarvoor heeft Caddy eerst het certificaat en de privésleutel uit hoofdstuk 10
nodig.

## 10. Het gratis STRATO SSL-certificaat maken en activeren

Deze VPS gebruikt het gratis Domain Validation-certificaat uit het STRATO-pakket,
maar de installatie werkt anders dan bij STRATO-webhosting. STRATO beheert de
website niet: je maakt daarom op de VPS zelf een privésleutel en een Certificate
Signing Request (CSR), laat STRATO/Sectigo daarmee het certificaat uitgeven en
installeert de bestanden daarna in Caddy.

Gebruik in STRATO niet alleen de webhostingknop **SSL afdwingen**. De omleiding van
HTTP naar HTTPS wordt op deze VPS door Caddy geregeld.

### 10.1 Privésleutel en CSR op de VPS maken

Log via SSH in als `deploy` en maak een afgeschermde certificaatmap:

```bash
sudo install -d -m 700 -o root -g root /etc/caddy/certs
```

Maak vervolgens de sleutel en aanvraag. Dit is dezelfde Apache/OpenSSL-methode als
in de door STRATO gekoppelde Sectigo-handleiding, met een sleutel van 3072 bits en
beide gebruikte hostnamen in de aanvraag:

```bash
sudo openssl req -new -newkey rsa:3072 -nodes \
  -keyout /etc/caddy/certs/aanbiedingspan.key \
  -out /etc/caddy/certs/aanbiedingspan.csr \
  -addext "subjectAltName=DNS:aanbiedingspan.nl,DNS:www.aanbiedingspan.nl"
```

Vul de vragen zo in:

- **Country Name:** `NL`;
- **State or Province Name:** je provincie;
- **Locality Name:** je woonplaats;
- **Organization Name:** `Jimmaphy Media` als dat de naam is waaronder je werkt;
- **Organizational Unit Name:** leeg laten;
- **Common Name:** `aanbiedingspan.nl`, dus uitdrukkelijk zonder `www`;
- **Email Address:** leeg laten;
- **challenge password:** leeg laten;
- **optional company name:** leeg laten.

Beveilig de privésleutel en controleer de aanvraag:

```bash
sudo chmod 600 /etc/caddy/certs/aanbiedingspan.key
sudo chmod 644 /etc/caddy/certs/aanbiedingspan.csr
sudo openssl req -in /etc/caddy/certs/aanbiedingspan.csr \
  -noout -verify -subject -ext subjectAltName
```

Je moet `verify OK` zien en bij `Subject Alternative Name` zowel
`aanbiedingspan.nl` als `www.aanbiedingspan.nl`. Toon daarna de CSR:

```bash
sudo cat /etc/caddy/certs/aanbiedingspan.csr
```

Kopieer alles vanaf `-----BEGIN CERTIFICATE REQUEST-----` tot en met
`-----END CERTIFICATE REQUEST-----`. Deel of upload uitsluitend de `.csr`. De
private sleutel `aanbiedingspan.key` verlaat de VPS nooit en hoort ook niet in Git,
e-mail, HiDrive of de STRATO-klantenlogin.

### 10.2 Het inbegrepen certificaat bij STRATO aanvragen

1. Log in bij STRATO en open het pakket waaraan `aanbiedingspan.nl` en het gratis
   certificaat zijn gekoppeld.
2. Ga naar **Beveiliging → STRATO SSL** of kies **SSL beheren**. De precieze
   benaming kan per pakket verschillen.
3. Kies het inbegrepen Domain Validation-certificaat en klik op **Toewijzen**,
   **Configureren** of **Bestellen**.
4. Kies de route voor gebruik op een eigen server en plak de volledige CSR in het
   daarvoor bestemde veld. Selecteer `aanbiedingspan.nl`; de Common Name moet zonder
   `www` zijn.
5. Rond de domeinvalidatie af en wacht tot de status **Actief** of **Uitgegeven** is.
6. Download het servercertificaat én de CA-bundle/tussenliggende certificaten. Kies
   **Apache/OpenSSL** of **PEM** als STRATO om een serverformaat vraagt.

Een STRATO Single Domain-certificaat bevat volgens STRATO normaal zowel het
hoofddomein als `www`. Krijg je alleen een simpele webhostingtoewijzing en nergens
een CSR-veld of downloadknop, stop dan en vraag STRATO Support om het inbegrepen
certificaat voor gebruik op een eigen VPS uit te geven. Maak geen tweede betaald
certificaat aan voordat STRATO heeft bevestigd dat dit echt nodig is.

### 10.3 De certificaatbestanden op de VPS installeren

Pak een eventueel gedownload zipbestand eerst op je Mac uit. In de download staan
een domeincertificaat en een CA-bundle; de exacte bestandsnamen verschillen. Zet
alleen die twee openbare bestanden over en vervang de namen tussen `<...>`:

```bash
scp -i ~/.ssh/aanbiedingspan_strato \
  ~/Downloads/<DOMEINCERTIFICAAT_BESTANDSNAAM> \
  ~/Downloads/<CA_BUNDLE_BESTANDSNAAM> \
  deploy@<SERVER_IP>:/home/deploy/
```

Zet ze eerst onder tijdelijke namen klaar. Zo overschrijf je bij een latere
vernieuwing het werkende certificaat pas nadat alle controles zijn geslaagd. Het
domeincertificaat moet in de full chain vóór de CA-bundle staan:

```bash
sudo install -m 644 /home/deploy/<DOMEINCERTIFICAAT_BESTANDSNAAM> \
  /etc/caddy/certs/aanbiedingspan.new.crt
sudo install -m 644 /home/deploy/<CA_BUNDLE_BESTANDSNAAM> \
  /etc/caddy/certs/strato-ca-bundle.new.crt
sudo sh -c 'cat /etc/caddy/certs/aanbiedingspan.new.crt /etc/caddy/certs/strato-ca-bundle.new.crt > /etc/caddy/certs/aanbiedingspan.fullchain.new.pem'
sudo chmod 600 /etc/caddy/certs/aanbiedingspan.key
```

Controleer eerst de inhoud, geldigheidsduur en namen:

```bash
sudo openssl x509 -in /etc/caddy/certs/aanbiedingspan.fullchain.new.pem \
  -noout -subject -issuer -dates -ext subjectAltName
```

Ga alleen door als de vervaldatum in de toekomst ligt en de namen
`aanbiedingspan.nl` en `www.aanbiedingspan.nl` beide aanwezig zijn. Controleer dan
of het certificaat werkelijk bij de privésleutel hoort. De twee hashes moeten exact
gelijk zijn:

```bash
sudo openssl pkey -in /etc/caddy/certs/aanbiedingspan.key \
  -pubout -outform pem | sha256sum
sudo openssl x509 -in /etc/caddy/certs/aanbiedingspan.fullchain.new.pem \
  -pubkey -noout | sha256sum
```

Zijn de hashes gelijk, activeer dan de gecontroleerde bestanden:

```bash
sudo mv /etc/caddy/certs/aanbiedingspan.new.crt \
  /etc/caddy/certs/aanbiedingspan.crt
sudo mv /etc/caddy/certs/strato-ca-bundle.new.crt \
  /etc/caddy/certs/strato-ca-bundle.crt
sudo mv /etc/caddy/certs/aanbiedingspan.fullchain.new.pem \
  /etc/caddy/certs/aanbiedingspan.fullchain.pem
sudo chmod 644 /etc/caddy/certs/aanbiedingspan.crt \
  /etc/caddy/certs/strato-ca-bundle.crt \
  /etc/caddy/certs/aanbiedingspan.fullchain.pem
```

Verwijder na deze controle de tijdelijke kopieën uit `/home/deploy`; de definitieve
bestanden staan in `/etc/caddy/certs`:

```bash
rm /home/deploy/<DOMEINCERTIFICAAT_BESTANDSNAAM> \
  /home/deploy/<CA_BUNDLE_BESTANDSNAAM>
```

### 10.4 Caddy starten en HTTPS controleren

De meegeleverde Caddyconfiguratie leest het STRATO-certificaat alleen-lezen uit
`/etc/caddy/certs`. Controleer de configuratie vóór je de proxy start:

```bash
cd /opt/aanbiedingspan
sudo docker compose --env-file .env.production -f compose.production.yml \
  run --rm --no-deps proxy validate --config /etc/caddy/Caddyfile
```

Na `Valid configuration` start je Caddy:

```bash
sudo docker compose --env-file .env.production -f compose.production.yml up -d proxy
sudo docker compose --env-file .env.production -f compose.production.yml logs --tail=100 proxy
curl --fail --head https://aanbiedingspan.nl
curl --fail https://aanbiedingspan.nl/health/ready
```

Controleer wat bezoekers daadwerkelijk ontvangen:

```bash
openssl s_client -connect aanbiedingspan.nl:443 \
  -servername aanbiedingspan.nl </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

De proxy stuurt na een geslaagde HTTPS-verbinding ook HSTS mee. Voeg `preload` niet
toe: dat is moeilijk terug te draaien en voor deze eerste publicatie niet nodig.

Open daarna in een privévenster:

- `https://aanbiedingspan.nl`;
- `http://aanbiedingspan.nl` — dit moet naar HTTPS doorsturen;
- `https://www.aanbiedingspan.nl` — dit moet naar het hoofddomein doorsturen;
- `https://aanbiedingspan.nl/admin/login`.

Accepteer nooit een certificaatwaarschuwing. Controleer dan eerst de DNS-records,
poort 443, de certificaatnamen, de volgorde van de full chain en de Caddy-logs.

### 10.5 Vernieuwing niet vergeten

Een certificaat op een eigen VPS wordt niet vanzelf in Caddy vervangen. Noteer de
vervaldatum uit de controle hierboven in je agenda en zet twee herinneringen: 30
dagen en 14 dagen vóór die datum. Vraag het vernieuwde certificaat in STRATO aan,
download het en herhaal paragraaf 10.3. Controleer daarna de configuratie en laad
Caddy zonder onderbreking opnieuw:

```bash
cd /opt/aanbiedingspan
sudo docker compose --env-file .env.production -f compose.production.yml \
  exec proxy caddy reload --config /etc/caddy/Caddyfile
curl --fail --head https://aanbiedingspan.nl
```

## 11. Automatische externe back-up instellen

### 11.1 HiDrive voorbereiden

1. Activeer in HiDrive het SFTP/rsync-protocol; dit is niet in elk pakket inbegrepen.
2. Maak bij voorkeur een aparte HiDrive-gebruiker voor deze back-up.
3. Noteer diens gebruikersnaam volledig in kleine letters als `HIDRIVE_USER`.

Maak op de VPS als root een sleutel zonder wachtwoordzin, uitsluitend voor de automatische back-up:

```bash
sudo mkdir -p /root/.ssh
sudo ssh-keygen -t ed25519 -f /root/.ssh/aanbiedingspan_hidrive -C "aanbiedingspan-backup" -N ''
sudo cat /root/.ssh/aanbiedingspan_hidrive.pub
```

Kopieer de getoonde publieke sleutel. Open in HiDrive **Instellingen → Account → OpenSSH** en sla de sleutel op voor de back-upgebruiker.

Test vanaf de VPS:

```bash
sudo rsync -av -e 'ssh -i /root/.ssh/aanbiedingspan_hidrive' /etc/hostname <HIDRIVE_USER>@rsync.hidrive.strato.com:/users/<HIDRIVE_USER>/aanbiedingspan-test/
```

Controleer in HiDrive of `hostname` aanwezig is en verwijder daarna de testmap.

### 11.2 Back-ups versleutelen

Maak de encryptiesleutel **op je Mac**, niet op de server:

```bash
brew install age
mkdir -p ~/.config/age
age-keygen -o ~/.config/age/aanbiedingspan-backup-key.txt
```

Bewaar `aanbiedingspan-backup-key.txt` ook versleuteld offline. Noteer de openbare sleutel die met `age1` begint. Alleen die openbare sleutel gaat naar de VPS; de geheime sleutel mag daar nooit staan.

### 11.3 Back-upscript maken

Maak op de VPS:

```bash
sudo nano /usr/local/sbin/aanbiedingspan-backup
```

Plak dit en vervang de twee waarden bovenaan:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

HIDRIVE_USER="<HIDRIVE_USER_IN_KLEINE_LETTERS>"
AGE_RECIPIENT="<OPENBARE_SLEUTEL_DIE_MET_AGE1_BEGINT>"
PROJECT_DIR="/opt/aanbiedingspan"
BACKUP_ROOT="/var/backups/aanbiedingspan"
STAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
TARGET="${BACKUP_ROOT}/${STAMP}"
COMPOSE=(docker compose --env-file .env.production -f compose.production.yml)

install -d -m 700 "${TARGET}"
cd "${PROJECT_DIR}"

"${COMPOSE[@]}" exec -T database sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  | age -r "${AGE_RECIPIENT}" -o "${TARGET}/database.dump.age"

"${COMPOSE[@]}" exec -T app tar -czf - -C /app/Public/uploads/recipes . \
  | age -r "${AGE_RECIPIENT}" -o "${TARGET}/uploads.tar.gz.age"

sha256sum "${TARGET}"/*.age > "${TARGET}/SHA256SUMS"
find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d -mtime +13 -exec rm -rf -- {} +

rsync -az --delete \
  -e 'ssh -i /root/.ssh/aanbiedingspan_hidrive -o BatchMode=yes' \
  "${BACKUP_ROOT}/" \
  "${HIDRIVE_USER}@rsync.hidrive.strato.com:/users/${HIDRIVE_USER}/aanbiedingspan/"
```

Maak het uitvoerbaar en test het:

```bash
sudo chmod 700 /usr/local/sbin/aanbiedingspan-backup
sudo /usr/local/sbin/aanbiedingspan-backup
sudo find /var/backups/aanbiedingspan -maxdepth 2 -type f
```

Controleer ook in HiDrive dat er drie bestanden in de nieuwste map staan.

### 11.4 Dagelijkse timer maken

Maak met `sudo nano` het bestand `/etc/systemd/system/aanbiedingspan-backup.service`:

```ini
[Unit]
Description=Back-up van Aanbiedingspan
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/aanbiedingspan-backup
```

Maak `/etc/systemd/system/aanbiedingspan-backup.timer`:

```ini
[Unit]
Description=Dagelijkse back-up van Aanbiedingspan

[Timer]
OnCalendar=*-*-* 03:15:00
Persistent=true
RandomizedDelaySec=10m

[Install]
WantedBy=timers.target
```

Activeer en controleer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now aanbiedingspan-backup.timer
systemctl list-timers aanbiedingspan-backup.timer
```

### 11.5 Herstel echt testen

Download de nieuwste `.age`-bestanden uit HiDrive naar een tijdelijke map op je Mac en ontsleutel ze:

```bash
age -d -i ~/.config/age/aanbiedingspan-backup-key.txt -o database.dump database.dump.age
age -d -i ~/.config/age/aanbiedingspan-backup-key.txt -o uploads.tar.gz uploads.tar.gz.age
tar -tzf uploads.tar.gz | head
file database.dump
```

`tar` moet bestanden kunnen tonen en `file` moet een PostgreSQL custom database dump herkennen. Test minimaal ieder kwartaal een volledig herstel naar een lege testdatabase.

## 12. STRATO-monitoring activeren

Open bij je server het monitoringgedeelte. Heb je het STRATO Cloud Panel, ga dan
naar **Veiligheid → Monitoringbeleid → Aanmaken**:

1. noem het beleid `Aanbiedingspan productie`;
2. stel je eigen bewaakte e-mailadres in voor waarschuwingen;
3. laat minimaal TCP-poort 443 controleren en waarschuw als die onbereikbaar is;
4. kies monitoring met agent als STRATO dit voor jouw VPS aanbiedt, zodat ook vrije
   schijfruimte en processen kunnen worden gecontroleerd;
5. stel een kritieke waarschuwing in bij minder dan 15% vrije schijfruimte;
6. wijs het beleid aan de Aanbiedingspan-VPS toe;
7. controleer dat het beleid actief is en een testmelding aankomt, als die functie
   beschikbaar is.

Nieuwe VC-VPS'en kunnen een eenvoudiger monitoringsscherm hebben. Activeer daar de
beschikbaarheids- en resourcemeldingen met dezelfde grenzen. STRATO controleert dan
de server en poort; `/health/ready` blijft je inhoudelijke controle dat ook de
database werkt.

Controleer bovendien iedere week in één minuut:

```bash
curl --fail https://aanbiedingspan.nl/health/ready
ssh -i ~/.ssh/aanbiedingspan_strato deploy@<SERVER_IP> \
  'df -h; systemctl list-timers aanbiedingspan-backup.timer'
```

## 13. Laatste controle vóór bekendmaking

Ga deze lijst één voor één af:

- [ ] Homepage, recepten, zoeken en receptdetails werken op mobiel en desktop.
- [ ] Ingrediënten zijn met muis én toetsenbord te kiezen.
- [ ] Het beheerpaneel is alleen via HTTPS bereikbaar en inloggen/uitloggen werkt.
- [ ] Onder **Beheer → Contactgegevens** staat het echte openbare e-mailadres.
- [ ] Op Over Aanbiedingspan staan Jimmaphy Media en de AI-toelichting correct.
- [ ] Op de privacypagina staan de juiste juridische naam en het juiste privacy-e-mailadres; nergens staat voorbeeldtekst of een placeholder.
- [ ] Alle afbeeldingen en teksten mogen worden gepubliceerd, inclusief de RealGoodAI-afbeelding.
- [ ] Affiliate- of commerciële relaties zijn duidelijk uitgelegd als die bestaan.
- [ ] `/health/live` en `/health/ready` geven succes.
- [ ] Het STRATO-certificaat is geldig voor `aanbiedingspan.nl` én `www.aanbiedingspan.nl`; de vernieuwingsherinneringen staan in de agenda.
- [ ] Alleen poorten 22, 80 en 443 zijn extern geopend.
- [ ] De database heeft geen openbare poort.
- [ ] Een handmatige back-up staat versleuteld in HiDrive.
- [ ] Je hebt die back-up op een ander apparaat kunnen ontsleutelen en inspecteren.
- [ ] STRATO en HiDrive hebben unieke wachtwoorden en waar mogelijk tweestapsverificatie.

Zolang één punt rood is, is de site technisch bereikbaar maar nog niet correct gepubliceerd.

## 14. Een volgende versie publiceren

Voer eerst lokaal uit:

```bash
cd /Users/wesley/Source/Jimmaphy/Aanbiedingspan
swift test
git status --short
git log -1 --oneline
```

Maak een commit en push die naar GitHub. Maak daarna op de server een verse back-up:

```bash
sudo /usr/local/sbin/aanbiedingspan-backup
```

Synchroniseer vanaf je Mac. Controleer vóór Enter zeer precies dat het doel `/opt/aanbiedingspan/` is:

```bash
rsync -az --delete \
  --exclude '.git/' \
  --exclude '.build/' \
  --exclude '.env' \
  --exclude '.env.*' \
  ./ deploy@<SERVER_IP>:/opt/aanbiedingspan/
```

`--delete` verwijdert daar oude codebestanden; `.env.production` blijft door de uitsluiting behouden. Bouw en publiceer vervolgens op de VPS:

```bash
cd /opt/aanbiedingspan
sudo docker compose --env-file .env.production -f compose.production.yml build app
sudo docker compose --env-file .env.production -f compose.production.yml run --rm app migrate --env production -y
sudo docker compose --env-file .env.production -f compose.production.yml up -d app proxy
sudo docker compose --env-file .env.production -f compose.production.yml ps
curl --fail https://aanbiedingspan.nl/health/ready
```

Doe daarna een rooktest: homepage, zoeken, recept openen, beheerlogin, één wijziging opslaan en afbeelding tonen.

## 15. Storingen en terugdraaien

Bekijk eerst status en logs:

```bash
cd /opt/aanbiedingspan
sudo docker compose --env-file .env.production -f compose.production.yml ps
sudo docker compose --env-file .env.production -f compose.production.yml logs --tail=200 app database proxy
```

Veelvoorkomende oorzaken:

- `database` niet healthy: controleer databasevariabelen en schijfruimte;
- Caddy start niet: controleer of de certificaatbestanden bestaan, leesbaar zijn,
  bij elkaar horen en een volledige certificaatketen bevatten;
- `ready` faalt: app bereikt de database niet of een migratie ontbreekt;
- afbeelding ontbreekt: controleer `recipe-uploads` en de back-up;
- beheerlogin is na een herstart weg: bestaande geheugensessies verdwijnen; log opnieuw in.

Wil je code terugzetten, zet dan lokaal de vorige bekende goede Git-commit op een tijdelijke branch, synchroniseer die en bouw opnieuw. Draai een productiemigratie niet blind terug: herstel bij een incompatibele migratie de databaseback-up of maak een voorwaartse reparatiemigratie.

Bij een ernstig incident stop je publiek verkeer zonder data te verwijderen:

```bash
sudo docker compose --env-file .env.production -f compose.production.yml stop proxy
```

Start later weer met `start proxy`. Gebruik **nooit** `docker compose down -v`: `-v` verwijdert database en uploads.

## 16. Maandelijks onderhoud

Maak vóór upgrades een back-up en voer uit:

```bash
sudo apt update
sudo apt full-upgrade -y
cd /opt/aanbiedingspan
sudo docker compose --env-file .env.production -f compose.production.yml pull database proxy
sudo docker compose --env-file .env.production -f compose.production.yml up -d database proxy
sudo docker image prune
df -h
sudo systemctl status aanbiedingspan-backup.timer
```

Controleer na een reboot de homepage, `/health/ready`, beheerlogin en back-uptimer.
Controleer maandelijks of een recente externe back-up werkelijk te ontsleutelen is
en hoeveel dagen het actieve certificaat nog geldig is:

```bash
echo | openssl s_client -connect aanbiedingspan.nl:443 \
  -servername aanbiedingspan.nl 2>/dev/null \
  | openssl x509 -noout -enddate
```

## Officiële naslag

- [STRATO: eerste stappen met een server](https://www.strato.nl/faq/server/eerste-stappen-met-je-strato-server/)
- [STRATO: firewall van een VPS](https://www.strato.nl/faq/server/de-firewall-van-je-strato-vps/)
- [STRATO: DNS-items configureren](https://www.strato.nl/faq/domeinnaam/welke-dns-items-kun-je-bij-STRATO-configureren/)
- [STRATO: een SSL-certificaat op een eigen server gebruiken](https://www.strato.nl/faq/domeinnaam/zo-gebruik-je-strato-ssl/)
- [Sectigo: CSR maken met Apache/OpenSSL](https://help.sectigostore.com/support/solutions/articles/22000218709--apache-openssl)
- [STRATO: VPS-back-up is eigen verantwoordelijkheid](https://www.strato.nl/faq/server/welke-backup-service-is-er-voor-linux-vpsen/)
- [STRATO: HiDrive met rsync en SSH-sleutels](https://www.strato.nl/faq/cloud-storage/hidrive-met-rsync-gebruiken/)
- [STRATO: monitoringbeleid instellen](https://www.strato.nl/faq/server/wat-is-monitoring-en-hoe-stel-ik-het-in/)
- [Docker: installeren op Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [Caddy: een eigen certificaat en sleutel configureren](https://caddyserver.com/docs/caddyfile/directives/tls)
- [Swift: officiële Docker-images](https://www.swift.org/install/linux/docker/)
- [Vapor: productieomgeving](https://docs.vapor.codes/basics/environment/)
- [Vapor: migraties](https://docs.vapor.codes/fluent/migration/)

Deze stappen zijn opgesteld voor de STRATO- en softwaremogelijkheden van augustus 2026. Controleer bij een veel latere publicatie de gekoppelde documentatie op gewijzigde schermnamen en ondersteunde versies.
