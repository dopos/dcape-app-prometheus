# dcape-app-prometheus Makefile

SHELL               = /bin/bash
CFG                ?= .env

# Database name for use with postgres_exporter
DB_NAME            ?= postgres_exporter
# Database user name
DB_USER            ?= $(DB_NAME)
# Database user password
DB_PASS            ?= $(shell < /dev/urandom tr -dc A-Za-z0-9 | head -c14; echo)
# Database dump for import on create
DB_SOURCE          ?=

# Site host
APP_SITE           ?= prom5s.iac.tender.pro
# site for Grafana
DASH_SITE					 ?= dash.$(APP_SITE)

# Docker images name & images tag (version)
IMAGE_PROM5S             ?= prom/prometheus
IMAGE_VER_PROM5S         ?= v2.2.1

IMAGE_ALERT_MANAGER      ?= prom/alertmanager
IMAGE_VER_ALERT_MANAGER  ?= v0.14.0

IMAGE_NODE_EXPORT        ?= prom/node-exporter
IMAGE_VER_NODE_EXPORT    ?= v0.15.2

IMAGE_CADVISOR           ?= google/cadvisor
IMAGE_VER_CADVISOR       ?= v0.29.0

IMAGE_GRAFANA            ?= grafana/grafana
IMAGE_VER_GRAFANA        ?= 5.0.0

IMAGE_PGSQL_EXPORT			 ?= wrouesnel/postgres_exporter
IMAGE_VER_PGSQL_EXPORT   ?= v0.4.4

# Docker image name & image tag (version)
#IMAGE_CADDY              ?= stefanprodan/caddy
#IMAGE_VER_CADDY          ?= 0.10.10

# Docker-compose project name (container name prefix)
PROJECT_NAME       ?= prom5s
# dcape container name prefix
DCAPE_PROJECT_NAME ?= dcape
# dcape network attach to
DCAPE_NET          ?= $(DCAPE_PROJECT_NAME)_default
# dcape postgresql container name
DCAPE_DB           ?= $(DCAPE_PROJECT_NAME)_db_1

# AUTHORIZATION for Prometheus via traefik - admin account
AUTH_PROMETHEUS_ADMIN  ?= admin:$apr1$wDsZIjJq$mS86gqB1k4G9I8.x599ai.

#Grafana AUTHORIZATION
GRAFANA_USER           ?= user
GRAFANA_USER_PASSWORD  ?=
GRAFANA_ADMIN_PASSWORD ?=

# Alert manager configuration
# List emails address for sending alerts - list with "," separator
EMAIL_ADRESS_FOR_SEND_ALERT ?=zan@whiteants.net
HOSTNAME_SMTP_SERVER        ?=mail.tender.pro
SMTP_PORT                   ?=25
USERNAME_SMTP_ALERT         ?=
PASSWORD_SMTP_ALERT         ?=

# Docker-compose image tag
DC_VER             ?= 1.14.0

define CONFIG_DEF
# ------------------------------------------------------------------------------
# Prom5s settings

# Site host
APP_SITE=$(APP_SITE)
# site for Grafana
DASH_SITE=$(DASH_SITE)

# Database user name for postgres_exporter
DB_USER=$(DB_USER)
# Database user password
DB_PASS=$(DB_PASS)

# Docker details
# Docker image name & image tag (version)
IMAGE_PROM5S=$(IMAGE_PROM5S)
IMAGE_VER_PROM5S=$(IMAGE_VER_PROM5S)

IMAGE_ALERT_MANAGER=$(IMAGE_ALERT_MANAGER)
IMAGE_VER_ALERT_MANAGER=$(IMAGE_VER_ALERT_MANAGER)

IMAGE_NODE_EXPORT=$(IMAGE_NODE_EXPORT)
IMAGE_VER_NODE_EXPORT=$(IMAGE_VER_NODE_EXPORT)

IMAGE_CADVISOR=$(IMAGE_CADVISOR)
IMAGE_VER_CADVISOR=$(IMAGE_VER_CADVISOR)

