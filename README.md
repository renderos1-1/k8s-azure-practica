# DevOps · K3s en Azure

Repositorio base de la Práctica 5. Reutiliza la API Express y PostgreSQL del ejemplo local e incorpora publicación de imágenes mediante GitHub Actions, aprovisionamiento de infraestructura con Terraform e instalación automática de K3s en una máquina virtual de Azure.

La guía académica y el instrumento de evaluación se proporcionarán por separado. Este README describe el proyecto, sus requisitos y las comprobaciones operativas; no sustituye el material de clase.

## Estructura

- `app/`: API Express, Dockerfile y pruebas automatizadas.
- `.github/workflows/publish-image.yml`: pruebas y construcción; publicación en GHCR inicialmente desactivada.
- `azure/terraform/`: grupo de recursos, red, NSG, IP, VM y `cloud-init` para K3s.
- `k8s/`: namespace `devops-demo`, ConfigMap, PVC, PostgreSQL, Services, Deployment de la API e Ingress Traefik.

## Actividades que se dejan deliberadamente sin completar

1. Activar la publicación en GHCR cambiando `push: false` por `push: true` en el workflow y ejecutarlo desde GitHub Actions.
2. Agregar el output `resource_group_name` en `azure/terraform/outputs.tf`.
3. Sustituir el marcador de `image:` en `k8s/06-api-deployment.yaml` por la imagen GHCR del repositorio propio, utilizando el tag `sha-<SHA_DEL_COMMIT>`.
4. Desplegar los recursos y verificar los endpoints HTTP y la persistencia de notas después de recrear el Pod de PostgreSQL.

Se debe crear un repositorio propio a partir de este **template**. El paquete GHCR puede ser público aunque el repositorio sea privado; debe verificarse explícitamente la visibilidad del **paquete**, no solo la del repositorio. No incorporar al template la imagen específica usada para validarlo.

## Requisitos y preparación local

Se requiere Git, Terraform, Azure CLI y OpenSSH. El procedimiento local debe funcionar en Windows PowerShell y Linux. No exige ejecutar scripts Bash complejos en Windows: `cloud-init` ejecuta su script **dentro de la VM Ubuntu**.

Se necesita una suscripción Azure con permisos de despliegue, una clave SSH pública existente y la IPv4 pública de origen para restringir el puerto 22.

En `azure/terraform/`, copiar `terraform.tfvars.example` a `terraform.tfvars` y configurar `subscription_id` y `ssh_source_cidr`. El archivo real contiene parámetros específicos del estudiante y **no debe versionarse**.

La configuración inicial procede de una validación exitosa con Azure for Students (noviembre de 2026):

| Parámetro | Valor |
| --- | --- |
| Región | `mexicocentral` |
| Tamaño VM | `Standard_B2s_v2` |
| Zona VM | `1` |
| Provider AzureRM | `4.40.0` (versión fijada) |
| K3s | `v1.35.2+k3s1` |
| Ubuntu | 24.04 LTS |
| Namespace Kubernetes | `devops-demo` |

La disponibilidad de la región y la capacidad de VM **no están garantizadas** para otras suscripciones. La suscripción usada en la validación restringía algunos SKU en la zona 2, y otros intentos fallaron por capacidad o políticas de región. El listado de SKU y las cuotas tampoco garantizan capacidad física al crear la VM. Antes de desplegar, confirmar los permisos, cuotas y restricciones regionales de la suscripción.

Puede comprobarse la suscripción activa con `az account show`, las cuotas con `az vm list-usage --location mexicocentral -o table` y los SKU con `az vm list-skus --location mexicocentral --resource-type virtualMachines -o table`.

## Flujo de trabajo y verificaciones

### 1. Imagen de la aplicación

En el repositorio propio, activar el `push` del workflow y ejecutarlo manualmente. Verificar que las pruebas y la publicación finalicen y localizar la imagen `ghcr.io/<usuario>/<repositorio>:sha-<commit>`. Ajustar la visibilidad del paquete GHCR a **Public** para permitir que el clúster descargue la imagen sin `imagePullSecrets`. Si el paquete es privado, esta configuración requiere autenticación adicional que no forma parte del recorrido principal.

### 2. Infraestructura con Terraform

Trabajar en `azure/terraform/`:

```text
terraform init
terraform validate
terraform plan
terraform apply
terraform output public_ip
terraform output ssh_command
```

Antes de ejecutar `apply`, revisar que solo se crean recursos de la práctica. En la validación inicial se crearon ocho recursos. El comando `terraform apply` puede finalizar antes de que `cloud-init` termine de instalar K3s.

Conectarse a la VM mediante el comando SSH obtenido de Terraform. Ya dentro de **Ubuntu**:

```bash
sudo cloud-init status --wait
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -A
```

Verificar el nodo `Ready` y los componentes `coredns`, `local-path-provisioner` y `traefik` en ejecución. Los trabajos Helm de instalación pueden aparecer como `Completed`.

### 3. Manifiestos editados localmente y Secret

**Editar `k8s/06-api-deployment.yaml` en el equipo local y dentro del repositorio Git**, no con `nano` en la VM. Conservar `imagePullPolicy: IfNotPresent` y sustituir el marcador por la imagen publicada por cada estudiante. Comprobar el cambio localmente y versionarlo según las indicaciones de la guía.

