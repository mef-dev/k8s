#!/usr/bin/env bash
set -euo pipefail
umask 077
: "${MSSQL_HOST:?}" "${MSSQL_DB:?}" "${MSSQL_USER:?}" "${MSSQL_PASSWORD:?}" "${APP_VERSION:?}" "${UCP_BOOTSTRAP_USER:?}" "${UCP_BOOTSTRAP_PASSWORD:?}"
[[ "$MSSQL_DB" =~ ^[A-Za-z_][A-Za-z0-9_]{0,49}$ ]] || { echo "Invalid SQL database identifier"; exit 2; }
[[ "$APP_VERSION" =~ ^[A-Za-z0-9._-]{1,20}$ ]] || { echo "Invalid application version"; exit 2; }
[[ "$FG10D_Num" =~ ^[0-9]+$ && "$FG10_Num" =~ ^[0-9]+$ && "$FG10D14_Num" =~ ^[0-9]+$ ]] || exit 2
sqlcmd=/opt/mssql-tools/bin/sqlcmd
[[ -x "$sqlcmd" ]] || sqlcmd=/opt/mssql-tools18/bin/sqlcmd
export SQLCMDPASSWORD="$MSSQL_PASSWORD"
cert_args=()
[[ "$TRUST_SERVER_CERTIFICATE" != true ]] || cert_args=(-C)
ready=false
for attempt in {1..60}; do
  if "$sqlcmd" -S "$MSSQL_HOST" -U "$MSSQL_USER" "${cert_args[@]}" -b -l 5 -Q 'SELECT 1' >/dev/null 2>&1; then ready=true; break; fi
  sleep 5
done
[[ "$ready" == true ]] || { echo "SQL connection check failed"; exit 1; }
[[ "$UCP_BOOTSTRAP_USER" =~ ^[A-Za-z_][A-Za-z0-9_]{0,49}$ ]] || exit 2
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Keep the connection string out of process arguments and log output.
quoted_password=${MSSQL_PASSWORD//\"/\"\"}
quoted_user=${MSSQL_USER//\"/\"\"}
quoted_host=${MSSQL_HOST//\"/\"\"}
connection="Server=\"$quoted_host\";Database=$MSSQL_DB;User ID=\"$quoted_user\";Password=\"$quoted_password\";Encrypt=True;TrustServerCertificate=$TRUST_SERVER_CERTIFICATE;"
connection=${connection//&/\&amp;}
connection=${connection//</\&lt;}
connection=${connection//>/\&gt;}
export MEF_TARGET_XML="<TargetConnectionString>$connection</TargetConnectionString>"
export MEF_DATABASE_XML="<TargetDatabaseName>$MSSQL_DB</TargetDatabaseName>"
awk '
 /<TargetConnectionString>/ { print ENVIRON["MEF_TARGET_XML"]; next }
 /<TargetDatabaseName>/ { print ENVIRON["MEF_DATABASE_XML"]; next }
 { print }
' /tmp/db/db.publish.xml > "$tmp/publish.xml"
unset MEF_TARGET_XML MEF_DATABASE_XML connection quoted_password quoted_user quoted_host
step() {
  local label=$1; shift
  echo "Starting $label"
  if "$@" >"$tmp/output.log" 2>&1; then
    echo "Completed $label"
  else
    local code=$?
    echo "Failed $label (exit $code)"
    # Print only error diagnostics, masking the exact input credential.
    while IFS= read -r line; do
      case "$line" in
        *Error*|*error*|*SQL7*|Msg\ *|Sqlcmd:*|*not\ defined*|*not\ found*|*Invalid*) line=${line//"$MSSQL_PASSWORD"/<redacted>}; line=${line//"$UCP_BOOTSTRAP_PASSWORD"/<redacted>}; printf '%s\n' "${line//"${UCPUserPassword:-}"/<redacted>}" ;;
      esac
    done < "$tmp/output.log"
    exit "$code"
  fi
}
# Use a protected copy so the image's embedded bootstrap password is never used.
cp -a /tmp/db/Scripts "$tmp/Scripts"
sed -i '/^[[:space:]]*:setvar[[:space:]]\+UCPUserName[[:space:]]/d; /^[[:space:]]*:setvar[[:space:]]\+UCPUserPassword[[:space:]]/d' "$tmp/Scripts/Create_FG.sql"
# The vendor script references an Azure MI-only view in a static batch.
# Resolve that optional probe dynamically so its TRY/CATCH works on SQL Server.
awk '
 /SELECT TOP\(1\) @vcores_stats = virtual_core_count/ {
   print "        EXEC sp_executesql N\047SELECT TOP(1) @result = virtual_core_count FROM master.sys.server_resource_stats ORDER BY end_time DESC;\047, N\047@result int OUTPUT\047, @result=@vcores_stats OUTPUT;";
   skip=2; next
 }
 skip > 0 { skip--; next }
 { print }
' "$tmp/Scripts/Init_Environment.sql" > "$tmp/init.sql"
mv "$tmp/init.sql" "$tmp/Scripts/Init_Environment.sql"
export UCPUserName="$UCP_BOOTSTRAP_USER"
# This variable is inserted into a T-SQL quoted string by the vendor SQL script.
export UCPUserPassword="${UCP_BOOTSTRAP_PASSWORD//\'/\'\'}"
cd "$tmp/Scripts"
if [[ "$CREATE_DATABASE_IF_MISSING" == true ]]; then
  step create-database "$sqlcmd" -S "$MSSQL_HOST" -U "$MSSQL_USER" "${cert_args[@]}" -b -d master \
    -Q "IF DB_ID(N'$MSSQL_DB') IS NULL EXEC(N'CREATE DATABASE [$MSSQL_DB]');"
fi
step pre-deployment "$sqlcmd" -S "$MSSQL_HOST" -U "$MSSQL_USER" "${cert_args[@]}" -b -d master \
  -i Script.PreDeployment.sql -v DatabaseName="$MSSQL_DB" DefaultFilePrefix="$MSSQL_DB" \
  Pt1_Dim1Num_Cust="$FG10D_Num" Pt2_Dim1Num_Cust="$FG10_Num" Pt3_Dim1Num_Cust="$FG10D14_Num"
step schema-publish /opt/sqlpackage/sqlpackage /a:Publish /pr:"$tmp/publish.xml" /sf:/tmp/db/db.dacpac \
  /p:BlockOnPossibleDataLoss=True /p:DropObjectsNotInSource=False \
  /p:DropIndexesNotInSource=False /p:DropConstraintsNotInSource=False
step post-deployment "$sqlcmd" -S "$MSSQL_HOST" -U "$MSSQL_USER" "${cert_args[@]}" -b -d master \
  -i Script.PostDeployment.sql -v DatabaseName="$MSSQL_DB" DefaultFilePrefix="$MSSQL_DB" APP_VERSION="$APP_VERSION"
echo "Database update finished; verify application behavior before serving traffic."