IMAGE_GRAFANA=$(IMAGE_GRAFANA)
IMAGE_VER_GRAFANA=$(IMAGE_VER_GRAFANA)

IMAGE_PGSQL_EXPORT=$(IMAGE_PGSQL_EXPORT)
IMAGE_VER_PGSQL_EXPORT=$(IMAGE_VER_PGSQL_EXPORT)

# Docker-compose project name (container name prefix)
PROJECT_NAME=$(PROJECT_NAME)
# dcape network attach to
DCAPE_NET=$(DCAPE_NET)
# dcape postgresql container name
DCAPE_DB=$(DCAPE_DB)

# AUTHORIZATION for Prometheus via traefik - admin account
AUTH_PROMETHEUS_ADMIN=$(AUTH_PROMETHEUS_ADMIN)

#Grafana AUTHORIZATION
GRAFANA_USER=$(GRAFANA_USER)
GRAFANA_USER_PASSWORD=$(GRAFANA_USER_PASSWORD)
GRAFANA_ADMIN_PASSWORD=$(GRAFANA_ADMIN_PASSWORD)

# Alert manager configuration
EMAIL_ADRESS_FOR_SEND_ALERT=$(EMAIL_ADRESS_FOR_SEND_ALERT)
HOSTNAME_SMTP_SERVER=$(HOSTNAME_SMTP_SERVER)
SMTP_PORT=$(SMTP_PORT)
USERNAME_SMTP_ALERT=$(USERNAME_SMTP_ALERT)
PASSWORD_SMTP_ALERT=$(PASSWORD_SMTP_ALERT)

endef
export CONFIG_DEF

-include $(CFG)
export

.PHONY: all $(CFG) start start-hook stop update up reup down docker-wait db-create db-drop psql dc help

all: help

# ------------------------------------------------------------------------------
# webhook commands

# webhook always run new docker image?  Webhook don't use for simple up service?

start: db-create-instances up

start-hook: db-create-instances reup

stop: down db-drop-instances

update: reup


# ------------------------------------------------------------------------------
# docker commands

## старт контейнеров
up:
up: CMD=up -d
up: init_alert dc

## рестарт контейнеров
reup:
reup: CMD=up --force-recreate -d
reup: init_alert dc

## остановка и удаление всех контейнеров и томов 
down:
down: CMD=down -v
down: dc

# create config file with smtp environment for alertmanageer
init_alert:
	@echo "global:" > alertmanager/config.yml
	@echo "  smtp_smarthost: '$$HOSTNAME_SMTP_SERVER:$$SMTP_PORT'" >> alertmanager/config.yml
	@echo "  smtp_hello: '$$APP_SITE'" >> alertmanager/config.yml
	@echo "  smtp_from: `sed -n '/USERNAME_SMTP_ALERT/p' .env | cut -c 21-`" >> alertmanager/config.yml
	@echo "  smtp_auth_username: `sed -n '/USERNAME_SMTP_ALERT/p' .env | cut -c 21-`" >> alertmanager/config.yml
	@echo "  smtp_auth_password: `sed -n '/PASSWORD_SMTP_ALERT/p' .env | cut -c 21-`" >> alertmanager/config.yml
	@echo " " >> alertmanager/config.yml
	@echo "route:" >> alertmanager/config.yml
	@echo "  receiver: default-receiver" >> alertmanager/config.yml
	@echo "receivers:" >> alertmanager/config.yml
	@echo "  - name: 'default-receiver'" >> alertmanager/config.yml
	@echo "    email_configs:" >> alertmanager/config.yml
	@echo "    - to: '$$EMAIL_ADRESS_FOR_SEND_ALERT'" >> alertmanager/config.yml
	@echo "      require_tls: false" >> alertmanager/config.yml


# Wait for postgresql container start
docker-wait:
	@echo -n "Checking PG is ready..."
	@until [[ `docker inspect -f "{{.State.Health.Status}}" $$DCAPE_DB` == healthy ]] ; do sleep 1 ; echo -n "." ; done
	@echo "Ok"

