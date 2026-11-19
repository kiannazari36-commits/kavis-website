#!/bin/sh
# Race test: two parallel uploads by the same trial student who already has 1 lesson. Only one may win.
# Usage: PSQL="docker exec -i supabase_db_kavis-study psql -U postgres -d <scratch db>" sh 51_trial_race.sh   (after 10_behaviour.sql etc.)
set -e
T=$(mktemp -d)
: "${PSQL:?set PSQL}"
U=00000000-0000-0000-0000-0000000000f1
$PSQL -q -c "insert into auth.users (id, email, raw_user_meta_data) values ('$U', 'f1@x', '{\"app_lang\":\"tr\"}'); insert into public.materials (user_id, kind, title) values ('$U', 'pdf', 'first');"
one() { $PSQL -q -c "begin; insert into public.materials (user_id, kind, title) values ('$U', 'pdf', '$1'); select pg_sleep(1); commit;" >/dev/null 2>&1 && echo ok || echo refused; }
( one A > $T/a ) & ( one B > $T/b ) & wait
r="$(cat $T/a $T/b | sort | tr '\n' ' ')"
rm -rf "$T"
n=$($PSQL -tAq -c "select lessons from public.trial_usage where user_id = '$U'")
echo "results: $r| trial lessons now: $n"
[ "$n" = "2" ] && echo "PASS parallel uploads cannot pass the trial limit" || { echo "FAIL trial lessons = $n"; exit 1; }
