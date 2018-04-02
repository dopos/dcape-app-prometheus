#!/bin/bash

# Taken from https://github.com/grafana/grafana-docker/issues/74

# Script to configure grafana datasources and dashboards.
# Intended to be run before grafana entrypoint...
# Image: grafana/grafana:4.1.2
# ENTRYPOINT [\"/run.sh\"]"

GRAFANA_URL=${GRAFANA_URL:-http://$GF_SECURITY_ADMIN_USER:$GF_SECURITY_ADMIN_PASSWORD@localhost:3000}
#GRAFANA_URL=http://grafana-plain.k8s.playground1.aws.ad.zopa.com
DATASOURCES_PATH=${DATASOURCES_PATH:-/etc/grafana/datasources}
DASHBOARDS_PATH=${DASHBOARDS_PATH:-/etc/grafana/dashboards}


# Generic function to call the Vault API
grafana_api() {
  local verb=$1
  local url=$2
  local params=$3
  local bodyfile=$4
  local response
  local cmd

  cmd="curl -L -s --fail -H \"Accept: application/json\" -H \"Content-Type: application/json\" -X ${verb} -k ${GRAFANA_URL}${url}"
  [[ -n "${params}" ]] && cmd="${cmd} -d \"${params}\""
  [[ -n "${bodyfile}" ]] && cmd="${cmd} -d '${bodyfile}'"
  echo "Running ${cmd}"
  eval ${cmd} || return 1
  return 0
}

wait_for_api() {
  while ! grafana_api GET /api/user/preferences
  do
    sleep 5
  done
}


install_datasources() {
  local datasource

  for datasource in ${DATASOURCES_PATH}/*.json
  do
    if [[ -f "${datasource}" ]]; then
      echo "Installing datasource ${datasource}"
      if grafana_api POST /api/datasources "" "${datasource}"; then
        echo "installed ok"
      else
        echo "install failed"
      fi
    fi
  done
}

install_dashboards() {
  local dashboard

  for dashboard in ${DASHBOARDS_PATH}/*.json
  do
    if [[ -f "${dashboard}" ]]; then
      echo "Installing dashboard ${dashboard}"

      echo "{\"dashboard\": `cat $dashboard`}" > "${dashboard}.wrapped"

      if grafana_api POST /api/dashboards/db "" "${dashboard}.wrapped"; then
        echo "installed ok"
      else
        echo "install failed"
      fi

      rm "${dashboard}.wrapped"
    fi
  done
}

add_user() {
  echo "add user account"
  if grafana_api POST /api/admin/users "" '{"name":"'$GRAFANA_USER'", "email":"'$GRAFANA_USER_EMAIL'", "login":"'$GRAFANA_USER'", "password":"'$GRAFANA_USER_PASSWORD'"}'; then
    echo "User add ok"
  else
    echo "User add failed"
  fi
}


configure_grafana() {
  sleep 3
  wait_for_api
  add_user
#  install_datasources
#  install_dashboards
#  cp -Rf /var/lib/dashboards/dash_list.yml /etc/grafana/provisioning/dashboards
#  cp -Rf /var/lib/datasources/datasources_list.yml /etc/grafana/provisioning/datasources
#  cp -Rf /var/lib/dashboards /var/lib/grafana/
echo "configure_grafana"
}


echo "Running configure_grafana in the background..."
configure_grafana &
/run.sh
exit 0
