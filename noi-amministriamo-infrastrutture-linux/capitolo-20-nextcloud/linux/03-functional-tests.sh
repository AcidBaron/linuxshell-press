#!/usr/bin/env bash
set -euo pipefail

USER_NAME=ncuser01
USER_PASS='provadipasswordnextcloud' # LAB ONLY

printf 'Capitolo 20 - test Nextcloud\n' > ~/nextcloud-test.txt
curl --fail-with-body -u "${USER_NAME}:${USER_PASS}" -T ~/nextcloud-test.txt \
    "https://nextcloud.lab.test/remote.php/dav/files/${USER_NAME}/nextcloud-test.txt"
curl --fail-with-body -u "${USER_NAME}:${USER_PASS}" -o ~/nextcloud-test.downloaded.txt \
    "https://nextcloud.lab.test/remote.php/dav/files/${USER_NAME}/nextcloud-test.txt"
cmp ~/nextcloud-test.txt ~/nextcloud-test.downloaded.txt
echo 'UPLOAD/DOWNLOAD: OK'

curl --fail-with-body \
    -u "${USER_NAME}:${USER_PASS}" \
    -H 'OCS-APIRequest: true' \
    -H 'Accept: application/json' \
    -X POST \
    https://nextcloud.lab.test/ocs/v2.php/apps/files_sharing/api/v1/shares \
    --data-urlencode 'path=/nextcloud-test.txt' \
    --data 'shareType=3'
