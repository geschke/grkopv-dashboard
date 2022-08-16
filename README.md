# grkopv-dashboard (Grafana Kostal Photovoltaic Dashboard)

This repository contains the documentation and all files necessary to build a Grafana dashboard for Kostal Plenticore inverters using the invafetch and invaps tools running in a Docker environment.

## Prerequisites

A running Docker installation on a Linux system is required. In addition, Prometheus and Grafana should already be installed and set up. If not, examples of Docker compose files for Prometheus and Grafana can be found below, but a detailed explanation is omitted.

## Overview and first steps

To get started, the repository must first be downloaded and some parameters adjusted. All steps are commented below and shown in the example.

```text
$ git clone https://github.com/geschke/grkopv-dashboard
$ cd grkopv-dashboard
```

The downloaded directory contains the following content:

* *Solar_Inverter_Dashboard-XXXXXXXXXXXX.json*: Definition file of the Grafana dashboard. This file can simply be imported into Grafana under "Dashboards" -> "Import". Afterwards, it is available in Grafana under the name "Solar Inverter Dashboard".

* *kopv-dashboard.yml*: Docker compose file for the invafetch and invaps components and the MariaDB database. This file needs to be customized, see [Docker-Compose-File](#docker-compose-file) for more information.

* *invafetch/*: This directory contains the file processdata.json, which is needed to start invafetch. It contains the definitions of the modules and their processdata IDs, which invafetch should fetch and save from the Kostal inverter. By default all processdata values are saved, except for the modules scb:export and scb:update. If not all values are to be read and saved, individual processdata IDs, but also complete module IDs can be removed from the processdata.json file.

* *sql/*: This contains the definition of the solardata table, which is necessary for operation. When first started using docker compose, MariaDB creates the database defined in the docker compose file and imports the contents of this directory. No customization is necessary within the solardata.sql file.

## Docker-Compose-File

The following Docker compose file defines the services for collecting and storing the inverter's Processdata values and providing the metrics to Prometheus.

```yaml
version: '3.7'
services:
  mariadb:
    image: mariadb:10.8
    restart: always
    volumes:
      - ./mariadb_solar/data:/var/lib/mysql
      - ./sql:/docker-entrypoint-initdb.d
    #ports:
    #  - "3307:3306"
    environment:
      MARIADB_ROOT_PASSWORD: "<ROOT PASSWORD>"
      MARIADB_DATABASE: "solardb"
      MARIADB_USER: "solardbuser"
      MARIADB_PASSWORD: "<DATABASE PASSWORD>"
  invafetch:
    image: ghcr.io/geschke/invafetch:main
    restart: always
    volumes:
      - ./invafetch/processdata.json:/app/processdata.json
    environment:
      DBHOST: "mariadb"
      DBUSER: "solardbuser"
      DBNAME: "solardb"
      DBPASSWORD: "<DATABASE PASSWORD>"
      #DBPORT:"3307"
      INV_SERVER: "<INVERTER IP ADDRESS>"
      INV_PASSWORD: "<INVERTER PASSWORD>"
      #INV_SCHEME: "http"
      #TIME_REQUEST_DURATION_SECONDS:2
      #TIME_NEW_LOGIN_MINUTES:1
  invaps:
    image: ghcr.io/geschke/invaps:main
    restart: always
    environment:
      DBHOST: "mariadb"
      DBUSER: "solardbuser"
      DBNAME: "solardb"
      DBPASSWORD: "<DATABASE PASSWORD>"
      #DBPORT: 3307      
      PORT: "8080"
      GIN_MODE: "release"
    ports:
      - "8090:8080"

```

### Services configuration

For the configuration, the adjustment of some environment variables within the individual services is necessary. The variables for which placeholders (in capital letters) are used in the example file must be adapted; adaptation is optional for all other environment variables.

#### MariaDB

The official [Docker image of MariaDB](https://hub.docker.com/_/mariadb) is used for the database service named "mariadb". All data to be stored persistently is located in the ./mariadb_solar/data directory. Mapping the ./sql directory to /docker-entrypoint-initdb.d ensures that the solardata table, if not already present, is created when MariaDB starts.

MARIADB_ROOT_PASSWORD is used to set the password for the MariaDB superuser account named "root". In practice, the use of this account is hardly needed, but it is still recommended to choose a sufficiently secure password.

The entries under MARIADB_DATABASE and MARIADB_USER can be taken from the example, in which case the database name "solardb" and the database user "solardbuser" are selected. If these specifications should be changed, a change is likewise necessary with the following services invafetch and invaps. In most cases a change is not necessary, because the MariaDB instance used is a stand-alone service exclusively for the use of the tools described here. Likewise, no access from outside is required, so the MariaDB port is not shared externally, i.e., no "ports:" option is necessary.

In the variable MARIADB_PASSWORD the password for the user MARIADB_USER is defined. When MariaDB is started for the first time, the database MARIADB_DATABASE and the user MARIADB_USER are thus created with the password MARIADB_PASSWORD, whereby the user receives the appropriate rights (GRANT ALL) for the database MARIADB_DATABASE.

#### invafetch

The invafetch tool reads the Processdata values at regular intervals from the Inverter API and stores the results in JSON format in a MariaDB table. More information can be found in the [invafetch GitHub repository](https://github.com/geschke/invafetch).

First, the processdata.json file is mapped into the container so that it is available to invafetch at startup. Further configuration takes place using environment variables.

In DBHOST the hostname is configured. This can be a full hostname (FQDN), but here it is sufficient to specify the service name ("mariadb"), since Docker provides this to the containers in the service-internal network as hostname.

The environment variables DBUSER, DBNAME and DBPASSWORD contain the corresponding information from the MariaDB configuration. DBUSER corresponds to the user name from MARIADB_USER, DBNAME to the database from MARIADB_DATABASE, and DBPASSWORD to the password defined in MARIADB_PASSWORD.

The specification of DBPORT is not necessary, since here the default port 3306 is selected. Again, access is only in the Docker service internal network.

In the variables INV_SERVER, INV_PASSWORD and INV_SCHEME the access to the inverter is configured. It is not necessary to specify the user, since the fixed username of the plant operator is automatically used.

Under INV_SERVER the host name or the IP address of the inverter (without "http://" or "https://") is entered (example: "192.168.0.100"). The inverter must be on the same network or accessible to the server running Docker services.

The password of the system operator must be entered in INV_PASSWORD. This can be changed in the web UI of the inverter.

The INV_SCHEME specification is optional and can only contain the values "http" or "https", with unencrypted access via http being used as the default.

In TIME_REQUEST_DURATION_SECONDS the time span between two requests to the inverter is defined. Invafetch thus fetches the process data values from the inverter at intervals of TIME_REQUEST_DURATION_SECONDS seconds and stores them in the MariaDB database. The default setting of TIME_REQUEST_DURATION_SECONDS is three (3) seconds. The lower the time span, the more accurate the later evaluation can be. The value of three seconds has proven itself in practice, but a too low or too high value is not recommended, because on the one hand the components should not be overloaded, on the other hand a too high resolution leads to less accurate metrics.

The variable TIME_NEW_LOGIN_MINUTES specifies after how many minutes a new session should be established towards the inverter and the database. The default value here is ten (10) minutes. Since invafetch is based on the (undocumented) REST API of the Kostal inverter, it is hardly possible to make a recommendation here. In practice, the specification of ten minutes has proven to be stable and functional.

#### invaps

The invaps tool reads the inverter's Processdata values from the MariaDB database and makes them available in a format suitable for Prometheus. More information about invaps can be found in the [invaps GitHub repository](https://github.com/geschke/invaps).

For the database configuration variables, the same notes apply as for invafetch. These specifications can simply be taken over.

By means of PORT it is specified under which port the server is made available for the metrics of invaps. The specification is optional, by default the port 8080 is set. Since invaps is started as a Docker container, the port must be shared externally with the "ports:" definition, and a different port can also be selected that differs from the internal port. In the example, the external port 8090 is mapped to the internal port 8080 so that the inverter metrics are made available at the URL http://[server][:8090]/metrics.

Invaps relies on the [Gin](https://gin-gonic.com/) HTTP web framework. Gin uses the GIN_MODE environment variable to set up debug mode, which contains additional output not required for operation. If GIN_MODE is not set, debug mode is enabled; for operation and to disable debug mode, set GIN_MODE=release.

### Operating

Services are started using docker compose for newer Docker versions or the standalone binary docker-compose for older variants:

```bash
$ docker compose -f kopv-dashboard.yml up -d
```

Zum Beenden aller Services wird ebenfalls docker compose (bzw. docker-compose) verwendet:

```bash
$ docker compose -f kopv-dashboard.yml down
```

## Prometheus

The following Docker compose file shows an example of one way to get Prometheus running using Docker:

```yaml
version: '3.2'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - 9090:9090
    command:
      - --config.file=/etc/prometheus/prometheus.yml
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./data:/prometheus

```

Prometheus is then available under port 9090 on the corresponding server.

The configuration of Prometheus is mapped in the file prometheus.yml, the following excerpt shows this for the job called "solardata", where the server is queried every 20 seconds, which returns the metrics of the inverter:

```yaml
scrape_configs:
[...]
  - job_name: solardata
    scrape_interval: 20s
    static_configs:
    - targets:
      - metrics.example.com:8090
[...]
```

Prometheus provides a web UI that can be used, among other things, to query the status of the jobs defined in this way. Under "Status" -> "Targets" you can find a list of the so-called endpoints that the Prometheus server queries. The current status, the labels, the time of the last query and its duration are also displayed.
For further information please refer to the [Prometheus documentation](https://prometheus.io/docs/introduction/overview/).

## Grafana

Grafana can also be run as a Docker container, below is a corresponding Docker compose file for it:

```yaml
version: '3.8'
services:
  grafana:
    image: grafana/grafana-oss:latest
    container_name: monitoring_grafana
    restart: unless-stopped
    volumes:
      - ./data:/var/lib/grafana
    user: "1000"
    environment:
      - GF_SERVER_DOMAIN=example.com
    ports:
      - "3000:3000"

```

Grafana is started on port 3000, which is shared with the outside world. Further information about the installation using Docker can be found in the [Grafana documentation](https://grafana.com/docs/grafana/next/setup-grafana/installation/docker/).
