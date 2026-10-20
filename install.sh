#!/usr/bin/env bash
# MEF initial installation. Configuration and credentials stay in ignored .local/.
set +x
set -Eeuo pipefail
umask 077
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MODE=deploy
CONFIG="$ROOT/.local/install.env"
STEP=initialization
say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
trap 'printf "\nStopped during %s. Existing resources were preserved; fix the error and rerun.\n" "$STEP" >&2' ERR
usage() {
  cat <<'HELP'
Usage: ./install.sh [--init | --check | --render] [--config FILE]
  --init    Create .local/install.env; never overwrite an existing configuration.
  --check   Validate inputs, certificate, cluster and Azure login; no remote changes.
  --render  Generate private installation files and render Helm charts; no remote changes.
  no flag   Install, or resume this installation without repeating a completed migration.
HELP
}
while (($#)); do
  case "$1" in
    --init|--check|--render) [[ $MODE == deploy ]] || die 'Choose one mode.'; MODE=${1#--} ;;
    --config) (($# >= 2)) || die '--config requires a filename.'; CONFIG=$2; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "Unknown option: $1" ;;
  esac
  shift
done
create_config() {
  mkdir -p -- "$(dirname -- "$CONFIG")"
  [[ ! -e $CONFIG ]] || return 0
  (set -o noclobber; cat > "$CONFIG" <<'CONFIGURATION'
# Fill this file, then run ./install.sh. It is Bash syntax: quote values.
# Do not commit credentials. Paths may be absolute or relative to the repository.
MEF_KUBE_CONTEXT=''          # kubectl config get-contexts -o name
MEF_DOMAIN=''                # e.g. platform.company.com (DNS/TLS must cover its subdomains)
MEF_SHARED_STORAGE_CLASS=''  # RWX-capable class, e.g. your NFS/CephFS CSI StorageClass
MEF_DB_STORAGE_CLASS=''      # StorageClass for SQL Server and PostgreSQL
MEF_TLS_CERT_FILE=''         # PEM certificate/full chain covering all application hosts
MEF_TLS_KEY_FILE=''          # Matching PEM private key (without a passphrase)
MEF_ENTRA_TENANT_ID=''       # Directory (tenant) ID from Microsoft Entra Overview
MEF_ACCEPT_SQL_EULA=''       # Set Y after accepting the SQL Server license terms
MEF_MSSQL_EDITION='Developer' # Developer is for non-production; choose your licensed edition

# create: create your own single-tenant Web App Registration using the current az login.
# existing: use a registration already prepared as described in README.md.
MEF_ENTRA_MODE='create'
MEF_ENTRA_CLIENT_ID=''       # Required only for existing mode
MEF_ENTRA_CLIENT_SECRET=''   # Secret VALUE, required only for existing mode

# Select one supplied routing profile. The default installs NGINX Gateway Fabric.
# gateway/nginx-gateway-fabric | gateway/envoy-gateway | gateway/traefik
# classic/ingress-nginx | classic/traefik | classic/haproxy
MEF_ROUTING_PROFILE='gateway/nginx-gateway-fabric'
MEF_INSTALL_CONTROLLER='true' # false to use an existing controller
MEF_ROUTING_CLASS=''          # Optional existing IngressClass/GatewayClass; empty uses profile default
MEF_INSTALL_PLANTUML='false'

# Install the manifest and ZIPs supplied in deployment-packages/.
# Azure CLI verifies this user's delegated Microsoft identity for initial MEF registration.
MEF_INSTALL_PLUGINS='true'
MEF_SETUP_EMAIL=''           # Microsoft user's mail/UPN; receives access to these plugins
MEF_ORGANIZATION_NAME=''     # Display name of the new MEF organization
# Registration PIN and emergency root password are generated in .local/installer/.
# SMTP stays disabled; configure your own mail provider later in Apps.

# Defaults below are suitable for a new installation. Existing databases use the manual guide.
MEF_NAMESPACE='mef-dev'
MEF_SHARED_ACCESS_MODE='ReadWriteMany'
MEF_NODE_NAME=''              # Required for single-node ReadWriteOnce shared storage
MEF_VERIFY_HTTPS='true'       # false leaves external HTTPS verification explicitly pending
MEF_HTTPS_CA_FILE=''          # Optional trusted private CA bundle for the final HTTPS checks
CONFIGURATION
  )
  chmod 600 -- "$CONFIG"
  printf 'Created %s\nFill its required fields, then run ./install.sh --check and ./install.sh.\n' "$CONFIG"
}
if [[ $MODE == init ]]; then
  if [[ -e $CONFIG ]]; then printf 'Configuration already exists: %s\n' "$CONFIG"; else create_config; fi
  exit 0
fi
if [[ ! -f $CONFIG ]]; then create_config; exit 2; fi
for tool in python3 helm kubectl openssl curl flock; do
  command -v "$tool" >/dev/null || die "Install required tool: $tool (see README.md)."
done
python3 -c 'import yaml' 2>/dev/null || die 'Python package PyYAML is required (Debian/Ubuntu: sudo apt install python3-yaml).'
# This is the administrator's own local Bash configuration; never source downloaded configs.
# shellcheck source=/dev/null
source "$CONFIG"
set +x
set -Eeuo pipefail
cd -- "$ROOT"
: "${MEF_NAMESPACE:=mef-dev}" "${MEF_ENTRA_MODE:=create}" "${MEF_ROUTING_PROFILE:=gateway/nginx-gateway-fabric}"
: "${MEF_INSTALL_CONTROLLER:=true}" "${MEF_ROUTING_CLASS:=}" "${MEF_INSTALL_PLANTUML:=false}"
: "${MEF_SHARED_ACCESS_MODE:=ReadWriteMany}" "${MEF_NODE_NAME:=}" "${MEF_VERIFY_HTTPS:=true}"
: "${MEF_INSTALL_PLUGINS:=true}" "${MEF_SETUP_EMAIL:=}" "${MEF_ORGANIZATION_NAME:=}"
: "${MEF_HTTPS_CA_FILE:=}" "${MEF_MSSQL_EDITION:=Developer}" "${MEF_ENTRA_CLIENT_ID:=}" "${MEF_ENTRA_CLIENT_SECRET:=}"
for name in MEF_KUBE_CONTEXT MEF_DOMAIN MEF_SHARED_STORAGE_CLASS MEF_DB_STORAGE_CLASS MEF_TLS_CERT_FILE MEF_TLS_KEY_FILE MEF_ENTRA_TENANT_ID MEF_ACCEPT_SQL_EULA; do
  export "$name=${!name-}"
done
export ROOT MEF_NAMESPACE MEF_ENTRA_MODE MEF_ROUTING_PROFILE MEF_INSTALL_CONTROLLER MEF_ROUTING_CLASS
export MEF_INSTALL_PLANTUML MEF_SHARED_ACCESS_MODE MEF_NODE_NAME MEF_VERIFY_HTTPS MEF_HTTPS_CA_FILE
export MEF_MSSQL_EDITION MEF_ENTRA_CLIENT_ID MEF_ENTRA_CLIENT_SECRET
export MEF_INSTALL_PLUGINS MEF_SETUP_EMAIL MEF_ORGANIZATION_NAME
WORK="$ROOT/.local/installer"
mkdir -p -- "$WORK"
chmod 700 -- "$ROOT/.local" "$WORK"
exec 9>"$WORK/install.lock"
flock -n 9 || die 'Another installer is using .local/installer; wait for it to finish.'
# Python handles YAML/JSON and credential-bearing API responses, avoiding shell interpolation.
helper() {
  python3 - "$@" <<'PYTHON'
import base64, copy, datetime, hashlib, http.client, json, os, re, secrets, shlex, ssl, stat, subprocess, sys, time, urllib.parse, uuid, zipfile
from pathlib import Path
import yaml
root=Path(os.environ['ROOT']); work=root/'.local/installer'; action=sys.argv[1]
e=lambda name,default='':os.environ.get('MEF_'+name,default)
def stop(message): print('ERROR: '+message,file=sys.stderr);sys.exit(2)
def save(path,obj):
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    temp=path.with_suffix(path.suffix+'.tmp')
    temp.write_text(json.dumps(obj,indent=2) if path.suffix=='.json' else yaml.safe_dump(obj,sort_keys=False))
    temp.chmod(0o600);temp.replace(path)
def read(path,default=None):return json.loads(path.read_text()) if path.exists() else (default or {})
statefile=work/'state.json';state=read(statefile)
def saved_passwords():
    path=work/'passwords.json'
    if not path.exists():
        if state.get('clusterUID'):stop('Saved database passwords are missing. Restore .local/installer from backup before continuing.')
        return None
    passwords=read(path)
    if not isinstance(passwords,dict) or any(not isinstance(passwords.get(k),str) or not passwords[k].strip() for k in ['mssql','pgvector','bootstrap']):
        stop('Saved database passwords are incomplete. Restore passwords.json from backup; passwords must not be regenerated for existing databases.')
    return passwords
profiles={'gateway/nginx-gateway-fabric':('mef-nginx','gateway.nginx.org/mef-public-controller','mef-ngf'),
          'gateway/envoy-gateway':('mef-envoy','gateway.envoyproxy.io/mef-public-controller','mef-eg'),
          'gateway/traefik':('mef-traefik','traefik.io/gateway-controller','mef-traefik'),
          'classic/ingress-nginx':('mef-ingress-nginx','k8s.io/mef-ingress-nginx','mef-ingress-nginx'),
          'classic/traefik':('traefik','traefik.io/ingress-controller',''),
          'classic/haproxy':('haproxy','haproxy.org/ingress-controller','')}
if action=='validate':
    hints={'KUBE_CONTEXT':'run kubectl config get-contexts -o name; select the target cluster explicitly',
           'DOMAIN':'base DNS domain, for example platform.company.com',
           'SHARED_STORAGE_CLASS':'StorageClass for shared front/back/api-config PVCs',
           'DB_STORAGE_CLASS':'StorageClass for the two database PVCs',
           'TLS_CERT_FILE':'path to a PEM certificate/full chain covering apps/api/knowledge-graph/servicehost subdomains',
           'TLS_KEY_FILE':'path to its matching unencrypted PEM private key',
           'ENTRA_TENANT_ID':'Directory (tenant) ID in Microsoft Entra Overview',
           'ACCEPT_SQL_EULA':'set Y after accepting the SQL Server license terms'}
    if e('ENTRA_MODE')=='existing':hints.update(ENTRA_CLIENT_ID='Application (client) ID from your Web App Registration',ENTRA_CLIENT_SECRET='client secret Value from Certificates & secrets; not the Secret ID')
    errors=[]
    for name,hint in hints.items():
        if not e(name).strip() or e(name).startswith(('REPLACE_','YOUR_','PENDING_')):errors.append('MEF_'+name+': '+hint)
    if e('INSTALL_PLUGINS')=='true':
        if not re.fullmatch(r'[^@\s]+@[^@\s]+\.[^@\s]+',e('SETUP_EMAIL')):errors.append('MEF_SETUP_EMAIL: Microsoft account mail/UPN receiving plugin access')
        if not e('ORGANIZATION_NAME').strip():errors.append('MEF_ORGANIZATION_NAME: display name of the new MEF organization')
    guid=r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}'
    for name in ['ENTRA_TENANT_ID']+(['ENTRA_CLIENT_ID'] if e('ENTRA_MODE')=='existing' else []):
        if e(name) and not re.fullmatch(guid,e(name)):errors.append('MEF_'+name+': enter a GUID copied from Entra Overview')
    if e('DOMAIN') and (not re.fullmatch(r'(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?',e('DOMAIN')) or e('DOMAIN').endswith('example.com')):errors.append('MEF_DOMAIN: use your real lowercase DNS domain without https://, ports or paths')
    if not re.fullmatch(r'[a-z0-9](?:[-a-z0-9]{0,61}[a-z0-9])?',e('NAMESPACE')):errors.append('MEF_NAMESPACE: use a Kubernetes DNS label (default mef-dev)')
    if e('ROUTING_PROFILE') not in profiles:errors.append('MEF_ROUTING_PROFILE: choose '+', '.join(profiles))
    if e('ENTRA_MODE') not in ['create','existing']:errors.append('MEF_ENTRA_MODE: choose create or existing')
    for name in ['INSTALL_CONTROLLER','INSTALL_PLANTUML','VERIFY_HTTPS','INSTALL_PLUGINS']:
        if e(name) not in ['true','false']:errors.append('MEF_'+name+': choose true or false')
    if e('SHARED_ACCESS_MODE') not in ['ReadWriteMany','ReadWriteOnce']:errors.append('MEF_SHARED_ACCESS_MODE: choose ReadWriteMany or ReadWriteOnce')
    if e('SHARED_ACCESS_MODE')=='ReadWriteOnce' and not e('NODE_NAME'):errors.append('MEF_NODE_NAME: required to keep all shared-volume consumers on one node with ReadWriteOnce')
    if e('ACCEPT_SQL_EULA') and e('ACCEPT_SQL_EULA')!='Y':errors.append('MEF_ACCEPT_SQL_EULA: must be Y to install SQL Server')
    if e('MSSQL_EDITION') not in ['Developer','Express','Standard','Enterprise','EnterpriseCore'] and not re.fullmatch(r'(?:[A-Z0-9]{5}-){4}[A-Z0-9]{5}',e('MSSQL_EDITION')):errors.append('MEF_MSSQL_EDITION: use a supported edition or your product key')
    if e('ROUTING_PROFILE') in ['classic/traefik','classic/haproxy'] and e('INSTALL_CONTROLLER')=='true':errors.append('MEF_INSTALL_CONTROLLER: set false for an existing classic Traefik/HAProxy controller, or choose a Gateway profile')
    if e('ROUTING_CLASS') and e('INSTALL_CONTROLLER')=='true':errors.append('MEF_ROUTING_CLASS: leave empty when installing a controller; custom class names are for existing controllers')
    for name in ['TLS_CERT_FILE','TLS_KEY_FILE','HTTPS_CA_FILE']:
        if e(name) and not Path(e(name)).is_file():errors.append('MEF_'+name+': file does not exist (paths are relative to repository root)')
    if errors:stop('Fill or correct these fields in your local configuration:\n  - '+'\n  - '.join(errors))
    print('Required configuration fields: OK')
elif action=='class':print(e('ROUTING_CLASS') or profiles[e('ROUTING_PROFILE')][0])
elif action=='release':print(profiles[e('ROUTING_PROFILE')][2])
elif action=='id':print(state.get('installationId',''))
elif action=='passwords-check':saved_passwords()
elif action=='passwords-init':
    passwords=saved_passwords()
    if passwords is None:save(work/'passwords.json',{name:'Mef!'+secrets.token_urlsafe(32) for name in ['mssql','pgvector','bootstrap']})
elif action=='migration-check':
    exists=any(r['name']=='db-update' for r in json.loads(sys.argv[2]))
    if state.get('migrationComplete') and not exists:stop('The completed db-update Helm release is missing. Inspect the existing database and use the manual migration procedure; automatic replay is blocked.')
    print('yes' if exists else 'no')
elif action in ['bind','target-check']:
    uid=sys.argv[2]
    if state.get('clusterUID') and (state['clusterUID']!=uid or state['namespace']!=e('NAMESPACE')):stop('Saved installer state belongs to another cluster/namespace. Use a separate repository checkout for a separate installation.')
    if state.get('domain') and state['domain']!=e('DOMAIN'):stop('Saved installation uses another domain. Change existing deployments through the manual guide, or use a separate checkout for a new installation.')
    if action=='target-check':sys.exit(0)
    state.setdefault('installationId',str(uuid.uuid4()));state.update(clusterUID=uid,namespace=e('NAMESPACE'),domain=e('DOMAIN'));save(statefile,state)
elif action=='migration-done':state['migrationComplete']=True;save(statefile,state)
elif action=='entra-verify':
    app=read(work/'entra.json') if e('ENTRA_MODE')=='create' else {'clientId':e('ENTRA_CLIENT_ID'),'clientSecret':e('ENTRA_CLIENT_SECRET')}
    connection=http.client.HTTPSConnection('login.microsoftonline.com',context=ssl.create_default_context(),timeout=60)
    body=urllib.parse.urlencode({'client_id':app['clientId'],'client_secret':app['clientSecret'],
        'grant_type':'client_credentials','scope':'https://graph.microsoft.com/.default'})
    try:
        connection.request('POST','/'+e('ENTRA_TENANT_ID')+'/oauth2/v2.0/token',body=body,headers={'Content-Type':'application/x-www-form-urlencoded'})
        response=connection.getresponse();payload=json.loads(response.read())
        if response.status!=200 or not payload.get('access_token'):
            stop('Entra rejected this App Registration credential. Check tenant/client IDs and the unexpired client secret VALUE (not Secret ID); no token or credential was printed.')
    except (OSError,ValueError,http.client.HTTPException):stop('Cannot verify the Entra credential over HTTPS. Check Microsoft connectivity and trusted system CAs.')
    finally:connection.close()
    # This token only verifies the credential; user registration uses a delegated Microsoft identity.
    print('Entra App Registration credential: OK')
elif action=='entra':
    if e('ENTRA_MODE')=='existing':sys.exit(0)
    path=work/'entra.json';app=read(path)
    def az(args,body=None):
        command=['az']+args+['--only-show-errors','--output','json']
        if body is not None:
            payload=work/'azure-request.json';save(payload,body);command+=['--body','@'+str(payload)]
        p=subprocess.run(command,capture_output=True,text=True)
        if p.returncode:stop('Azure operation failed. Check your tenant, az login and App Registration permissions; no credential output was printed.')
        return json.loads(p.stdout) if p.stdout.strip() else {}
    tenant=az(['account','show'])['tenantId']
    if tenant!=e('ENTRA_TENANT_ID'):stop('Azure CLI tenant differs from MEF_ENTRA_TENANT_ID. Run az login --tenant YOUR_TENANT_ID --allow-no-subscriptions.')
    if app and app.get('tenantId')!=tenant:stop('Saved Entra registration belongs to another tenant.')
    if app.get('clientSecret'):
        current=az(['ad','app','show','--id',app['objectId']])
        if current['appId']!=app['clientId']:stop('Saved Entra registration does not match Azure.')
        if 'https://api.'+e('DOMAIN')+'/api/v0/auth/signin-entraid' not in current.get('web',{}).get('redirectUris',[]):stop('Saved Entra callback does not match this domain; correct it in Entra before continuing.')
        if datetime.datetime.fromisoformat(app['expiresAt'])<=datetime.datetime.now(datetime.timezone.utc):stop('Saved Entra client secret has expired. Rotate it through the manual guide before continuing.')
        print('Using the saved Entra App Registration.');sys.exit(0)
    name='MEF '+e('DOMAIN')+' ['+state['installationId'][:8]+']'
    if not app:
        found=az(['ad','app','list','--filter',"displayName eq '"+name+"'"])
        if len(found)>1:stop('Multiple Entra applications match this installation; resolve the ambiguity in Entra.')
        obj=found[0] if found else az(['rest','--method','POST','--url','https://graph.microsoft.com/v1.0/applications'],{
            'displayName':name,'signInAudience':'AzureADMyOrg',
            'web':{'redirectUris':['https://api.'+e('DOMAIN')+'/api/v0/auth/signin-entraid'],'implicitGrantSettings':{'enableAccessTokenIssuance':False,'enableIdTokenIssuance':False}},
            'requiredResourceAccess':[{'resourceAppId':'00000003-0000-0000-c000-000000000000','resourceAccess':[{'id':'e1fe6dd8-ba31-4d61-89e7-88639da4683d','type':'Scope'}]}]})
        app={'objectId':obj['id'],'clientId':obj['appId'],'tenantId':tenant,'name':name};save(path,app)
    principals=az(['ad','sp','list','--filter',"appId eq '"+app['clientId']+"'"])
    principal=principals[0] if principals else az(['ad','sp','create','--id',app['clientId']])
    app['servicePrincipalId']=principal['id'];save(path,app)
    # Recover an interrupted credential creation by revoking only this installer's unfinished credential.
    current=az(['ad','app','show','--id',app['objectId']])
    label='mef-installer-'+state['installationId']
    for credential in current.get('passwordCredentials',[]):
        if credential.get('displayName')==label:az(['rest','--method','POST','--url','https://graph.microsoft.com/v1.0/applications/'+app['objectId']+'/removePassword'],{'keyId':credential['keyId']})
    expiry=(datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=180)).isoformat()
    credential=az(['rest','--method','POST','--url','https://graph.microsoft.com/v1.0/applications/'+app['objectId']+'/addPassword'],{'passwordCredential':{'displayName':label,'endDateTime':expiry}})
    app.update(clientSecret=credential['secretText'],credentialId=credential['keyId'],expiresAt=expiry);save(path,app)
    print('Created a single-tenant Entra Web App Registration (User.Read); credential saved privately. Tenant consent policy still applies.')
elif action=='render':
    passwords=saved_passwords()
    if passwords is None:passwords={name:'Mef!'+secrets.token_urlsafe(32) for name in ['mssql','pgvector','bootstrap']}
    state.setdefault('installationId',str(uuid.uuid4()));save(statefile,state)
    save(work/'passwords.json',passwords)
    if e('ENTRA_MODE')=='create':app=read(work/'entra.json',{'clientId':'PENDING_ENTRA_APP_CREATION','clientSecret':'PENDING_ENTRA_APP_CREATION'})
    else:app={'clientId':e('ENTRA_CLIENT_ID'),'clientSecret':e('ENTRA_CLIENT_SECRET')}
    if 'clientSecret' not in app:stop('Entra creation is incomplete; rerun the installer in deployment mode.')
    mapping={name+'.example.com':name+'.'+e('DOMAIN') for name in ['apps','api','servicehost','knowledge-graph','plantuml']}
    def replace(value):
        if isinstance(value,dict):return {k:replace(v) for k,v in value.items()}
        if isinstance(value,list):return [replace(v) for v in value]
        if isinstance(value,str):
            for old,new in mapping.items():value=value.replace(old,new)
            value=value.replace('example.com',e('DOMAIN'))
        return value
    def merge(a,b):
        for k,v in b.items():
            if isinstance(v,dict) and isinstance(a.get(k),dict):merge(a[k],v)
            else:a[k]=copy.deepcopy(v)
        return a
    components=['storage','pgvector','mssql','db-update','api','servicehost','knowledge-graph','apps']
    if e('INSTALL_PLANTUML')=='true':components.append('plantuml')
    for name in components:
        doc=replace(yaml.safe_load((root/'helm/values'/f'{name}.yaml').read_text()))
        if name=='storage':
            for claim in doc['claims'].values():claim.update(storageClass=e('SHARED_STORAGE_CLASS'),accessModes=[e('SHARED_ACCESS_MODE')])
        elif name in ['mssql','pgvector']:doc['persistence']['storageClass']=e('DB_STORAGE_CLASS')
        if name=='mssql':doc['env'].update(ACCEPT_EULA='Y',MSSQL_PID=e('MSSQL_EDITION'))
        if name=='api':
            auth=doc['config']['appsettings']['AuthOptions'];auth.update(EntraIdAuth=True,EntraIdAuthUrl='https://login.microsoftonline.com/'+e('ENTRA_TENANT_ID'),Domain=e('DOMAIN'));auth['EntraId'].update(ClientId=app['clientId'],ClientSecret='')
        if name=='apps':
            config=json.loads(doc['config']['data']['config.json']);config.update(EntraIdAuthClientId=app['clientId'],EntraIdAuthUrl='https://login.microsoftonline.com/'+e('ENTRA_TENANT_ID'));doc['config']['data']['config.json']=json.dumps(config,indent=2)
        # A fingerprint triggers rollout when Secret-backed credentials change.
        if name in ['api','servicehost']:
            material=[passwords['mssql']]
            if name=='api':material.extend([passwords['pgvector'],app['clientSecret']])
            doc.setdefault('podAnnotations',{})['mef.dev/credentials-checksum']=hashlib.sha256(json.dumps(material).encode()).hexdigest()
        if name in ['api','apps','servicehost','knowledge-graph','plantuml']:
            merge(doc,replace(yaml.safe_load((root/'helm/values/ingress'/e('ROUTING_PROFILE')/f'{name}.yaml').read_text())))
            if e('ROUTING_PROFILE').startswith('classic/'):
                doc['ingress']['className']=e('ROUTING_CLASS') or profiles[e('ROUTING_PROFILE')][0]
            if name=='api' and e('ROUTING_PROFILE').startswith('gateway/'):
                cors='gateway/traefik/cors.yaml' if e('ROUTING_PROFILE')=='gateway/traefik' else 'gateway/common/cors.yaml'
                merge(doc,replace(yaml.safe_load((root/'helm/values/ingress'/cors).read_text())))
            if e('SHARED_ACCESS_MODE')=='ReadWriteOnce':doc['nodeSelector']['kubernetes.io/hostname']=e('NODE_NAME')
        save(work/'values'/f'{name}.yaml',doc)
    def quoted(value):return '"'+value.replace('"','""')+'"'
    sql='Server=mssql,1433;Database=UCP;User Id=sa;Password='+quoted(passwords['mssql'])+';TrustServerCertificate=True;'
    pg='Host=pgvector;Port=5432;Database=mef;Username=mef;Password='+quoted(passwords['pgvector'])+';'
    data={'mssql-auth':{'password':passwords['mssql']},'pgvector-auth':{'password':passwords['pgvector']},'db-update-bootstrap':{'password':passwords['bootstrap']},'api-secrets':{'ucpDbConnection':sql,'pgvector':pg,'entraClientSecret':app['clientSecret']},'servicehost-secrets':{'csUcp':sql,'csWidecoup':sql}}
    for name,values in data.items():
        doc=yaml.safe_load((root/'helm/values/secrets'/f'{name}.yaml').read_text());doc['metadata']['namespace']=e('NAMESPACE');doc['stringData']=values;save(work/'secrets'/f'{name}.yaml',doc)
    if e('ROUTING_PROFILE').startswith('gateway/'):
        files=['gateway.yaml','redirect.yaml']
        if e('ROUTING_PROFILE')=='gateway/traefik':files.append('cors-middleware.yaml')
        if e('ROUTING_PROFILE')=='gateway/nginx-gateway-fabric':files.append('client-settings.yaml')
        if e('ROUTING_PROFILE')=='gateway/envoy-gateway':files.extend(['body-limit.yaml','https-http1.yaml'])
        for name in files:
            doc=replace(yaml.safe_load((root/'helm/values/ingress'/e('ROUTING_PROFILE')/name).read_text()))
            if name=='gateway.yaml':doc['spec']['gatewayClassName']=e('ROUTING_CLASS') or profiles[e('ROUTING_PROFILE')][0]
            if name=='redirect.yaml' and e('INSTALL_PLANTUML')!='true':doc['spec']['hostnames']=[h for h in doc['spec']['hostnames'] if not h.startswith('plantuml.')]
            doc['metadata']['namespace']=e('NAMESPACE');save(work/'networking'/name,doc)
        if e('ROUTING_PROFILE')=='gateway/envoy-gateway' and e('INSTALL_CONTROLLER')=='true':
            doc=yaml.safe_load((root/'helm/values/ingress/gateway/envoy-gateway/gatewayclass.yaml').read_text())
            doc['metadata']['annotations']={'mef.dev/installation-id':state['installationId']}
            save(work/'networking/gatewayclass.yaml',doc)
    print('Generated complete values and separate Secrets in .local/installer (private file permissions).')
elif action in ['packages-check','identity-check','plugins']:
    # All plugin operations use the same explicitly selected cluster and namespace.
    k=['kubectl','--context',e('KUBE_CONTEXT'),'--namespace',e('NAMESPACE')]
    def run(args,body=None,timeout=120):
        try:p=subprocess.run(args,input=body,capture_output=True,timeout=timeout)
        except subprocess.TimeoutExpired:stop('Operation timed out: '+args[0]+'. Existing data was preserved; rerun to resume.')
        if p.returncode:stop('Operation failed: '+args[0]+'. Inspect this installation; credential-bearing output was suppressed.')
        return p.stdout
    folder=root/'deployment-packages'
    try:
        manifest=json.loads((folder/'manifest.json').read_text())
        artifacts=manifest['Artifacts']
        if not isinstance(manifest.get('BundleVersion'),str) or not manifest['BundleVersion'].strip() or not isinstance(artifacts,list) or not artifacts:raise ValueError()
        names=set();paths=set();enabled=[];files={}
        for item in artifacts:
            name,alias,filename=item['Name'],item['Namespace'],item['Path']
            if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*',name) or not re.fullmatch(r'[a-z][a-z0-9-]*',alias):raise ValueError()
            if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*\.zip',filename) or name.casefold() in names or filename.casefold() in paths:raise ValueError()
            if not isinstance(item.get('Enable',True),bool):raise ValueError()
            names.add(name.casefold());paths.add(filename.casefold())
            package=folder/filename
            if package.is_symlink() or not package.is_file():raise ValueError()
            with zipfile.ZipFile(package) as archive:
                if not archive.infolist() or archive.testzip() is not None:raise ValueError()
                for entry in archive.infolist():
                    path=entry.filename.replace('\\','/')
                    if path.startswith('/') or '..' in path.split('/') or ':' in path or stat.S_ISLNK(entry.external_attr>>16):raise ValueError()
            files[filename]=hashlib.sha256(package.read_bytes()).hexdigest()
            if item.get('Enable',True):enabled.append(item)
        if not enabled:raise ValueError()
        files['manifest.json']=hashlib.sha256((folder/'manifest.json').read_bytes()).hexdigest()
    except (OSError,ValueError,KeyError,TypeError,RuntimeError,zipfile.BadZipFile):
        stop('Invalid deployment-packages: supply a BundleVersion, unique Name/Namespace/Path entries, at least one enabled artifact, and valid ZIPs with safe relative paths.')
    fingerprint=hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest()
    if state.get('pluginBundleHash') and state['pluginBundleHash']!=fingerprint:
        stop('The installed plugin bundle differs from deployment-packages. Automatic package upgrades are blocked; use the application publishing workflow for a reviewed upgrade.')
    if state.get('setupEmail') and state['setupEmail'].casefold()!=e('SETUP_EMAIL').casefold():
        stop('MEF_SETUP_EMAIL differs from the saved installation owner. Assign additional users in Apps; do not replace the bootstrap owner.')
    if state.get('platformSetupStarted') or state.get('pluginBundleHash'):
        saved_root=read(work/'root-credentials.json')
        saved_access=read(work/'plugin-access.json')
        if not saved_root.get('password') or saved_root.get('userName')!='root' or not saved_access.get('userId'):
            stop('Saved plugin/root credentials are missing or incomplete. Restore .local/installer from backup; credentials must not be regenerated for an existing platform.')
    if action=='packages-check':
        print('Plugin manifest, ZIP integrity and saved bundle identity: OK');sys.exit(0)
    def request(host,method,path,body=None,token=None,cookie=None):
        context=ssl.create_default_context()
        if e('HTTPS_CA_FILE'):context.load_verify_locations(cafile=e('HTTPS_CA_FILE'))
        conn=http.client.HTTPSConnection(host,context=context,timeout=300)
        headers={'Content-Type':'application/json','Accept':'application/json'}
        if token:headers['Authorization']='Bearer '+token
        if cookie:headers['Cookie']='external_access_token='+cookie
        try:
            conn.request(method,path,body=json.dumps(body).encode() if body is not None else None,headers=headers)
            response=conn.getresponse();raw=response.read();code=response.status
            try:result=json.loads(raw) if raw else None
            except ValueError:result=None
            return code,result
        except (OSError,http.client.HTTPException):stop('HTTPS request failed for '+host+'. Check DNS, trusted CA and routing; no TLS verification was disabled.')
        finally:conn.close()
    host='api.'+e('DOMAIN')
    def checked(method,path,body=None,token=None,cookie=None):
        status,obj=request(host,method,path,body,token,cookie)
        if status!=200:stop(method+' '+path+' returned HTTP '+str(status)+'. Inspect API logs; response content was suppressed to protect credentials.')
        return obj
    def identity():
        account=json.loads(run(['az','account','show','--output','json','--only-show-errors']))
        if account.get('tenantId')!=e('ENTRA_TENANT_ID'):stop('Azure CLI is using another tenant. Sign in with the configured tenant.')
        result=json.loads(run(['az','account','get-access-token','--resource-type','ms-graph','--output','json','--only-show-errors']))
        delegated=result['accessToken']
        status,profile=request('graph.microsoft.com','GET','/v1.0/me?$select=id,mail,userPrincipalName,givenName,surname',token=delegated)
        if status!=200 or not isinstance(profile,dict) or not profile.get('id'):stop('A delegated Microsoft user login with Graph profile access is required; service-principal login cannot bootstrap an MEF user. Run az login --tenant YOUR_TENANT_ID --allow-no-subscriptions.')
        if e('SETUP_EMAIL').casefold() not in [str(profile.get(n) or '').casefold() for n in ['mail','userPrincipalName']]:
            stop('The Microsoft account differs from MEF_SETUP_EMAIL. Sign in as the intended installation owner.')
        return delegated,profile
    if action=='identity-check':
        identity();print('Delegated Microsoft identity and installation owner: OK');sys.exit(0)
    # Persist root credentials before the first setup POST, so interrupted imports can resume.
    credentials_path=work/'root-credentials.json'
    credentials=read(credentials_path)
    access=read(work/'plugin-access.json')
    user_token=None
    if access:
        if access.get('bundleHash')!=fingerprint or access.get('email','').casefold()!=e('SETUP_EMAIL').casefold():stop('Saved plugin access state does not match this bundle/owner.')
        user_id=access['userId'];tenant_id=access['tenantId']
    else:
        delegated,profile=identity()
        status,session=request(host,'POST','/api/v0/auth/verify/EntraId',{},cookie=delegated)
        if status==404 and isinstance(session,dict) and session.get('id'):
            registration=read(work/'registration.json')
            if not registration:
                registration={'firstName':profile.get('givenName') or 'Administrator','lastName':profile.get('surname') or '',
                    'email':session.get('email') or profile.get('mail') or profile['userPrincipalName'],
                    'pin':str(secrets.randbelow(900000)+100000),'provider':3}
                registration['pinConfirm']=registration['pin'];save(work/'registration.json',registration)
            session=checked('POST','/api/v0/auth/register',registration,cookie=delegated)
        elif status!=200:stop('Microsoft identity verification failed with HTTP '+str(status)+'. Inspect registration/tenant policy before retrying.')
        if not isinstance(session,dict) or not session.get('accessToken'):stop('MEF did not issue an authenticated tenant session. Complete account approval before retrying.')
        user_token=session['accessToken']
        claims=json.loads(base64.urlsafe_b64decode(user_token.split('.')[1]+'==='))
        user_id=claims['userId'];tenant_id=int(claims['tenantId'])
        access={'email':e('SETUP_EMAIL'),'userId':user_id,'tenantId':tenant_id,'bundleHash':fingerprint}
        # This checkpoint does not claim setup/import success.
        save(work/'plugin-access.json',access)
    if not credentials:
        credentials={'userName':'root','password':'Mef!42_'+secrets.token_urlsafe(32),'currentTenant':tenant_id}
        save(credentials_path,credentials)
    if credentials.get('currentTenant')!=tenant_id:stop('Saved root credentials belong to another MEF tenant.')
    def root_login():return checked('POST','/api/v0/auth/login',credentials)['accessToken']
    # Recover with the saved root after a partial setup, without bypassing authentication.
    if user_token is None:
        status,login=request(host,'POST','/api/v0/auth/login',credentials)
        if status==200 and isinstance(login,dict) and login.get('accessToken'):admin_token=login['accessToken']
        else:
            delegated,profile=identity()
            user_token=checked('POST','/api/v0/auth/verify/EntraId',{'currentTenant':tenant_id},cookie=delegated)['accessToken']
            admin_token=user_token
    else:
        admin_token=user_token
        if state.get('platformSetupStarted'):
            status,login=request(host,'POST','/api/v0/auth/login',credentials)
            if status==200 and isinstance(login,dict) and login.get('accessToken'):admin_token=login['accessToken']
    # Copy archives atomically, then publish the manifest last; no shell interpolation of file contents.
    storage=yaml.safe_load((work/'values/api.yaml').read_text())['config']['appsettings']['Settings']['StorageFolder']
    bundle=storage.rstrip('/')+'/bundle'
    for filename in [n for n in files if n!='manifest.json']+['manifest.json']:
        data=(folder/filename).read_bytes();target=bundle+'/'+filename
        digest=hashlib.sha256(data).hexdigest()
        command='umask 0002; mkdir -p '+shlex.quote(bundle)+'; cat > '+shlex.quote(target+'.partial')+' && mv '+shlex.quote(target+'.partial')+' '+shlex.quote(target)
        run(k+['exec','-i','deployment/api','--','sh','-ec',command],data,timeout=300)
        actual=run(k+['exec','deployment/api','--','sha256sum',target]).decode().split()[0]
        if actual!=digest:stop('Package checksum verification failed for '+filename)
    if not state.get('pluginBundleHash'):
        setup=checked('GET','/api/v0/auth/setup',token=admin_token)
        if not setup.get('firstSetup') and not state.get('platformSetupStarted'):
            stop('MEF was already configured outside this installer. Automatic setup overwrite is blocked; use the manual plugin publishing workflow.')
        setup['root'].update(userName=credentials['userName'],password=credentials['password'],email=e('SETUP_EMAIL'))
        setup['tenant'].update(name=e('ORGANIZATION_NAME'),domain=[e('SETUP_EMAIL').split('@')[1]])
        settings=setup['appSettings']['settings']
        settings['entityGenerator']={'enabled':True,'url':'http://servicehost:7000'}
        settings['mail']={'sendMail':False,'smtpClient':{'host':''}}
        # Do not opt in to a third-party email processor on the administrator's behalf.
        setup['appSettings']['tasks']={'taskProducers':None}
        setup['appSettings']['authOptions'].update(entraIdAuth=True,passwordAuth=True,multiTenant=False,googleAuth=False,linkedinAuth=False,idGovUaAuth=False)
        actual=setup.get('manifest') or {}
        if {(i['namespace'],i['name']) for i in actual.get('artifacts',[])}!={(i['Namespace'],i['Name']) for i in artifacts}:stop('API manifest differs from the staged bundle.')
        setup['manifest']['artifacts']=[{'namespace':i['Namespace'],'name':i['Name'],'path':i['Path'],'enable':i.get('Enable',True)} for i in artifacts]
        state['platformSetupStarted']=True;state['setupEmail']=e('SETUP_EMAIL');save(statefile,state)
        if checked('POST','/api/v0/auth/setup',setup,token=admin_token) is not True:stop('MEF did not confirm platform setup and bundle import.')
        state['pluginBundleHash']=fingerprint;save(statefile,state)
    admin_token=root_login()
    namespaces=[];page=0
    while True:
        result=checked('GET',f'/api/v0/namespaces?page={page}&pagesize=100',token=admin_token)
        items=result['items'];namespaces.extend(items)
        if len(items)<100:break
        page+=1
    for item in enabled:
        matches=[n for n in namespaces if n['alias']==item['Namespace']]
        if len(matches)!=1:stop('Expected exactly one imported namespace: '+item['Namespace'])
        namespace_id=matches[0]['id']
        detail=checked('GET',f'/api/v0/namespaces/{namespace_id}',token=admin_token)
        services=[s for s in detail['services'] if s.get('pluginName')==item['Name']]
        if len(services)!=1:stop('Imported service missing or ambiguous: '+item['Name'])
        checked('POST',f'/api/v0/namespaces/{namespace_id}/request',token=admin_token)
        checked('POST',f'/api/v0/namespaces/{namespace_id}/user/{services[0]["serviceId"]}',{'userId':user_id,'assigned':True},token=admin_token)
    # Obtain a fresh owner session only when needed for end-user access verification.
    delegated,profile=identity()
    user_session=checked('POST','/api/v0/auth/verify/EntraId',{'currentTenant':tenant_id},cookie=delegated)
    user_token=user_session['accessToken']
    configs=checked('GET','/api/v0/services/config',token=user_token)
    if not isinstance(configs,list):stop('Unexpected service configuration response.')
    for item in enabled:
        if not any(c.get('alias')==item['Namespace'] and item['Name'] in [c.get('pluginUIName'),c.get('pluginUiName'),c.get('pluginMefName')] for c in configs):stop('The Microsoft user cannot access '+item['Name'])
    if any(i['Name']=='bpmn-designer' and i['Namespace']=='bpmn' for i in enabled):
        profile=checked('GET','/api/v2/plugins/bpmn/bpmn-designer/ui-profile',token=user_token)
        if not isinstance(profile,dict) or not profile:stop('BPMN did not return its UI profile.')
    if any(i['Name']=='ProductCatalogAI' and i['Namespace']=='ai' for i in enabled):
        # Loading the backend applies its own EF migrations and exercises the real Secret-backed connection.
        threads=checked('GET','/api/v2/ai/threads/list?page=1&pageSize=1',token=user_token)
        if not isinstance(threads,dict) or not isinstance(threads.get('items'),list):stop('ProductCatalogAI did not return its PostgreSQL-backed thread list.')
    query="SELECT extversion FROM pg_extension WHERE extname='vector';"
    version=run(k+['exec','statefulset/pgvector','--','sh','-ec','psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -v ON_ERROR_STOP=1 -c '+shlex.quote(query)]).decode().strip()
    if not version:stop('The vector extension is missing from the application PostgreSQL database.')
    query="SELECT '[1,2,3]'::vector <-> '[1,2,4]'::vector;"
    distance=run(k+['exec','statefulset/pgvector','--','sh','-ec','psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -v ON_ERROR_STOP=1 -c '+shlex.quote(query)]).decode().strip()
    if distance!='1':stop('PostgreSQL vector distance verification failed.')
    state['pluginAccessComplete']=True;save(statefile,state)
    print('Bundle files verified; plugins imported; owner access and pgvector '+version+' verified.')
    print('Emergency root credentials: .local/installer/root-credentials.json (keep private).')

elif action=='routing-check':
    command=['kubectl','--context',e('KUBE_CONTEXT'),'--namespace',e('NAMESPACE'),'--request-timeout=15s']
    names=['api','apps','servicehost','knowledge-graph','mef-https-redirect']
    if e('INSTALL_PLANTUML')=='true':names.append('plantuml')
    def conditions_ready(conditions,types,generation):
        return all(any(c.get('type')==t and c.get('status')=='True' and c.get('observedGeneration')==generation for c in conditions) for t in types)
    deadline=time.monotonic()+300;pending=[]
    while True:
        pending=[]
        for kind,name in [('gateway','mef-gateway')]+[('httproute',n) for n in names]:
            try:result=subprocess.run(command+['get',kind,name,'-o','json'],capture_output=True,text=True,timeout=20)
            except subprocess.TimeoutExpired:pending.append(kind+'/'+name);continue
            if result.returncode:pending.append(kind+'/'+name);continue
            obj=json.loads(result.stdout);generation=obj['metadata']['generation']
            if kind=='gateway':ready=conditions_ready(obj.get('status',{}).get('conditions',[]),['Accepted','Programmed'],generation)
            else:
                section='http' if name=='mef-https-redirect' else 'https'
                ready=any(p.get('parentRef',{}).get('name')=='mef-gateway'
                    and p['parentRef'].get('namespace',e('NAMESPACE'))==e('NAMESPACE')
                    and p['parentRef'].get('sectionName')==section
                    and conditions_ready(p.get('conditions',[]),['Accepted','ResolvedRefs'],generation)
                    for p in obj.get('status',{}).get('parents',[]))
            if not ready:pending.append(kind+'/'+name)
        if not pending:print('Gateway and all routes report current-generation readiness.');break
        if time.monotonic()>=deadline:stop('Timed out waiting for current routing status: '+', '.join(pending)+'. Inspect Gateway/HTTPRoute conditions before retrying.')
        time.sleep(3)
else:stop('Unknown internal action.')
PYTHON
}
STEP='configuration validation'
helper validate
helper passwords-check
if [[ $MEF_INSTALL_PLUGINS == true ]]; then helper packages-check; fi
for suffix in apps api servicehost knowledge-graph; do
  openssl x509 -in "$MEF_TLS_CERT_FILE" -noout -checkhost "$suffix.$MEF_DOMAIN" >/dev/null 2>&1 || die "TLS certificate does not cover $suffix.$MEF_DOMAIN."
done
if [[ $MEF_INSTALL_PLANTUML == true ]]; then
  openssl x509 -in "$MEF_TLS_CERT_FILE" -noout -checkhost "plantuml.$MEF_DOMAIN" >/dev/null 2>&1 || die 'TLS certificate does not cover the PlantUML hostname.'
fi
openssl x509 -in "$MEF_TLS_CERT_FILE" -noout -checkend 0 >/dev/null || die 'TLS certificate has expired.'
cert_public=$(openssl x509 -in "$MEF_TLS_CERT_FILE" -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256)
key_public=$(openssl pkey -in "$MEF_TLS_KEY_FILE" -passin pass: -pubout -outform DER 2>/dev/null | openssl dgst -sha256) || die 'Cannot read TLS key; use an unencrypted PEM key.'
[[ $cert_public == "$key_public" ]] || die 'TLS certificate and private key do not match.'
K=(kubectl --context "$MEF_KUBE_CONTEXT" --namespace "$MEF_NAMESPACE")
H=(helm --kube-context "$MEF_KUBE_CONTEXT" --namespace "$MEF_NAMESPACE")
CLASS=$(helper class)
CONTROLLER_RELEASE=$(helper release)
check_migration() {
  local release_list migration_status
  release_list=$("${H[@]}" list --all --filter '^db-update$' -o json)
  migration_exists=$(helper migration-check "$release_list")
  if [[ $migration_exists == yes ]]; then
    migration_status=$("${H[@]}" status db-update -o json | python3 -c 'import json,sys;print(json.load(sys.stdin)["info"]["status"])')
    [[ $migration_status == deployed ]] || die 'The previous migration did not complete. Inspect db-update and the database before an intentional manual retry.'
  fi
}
if [[ $MODE != render ]]; then
  STEP='read-only cluster preflight'
  say "Checking context $MEF_KUBE_CONTEXT, namespace $MEF_NAMESPACE"
  "${K[@]}" get --raw=/readyz >/dev/null || die 'Cannot reach this Kubernetes context; check kubeconfig and access.'
  KUBE_VERSION=$("${K[@]}" version -o json | python3 -c 'import json,sys;v=json.load(sys.stdin)["serverVersion"];assert (int(v["major"]),int(v["minor"].rstrip("+"))) >= (1,28),"Kubernetes 1.28+ required";print(v["gitVersion"])')
  if [[ $MEF_INSTALL_CONTROLLER == true && $MEF_ROUTING_PROFILE == gateway/nginx-gateway-fabric ]]; then
    python3 -c 'import re,sys;v=tuple(map(int,re.match(r"v?(\d+)\.(\d+)",sys.argv[1]).groups()));assert v >= (1,31), "NGINX Gateway Fabric 2.6.7 requires Kubernetes 1.31+; choose another compatible controller or upgrade the cluster"' "$KUBE_VERSION"
  fi
  if [[ $MEF_INSTALL_CONTROLLER == true && $MEF_ROUTING_PROFILE == gateway/envoy-gateway ]]; then
    python3 -c 'import re,sys;v=tuple(map(int,re.match(r"v?(\d+)\.(\d+)",sys.argv[1]).groups()));assert (1,33) <= v <= (1,36), "Envoy Gateway v1.9.2 installer supports its tested Kubernetes range 1.33-1.36; use a compatible cluster or an existing controller reviewed for your version"' "$KUBE_VERSION"
  fi
  CLUSTER_UID=$("${K[@]}" get namespace kube-system -o jsonpath='{.metadata.uid}')
  helper target-check "$CLUSTER_UID"
  for storage in "$MEF_SHARED_STORAGE_CLASS" "$MEF_DB_STORAGE_CLASS"; do
    "${K[@]}" get storageclass "$storage" >/dev/null || die "StorageClass $storage does not exist. Run kubectl get storageclass."
  done
  provisioner=$("${K[@]}" get storageclass "$MEF_SHARED_STORAGE_CLASS" -o jsonpath='{.provisioner}')
  [[ $MEF_SHARED_ACCESS_MODE != ReadWriteMany || $provisioner != rancher.io/local-path ]] || die 'local-path cannot provision shared RWX claims. Choose NFS/CephFS, or explicitly use ReadWriteOnce with MEF_NODE_NAME for a single-node installation.'
  if [[ $MEF_SHARED_ACCESS_MODE == ReadWriteOnce ]]; then
    node_label=$("${K[@]}" get node "$MEF_NODE_NAME" -o jsonpath='{.metadata.labels.kubernetes\.io/hostname}')
    [[ $node_label == "$MEF_NODE_NAME" ]] || die 'MEF_NODE_NAME must match the node name and its kubernetes.io/hostname label.'
  fi
  saved_id=$(helper id)
  owner=$("${K[@]}" get namespace "$MEF_NAMESPACE" --ignore-not-found -o 'jsonpath={.metadata.annotations.mef\.dev/installation-id}')
  existing_ns=$("${K[@]}" get namespace "$MEF_NAMESPACE" --ignore-not-found -o name)
  [[ -z $existing_ns || ( -n $saved_id && $owner == "$saved_id" ) ]] || die 'Namespace already exists and is not owned by this installer. Use the manual guide for existing installations.'
  [[ -z $existing_ns || -f $WORK/passwords.json ]] || die 'Saved database passwords are missing. Restore .local/installer from backup; do not generate new passwords for an existing database.'
  check_migration
  if [[ $MEF_INSTALL_CONTROLLER == false ]]; then
    class_kind=ingressclass
    [[ $MEF_ROUTING_PROFILE != gateway/* ]] || class_kind=gatewayclass
    "${K[@]}" get "$class_kind" "$CLASS" >/dev/null || die "Existing $class_kind $CLASS was not found; correct MEF_ROUTING_CLASS."
  else
    class_kind=ingressclass
    [[ $MEF_ROUTING_PROFILE != gateway/* ]] || class_kind=gatewayclass
    class_exists=''
    class_ns=''
    class_release=''
    if [[ $class_kind == ingressclass ]] || [[ -n $("${K[@]}" get crd gatewayclasses.gateway.networking.k8s.io --ignore-not-found -o name) ]]; then
      class_exists=$("${K[@]}" get "$class_kind" "$CLASS" --ignore-not-found -o name)
      class_ns=$("${K[@]}" get "$class_kind" "$CLASS" --ignore-not-found -o 'jsonpath={.metadata.annotations.meta\.helm\.sh/release-namespace}')
      class_release=$("${K[@]}" get "$class_kind" "$CLASS" --ignore-not-found -o 'jsonpath={.metadata.annotations.meta\.helm\.sh/release-name}')
    fi
    if [[ -n $class_exists ]]; then
      if [[ $MEF_ROUTING_PROFILE == gateway/envoy-gateway ]]; then
        class_owner=$("${K[@]}" get "$class_kind" "$CLASS" -o 'jsonpath={.metadata.annotations.mef\.dev/installation-id}')
        [[ -n $saved_id && $class_owner == "$saved_id" ]] || die 'The Envoy GatewayClass is not owned by this installer. Set MEF_INSTALL_CONTROLLER=false to reuse it.'
      else
        [[ $class_ns == "$MEF_NAMESPACE" && $class_release == "$CONTROLLER_RELEASE" ]] || die 'The routing class belongs to another controller installation. Set MEF_INSTALL_CONTROLLER=false to reuse it.'
      fi
    fi
  fi
  if [[ $MEF_ROUTING_PROFILE == gateway/* ]]; then
    "${K[@]}" get crd gatewayclasses.gateway.networking.k8s.io gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io --ignore-not-found -o json | \
      python3 -c 'import json,sys;items=json.load(sys.stdin).get("items",[]);assert len(items) in [0,3], "Gateway API CRDs are incomplete; install a compatible standard bundle manually";v=[next((x for x in i["spec"]["versions"] if x["name"]=="v1" and x.get("served")),None) for i in items];assert all(v), "Gateway API CRDs must serve v1";routes=[x for i,x in zip(items,v) if i["metadata"]["name"].startswith("httproutes.")];assert not routes or sys.argv[1]=="gateway/traefik" or "cors" in routes[0]["schema"]["openAPIV3Schema"]["properties"]["spec"]["properties"]["rules"]["items"]["properties"]["filters"]["items"]["properties"], "Existing HTTPRoute CRD lacks CORS; review the Gateway API version before installing"' "$MEF_ROUTING_PROFILE"
    if [[ $MEF_INSTALL_CONTROLLER == false && $MEF_ROUTING_PROFILE == gateway/traefik ]]; then
      "${K[@]}" get crd middlewares.traefik.io >/dev/null || die 'Existing Traefik must have its Middleware CRD and Kubernetes CRD provider enabled.'
    fi
  fi
  if [[ $MEF_INSTALL_PLUGINS == true ]]; then
    command -v az >/dev/null || die 'Install Azure CLI for the initial Microsoft user registration.'
    if ! az account show --query tenantId -o tsv --only-show-errors >/dev/null 2>&1; then
      [[ $MODE == deploy ]] || die "Run az login --tenant $MEF_ENTRA_TENANT_ID --allow-no-subscriptions."
      az login --tenant "$MEF_ENTRA_TENANT_ID" --allow-no-subscriptions --output none
    fi
    helper identity-check
  fi
  if [[ $MEF_ENTRA_MODE == create ]]; then
    command -v az >/dev/null || die 'Install Azure CLI, or select MEF_ENTRA_MODE=existing and fill its client ID/secret.'
    tenant=$(az account show --query tenantId -o tsv --only-show-errors 2>/dev/null) || die "Run az login --tenant $MEF_ENTRA_TENANT_ID --allow-no-subscriptions, then rerun."
    [[ $tenant == "$MEF_ENTRA_TENANT_ID" ]] || die 'Azure CLI is logged into another tenant; use az login --tenant with the configured tenant ID.'
  fi
  if [[ $MEF_ENTRA_MODE == existing ]]; then helper entra-verify; fi
  if [[ $MODE == check ]]; then say 'Preflight passed. No remote resources were changed. Storage capabilities still depend on your CSI backend.'; exit 0; fi
else
  KUBE_VERSION=1.35.0
fi
STEP='local configuration generation'
if [[ $MODE == deploy ]]; then
  # Persist passwords before binding state or creating cloud resources.
  helper passwords-init
  helper bind "$CLUSTER_UID"
  helper entra
  if [[ $MEF_ENTRA_MODE == create ]]; then helper entra-verify; fi
fi
helper render
components=(storage pgvector mssql db-update api servicehost knowledge-graph apps)
[[ $MEF_INSTALL_PLANTUML != true ]] || components+=(plantuml)
for component in "${components[@]}"; do
  helm template "$component" "$ROOT/helm/charts/$component" --namespace "$MEF_NAMESPACE" --kube-version "$KUBE_VERSION" -f "$WORK/values/$component.yaml" >/dev/null
done
if [[ $MODE == render ]]; then say 'Helm rendering passed. No remote resources were changed; create-mode Entra fields remain pending until deployment.'; exit 0; fi
STEP='namespace and credentials'
installation_id=$(helper id)
if [[ -z $existing_ns ]]; then
  "${K[@]}" create namespace "$MEF_NAMESPACE" --dry-run=client -o json | \
    python3 -c 'import json,sys;d=json.load(sys.stdin);d["metadata"]["annotations"]={"mef.dev/installation-id":sys.argv[1]};json.dump(d,sys.stdout)' "$installation_id" | \
    "${K[@]}" create -f -
fi
"${K[@]}" apply -f "$WORK/secrets/"
"${K[@]}" create secret tls mef-tls --cert="$MEF_TLS_CERT_FILE" --key="$MEF_TLS_KEY_FILE" --dry-run=client -o yaml | "${K[@]}" apply -f -
install_release() {
  local name=$1
  STEP="Helm release $name"
  say "Installing $name"
  "${H[@]}" upgrade --install "$name" "$ROOT/helm/charts/$name" -f "$WORK/values/$name.yaml" --wait --timeout 10m
}
STEP='routing controller'
if [[ $MEF_ROUTING_PROFILE == gateway/* ]]; then
  gateway_crd=$("${K[@]}" get crd gateways.gateway.networking.k8s.io --ignore-not-found -o name)
  if [[ -z $gateway_crd ]]; then
    [[ $MEF_INSTALL_CONTROLLER == true ]] || die 'Install compatible Gateway API CRDs before reusing this controller.'
    "${K[@]}" apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
  fi
fi
if [[ $MEF_INSTALL_CONTROLLER == true ]]; then
  say "Installing controller for $MEF_ROUTING_PROFILE"
  case "$MEF_ROUTING_PROFILE" in
    gateway/nginx-gateway-fabric)
      "${H[@]}" upgrade --install mef-ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --version 2.6.7 -f "$ROOT/helm/values/ingress/$MEF_ROUTING_PROFILE/controller-values.yaml" --wait --timeout 10m ;;
    gateway/envoy-gateway)
      mkdir -p "$WORK/vendor"
      if [[ ! -d $WORK/vendor/gateway-helm ]]; then helm pull oci://docker.io/envoyproxy/gateway-helm --version v1.9.2 --untar --untardir "$WORK/vendor"; fi
      python3 -c 'import sys,yaml;assert str(yaml.safe_load(open(sys.argv[1]))["version"]).lstrip("v")=="1.9.2", "Cached Envoy chart has another version; remove only .local/installer/vendor/gateway-helm and rerun"' "$WORK/vendor/gateway-helm/Chart.yaml"
      "${K[@]}" apply --server-side -f "$WORK/vendor/gateway-helm/charts/crds/crds/generated/"
      "${H[@]}" upgrade --install mef-eg "$WORK/vendor/gateway-helm" --skip-crds --set crds.gatewayAPI.safeUpgradePolicy.enabled=false -f "$ROOT/helm/values/ingress/$MEF_ROUTING_PROFILE/controller-values.yaml" --wait --timeout 10m
      "${K[@]}" apply -f "$WORK/networking/gatewayclass.yaml" ;;
    gateway/traefik)
      helm repo add traefik https://traefik.github.io/charts
      helm repo update traefik
      "${H[@]}" upgrade --install mef-traefik traefik/traefik --version 41.7.1 -f "$ROOT/helm/values/ingress/$MEF_ROUTING_PROFILE/controller-values.yaml" --set providers.kubernetesCRD.enabled=true --wait --timeout 10m ;;
    classic/ingress-nginx)
      helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
      helm repo update ingress-nginx
      "${H[@]}" upgrade --install mef-ingress-nginx ingress-nginx/ingress-nginx --version 4.15.1 -f "$ROOT/helm/values/ingress/$MEF_ROUTING_PROFILE/controller-values.yaml" --wait --timeout 10m ;;
  esac
fi
if [[ $MEF_ROUTING_PROFILE == gateway/* ]]; then
  "${K[@]}" apply -f "$WORK/networking/gateway.yaml"
  "${K[@]}" apply -f "$WORK/networking/redirect.yaml"
  case "$MEF_ROUTING_PROFILE" in
    gateway/traefik) "${K[@]}" apply -f "$WORK/networking/cors-middleware.yaml" ;;
    gateway/nginx-gateway-fabric) "${K[@]}" apply -f "$WORK/networking/client-settings.yaml" ;;
    gateway/envoy-gateway)
      "${K[@]}" apply -f "$WORK/networking/body-limit.yaml"
      "${K[@]}" apply -f "$WORK/networking/https-http1.yaml" ;;
  esac
fi
STEP='shared storage'
# Do not --wait: WaitForFirstConsumer claims bind when application Pods are created.
"${H[@]}" upgrade --install storage "$ROOT/helm/charts/storage" -f "$WORK/values/storage.yaml"
install_release pgvector
install_release mssql
STEP='initial database migration'
check_migration
if [[ $migration_exists == yes ]]; then
  say 'Keeping the previously completed migration; it will not be run again.'
else
  "${H[@]}" upgrade --install db-update "$ROOT/helm/charts/db-update" -f "$WORK/values/db-update.yaml" --wait --wait-for-jobs --timeout 35m
fi
helper migration-done
for component in api servicehost knowledge-graph apps; do install_release "$component"; done
if [[ $MEF_INSTALL_PLANTUML == true ]]; then install_release plantuml; fi
STEP='verification'
for claim in front back api-config; do "${K[@]}" wait --for=jsonpath='{.status.phase}'=Bound "pvc/$claim" --timeout=5m; done
if [[ $MEF_ROUTING_PROFILE == gateway/* ]]; then
  helper routing-check
fi
if [[ $MEF_VERIFY_HTTPS == true ]]; then
  ca=()
  [[ -z $MEF_HTTPS_CA_FILE ]] || ca=(--cacert "$MEF_HTTPS_CA_FILE")
  for endpoint in "https://api.$MEF_DOMAIN/api/v0/live" "https://apps.$MEF_DOMAIN/" "https://knowledge-graph.$MEF_DOMAIN/"; do
    status=$(curl --silent --show-error --fail --retry 10 --retry-delay 2 --retry-max-time 60 --connect-timeout 10 --max-time 30 "${ca[@]}" --output /dev/null --write-out '%{http_code}' "$endpoint") || die "HTTPS verification failed for $endpoint. Check DNS, load balancer and TLS; then rerun."
    [[ $status == 200 ]] || die "Expected HTTP 200 from $endpoint; received $status. Check routing before continuing."
  done
  say 'Installation and HTTPS checks passed.'
else
  say 'Cluster installation is ready. External DNS/TLS/HTTPS verification is PENDING (MEF_VERIFY_HTTPS=false).'
fi
if [[ $MEF_INSTALL_PLUGINS == true ]]; then
  STEP='plugin installation and access'
  helper plugins
  say 'Plugins installed; PostgreSQL storage and Microsoft user access verified.'
  printf 'Sign in with the configured Microsoft account. Plugin access is ready.\n'
else
  printf 'Complete initial account/platform setup in the browser. Plugins were explicitly disabled.\n'
fi
printf 'Open https://apps.%s/login and choose Microsoft.\n' "$MEF_DOMAIN"
printf 'Keep .local/installer and your config securely for recovery and repeat runs.\n'
