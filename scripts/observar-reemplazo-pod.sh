#!/usr/bin/env bash
# Observa en vivo el reemplazo del Pod de PostgreSQL y su efecto en la API.
# Se ejecuta en el equipo local; los comandos kubectl se ejecutan en la VM por SSH.
#
# Uso: ./scripts/observar-reemplazo-pod.sh [IP_PUBLICA] [SEGUNDOS_DE_OBSERVACION]
set -euo pipefail

IP="${1:-$(terraform -chdir="$(dirname "$0")/../azure/terraform" output -raw public_ip)}"
DURACION="${2:-240}"   # máximo; termina antes si la API vuelve a estar lista
NS="devops-demo"
SSH="ssh -o ConnectTimeout=10 azureuser@$IP"
K="sudo k3s kubectl -n $NS"

c_title() { printf '\n\033[1;36m=== %s ===\033[0m\n' "$*"; }
ts() { while IFS= read -r l; do printf '%s %s %s\n' "$(date +%T)" "$1" "$l"; done; }

pod_info() {
  $SSH "$K get pod -l app=postgres -o custom-columns=POD:.metadata.name,UID:.metadata.uid,IP:.status.podIP,NODO:.spec.nodeName,INICIO:.status.startTime,PVC:.spec.volumes[0].persistentVolumeClaim.claimName"
  $SSH "$K get pvc postgres-data -o custom-columns=PVC:.metadata.name,VOLUMEN:.spec.volumeName,ESTADO:.status.phase"
}

c_title "ANTES: Pod de PostgreSQL y volumen"
pod_info
c_title "Notas antes del reemplazo"
curl -sS "http://$IP/notes"; echo

c_title "Observando cambios (máx. ${DURACION}s)  ([K8S] = eventos de Pods, [HTTP] = GET /notes desde este equipo)"
# 1) Flujo de cambios de Pods (kubectl -w), con marca de tiempo local.
$SSH "timeout $DURACION $K get pods -w -o wide --no-headers" 2>/dev/null | ts "[K8S] " &
WATCH_PID=$!
# 2) Sondeo HTTP cada segundo: código de respuesta y cantidad de notas.
(
  end=$((SECONDS + DURACION))
  while (( SECONDS < end )); do
    body=$(curl -s -m 2 -w '\n%{http_code}' "http://$IP/notes" || printf '\n000')
    code=${body##*$'\n'}; json=${body%$'\n'*}
    n=$(grep -o '"id"' <<<"$json" | wc -l || true)
    echo "HTTP $code  notas=$n" | ts "[HTTP]"
    sleep 1
  done
) &
HTTP_PID=$!
trap 'kill $WATCH_PID $HTTP_PID 2>/dev/null || true' EXIT

sleep 3
echo "$(date +%T) [ACCION] Eliminando el Pod de PostgreSQL..."
$SSH "$K delete pod -l app=postgres --wait=false" | ts "[ACCION]"

# Esperar a que el nuevo Pod de PostgreSQL y la API estén listos (o a que se agote DURACION).
# Se espera sobre los Deployments: un "wait pod -l" incluiría el Pod antiguo en estado Completed.
sleep 5   # dar tiempo a que el Deployment registre la baja del Pod eliminado
$SSH "$K wait --for=condition=Available deploy/postgres deploy/demo-api --timeout=${DURACION}s >/dev/null" || true
sleep 3   # dejar que el sondeo HTTP registre la recuperación
kill $WATCH_PID $HTTP_PID 2>/dev/null || true

c_title "DESPUÉS: Pod de PostgreSQL y volumen (nombre, UID e IP nuevos; mismo PVC y volumen)"
pod_info
c_title "Estado final de los Pods"
$SSH "$K get pods -o wide"
c_title "Notas después del reemplazo"
curl -sS "http://$IP/notes"; echo
