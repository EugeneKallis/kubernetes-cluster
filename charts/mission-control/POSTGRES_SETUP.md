Mission Control Postgres setup

Postgres host: 192.168.1.150
Port: 5432

1) Create role + databases (run from any machine with psql access)

export PGHOST=192.168.1.150
export PGPORT=5432
export PGUSER=postgres
export PGPASSWORD='<SUPERUSER_PASSWORD>'

psql -v ON_ERROR_STOP=1 <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'mission_control') THEN
    CREATE ROLE mission_control LOGIN PASSWORD 'CHANGE_ME_STRONG_PASSWORD';
  ELSE
    ALTER ROLE mission_control WITH LOGIN PASSWORD 'CHANGE_ME_STRONG_PASSWORD';
  END IF;
END
$$;

CREATE DATABASE mission_control_dev OWNER mission_control;
CREATE DATABASE mission_control_prod OWNER mission_control;
SQL

# if DBs might already exist, run idempotent creates instead:
psql -v ON_ERROR_STOP=1 <<'SQL'
SELECT 'CREATE DATABASE mission_control_dev OWNER mission_control'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'mission_control_dev')\gexec

SELECT 'CREATE DATABASE mission_control_prod OWNER mission_control'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'mission_control_prod')\gexec
SQL

2) Verify login

PGPASSWORD='CHANGE_ME_STRONG_PASSWORD' psql "postgresql://mission_control@192.168.1.150:5432/mission_control_dev" -c 'SELECT current_database(), current_user;'
PGPASSWORD='CHANGE_ME_STRONG_PASSWORD' psql "postgresql://mission_control@192.168.1.150:5432/mission_control_prod" -c 'SELECT current_database(), current_user;'

3) Kubernetes secret (recommended)

# Option A: direct command
kubectl -n development create secret generic mission-control-postgres \
  --from-literal=password='CHANGE_ME_STRONG_PASSWORD' \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n production create secret generic mission-control-postgres \
  --from-literal=password='CHANGE_ME_STRONG_PASSWORD' \
  --dry-run=client -o yaml | kubectl apply -f -

# Option B: from .env file
# Create a local file (do not commit):
#   PG_PASSWORD=CHANGE_ME_STRONG_PASSWORD
kubectl -n development create secret generic mission-control-postgres \
  --from-env-file=.env \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n production create secret generic mission-control-postgres \
  --from-env-file=.env \
  --dry-run=client -o yaml | kubectl apply -f -

IMPORTANT for Option B:
- Chart expects key name: password
- So either name it 'password=...' in your env file, or map key accordingly in values.

4) Deploy

# Dev
helm upgrade --install mission-control-dev ./charts/mission-control \
  -n development --create-namespace \
  -f ./charts/mission-control/values-dev.yaml

# Prod
helm upgrade --install mission-control-prod ./charts/mission-control \
  -n production --create-namespace \
  -f ./charts/mission-control/values-prod.yaml