# ------------------------------------------------------------------------------
# DB operations

# create user, db and shema for non-superuser runing postgres_exporter
db-create-instances: docker-wait
	@check_dbname_exist=`docker exec -i $$DCAPE_DB psql -U postgres -l | grep -m 1 -w $$DB_NAME` ; \
	if [[ $$check_dbname_exist ]] ; then \
		echo "DB with name="$$DB_NAME"already exist on: "$$DCAPE_DB" server. Starting existing postgres_exporter" ; \
	else \
		echo "DB with name="$$DB_NAME" don't exist on: "$$DCAPE_DB" server. Create DB, VIEW and SCHEMA for postgres_exporter" ; \
		echo "*** $@ ***" ; \
		docker exec -i $$DCAPE_DB psql -U postgres -c "CREATE USER \"$$DB_USER\" WITH PASSWORD '$$DB_PASS';" || true ; \
		docker exec -i $$DCAPE_DB psql -U postgres -c "CREATE DATABASE \"$$DB_NAME\" OWNER \"$$DB_USER\";" || true ; \
		docker exec -i $$DCAPE_DB psql -U postgres -c "ALTER USER \"$$DB_USER\" SET SEARCH_PATH TO '$$DB_USER',pg_catalog;" || true ; \
		docker exec -i $$DCAPE_DB psql -U postgres -c "CREATE SCHEMA \"$$DB_USER\" AUTHORIZATION postgres_exporter;" || true ; \
		docker exec -i $$DCAPE_DB psql -U postgres -c "CREATE VIEW postgres_exporter.pg_stat_activity AS SELECT * from pg_catalog.pg_stat_activity;" || true ; \
		docker exec -i $$DCAPE_DB psql -U postgres -c "GRANT SELECT ON postgres_exporter.pg_stat_activity TO postgres_exporter;" || true ; \
		docker exec -i $$DCAPE_DB psql -U postgres -c "CREATE VIEW postgres_exporter.pg_stat_replication AS SELECT * from pg_catalog.pg_stat_replication;" || true ; \
		docker exec -i $$DCAPE_DB psql -U postgres -c "GRANT SELECT ON postgres_exporter.pg_stat_replication TO postgres_exporter;" || true ; \
	fi

## drop database and user
db-drop-instances: docker-wait
	@echo "*** $@ ***"
	@docker exec -i $$DCAPE_DB psql -U postgres -c "DROP VIEW postgres_exporter.pg_stat_replication CASCADE;" || true
	@docker exec -i $$DCAPE_DB psql -U postgres -c "DROP VIEW postgres_exporter.pg_stat_activity CASCADE;" || true
	@docker exec -i $$DCAPE_DB psql -U postgres -c "DROP SCHEMA postgres_exporter CASCADE;" || true
	@docker exec -i $$DCAPE_DB psql -U postgres -c "DROP DATABASE $$DB_NAME;" || true
	@docker exec -i $$DCAPE_DB psql -U postgres -c "DROP USER \"$$DB_USER\";" || true

# ------------------------------------------------------------------------------

# $$PWD используется для того, чтобы текущий каталог был доступен в контейнере по тому же пути
# и относительные тома новых контейнеров могли его использовать
## run docker-compose
dc: docker-compose.yml
	@docker run --rm  \
	  -v /var/run/docker.sock:/var/run/docker.sock \
	  -v $$PWD:$$PWD \
	  -w $$PWD \
	  docker/compose:$(DC_VER) \
	  -p $$PROJECT_NAME \
	  $(CMD)  \

# ------------------------------------------------------------------------------

$(CFG):
	@[ -f $@ ] || { echo "$$CONFIG_DEF" > $@ ; echo "Warning: Created default $@" ; }

# ------------------------------------------------------------------------------

## List Makefile targets
help:
	@grep -A 1 "^##" Makefile | less

##
## Press 'q' for exit
##