Desde la raíz del repositorio, transferir el directorio completo a Ubuntu:

```text
scp -r k8s azureuser@IP_PUBLICA:~/
```

En PowerShell también puede utilizarse `scp -r .\k8s azureuser@IP_PUBLICA:~/`. Repetir la transferencia después de cambiar un manifiesto local.

**Crear el Secret antes de aplicar los Deployments.** Los manifiestos de PostgreSQL y de la API requieren un Secret llamado `postgres-credentials` con la clave `password`, en el namespace `devops-demo`. No incluir contraseñas en el repositorio.

Ya dentro de la VM Ubuntu:

```bash
sudo k3s kubectl apply -f ~/k8s/01-namespace.yaml
read -rsp "Contraseña de PostgreSQL: " DB_PASSWORD
echo
sudo k3s kubectl create secret generic postgres-credentials \
  --namespace devops-demo \
  --from-literal="password=$DB_PASSWORD"
unset DB_PASSWORD
sudo k3s kubectl apply -f ~/k8s/
```

La contraseña se introduce sin mostrarla durante la lectura. No utilizar `kubectl get secret -o yaml` como evidencia pública ni registrar sus valores. El Secret de Kubernetes no equivale por sí mismo a un sistema de gestión de secretos con cifrado, rotación y control de acceso.

Comprobar:

```bash
sudo k3s kubectl get pods,deployments,services -n devops-demo
sudo k3s kubectl get pvc -n devops-demo
sudo k3s kubectl get ingress -n devops-demo
```

Se esperan los pods de PostgreSQL y Express en `1/1 Running`, y el PVC `postgres-data` en `Bound`. El namespace es **`devops-demo`**, no `devops`. Si un Pod presenta `CreateContainerConfigError`, revisar `kubectl describe pod` y los eventos; si presenta reinicios, revisar también `kubectl logs --previous` según corresponda.

### 4. Pruebas funcionales y persistencia

Desde la computadora local (Windows PowerShell o Linux), sustituir `IP_PUBLICA` por la dirección de Terraform:

```text
curl http://IP_PUBLICA/health
curl http://IP_PUBLICA/notes
```

Para realizar una prueba POST portable, utilizar `curl.exe` en PowerShell o `curl` en Linux, con los parámetros de JSON correspondientes a cada shell, o un cliente HTTP. La guía describirá la prueba específica.

Comprobar que la API devuelve `/health` con HTTP 200, permite crear una nota mediante `POST /notes` y la recupera con `GET /notes`.

Después, dentro de Ubuntu:

```bash
sudo k3s kubectl delete pod -n devops-demo -l app=postgres
sudo k3s kubectl rollout status deployment/postgres -n devops-demo --timeout=120s
```

Volver a consultar `GET /notes` desde la computadora local. La nota debe persistir después de recrear el Pod. La prueba valida el PVC `local-path` en este nodo, **no alta disponibilidad ni recuperación ante pérdida de la VM**.

### 5. Destrucción y verificación de costos

Desde `azure/terraform/` en el equipo local:

```text
terraform plan -destroy
terraform destroy
```

Verificar después la eliminación del grupo y de sus recursos:

```text
az group exists --name devops-k3s-rg
```

Se espera `false`. Si Terraform falla al destruir, **no asumir que todos los recursos han desaparecido**. Revisar `terraform state list`, el grupo y los recursos en Azure. Como medida excepcional, si el grupo fue creado exclusivamente para esta práctica y está confirmado que no contiene recursos ajenos:

```text
az group delete --name devops-k3s-rg --yes
```

Después, verificar nuevamente la eliminación y reconciliar cualquier referencia residual del estado local antes de un nuevo despliegue. No borrar el archivo de estado para ocultar inconsistencias.

## Limitaciones y observaciones de la validación

La validación completa consiguió publicar en GHCR, aprovisionar ocho recursos de Azure, ejecutar K3s, desplegar Express y PostgreSQL, acceder por HTTP y recuperar una nota tras recrear el Pod de PostgreSQL. **La destrucción final de ese despliegue aún debe verificarse.**

Durante la validación se observaron respuestas `404` y resultados inconsistentes al consultar recursos recién creados. En particular, la API de Azure `2025-01-01` devolvió `404` para una IP pública que la API `2024-05-01` encontraba. La versión AzureRM `4.40.0` permitió completar posteriormente el despliegue, sin que ello demuestre una solución universal para todas las suscripciones. La capacidad regional y las políticas de Azure for Students son limitaciones adicionales.

El servidor de un solo nodo y el almacenamiento local no ofrecen alta disponibilidad. El puerto 80 queda expuesto para una demostración HTTP sin TLS; no usar datos reales ni mantener el laboratorio publicado permanentemente. SSH está restringido a la IP `/32` configurada; cambiar de red de origen puede requerir actualizar ese valor mediante Terraform. Confirmar siempre la limpieza final para evitar consumo de créditos.

## Documentación

- [K3s](https://docs.k3s.io/)
- [Terraform AzureRM](https://registry.terraform.io/providers/hashicorp/azurerm/4.40.0/docs)
- [Azure cloud-init](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/using-cloud-init)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
