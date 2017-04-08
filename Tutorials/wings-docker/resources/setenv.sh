#!/bin/bash

echo "export WINGS_MODE='dind'" > /usr/share/tomcat8/bin/setenv.sh
env | grep DOCKER | sed -e 's/^/export /' >> /usr/share/tomcat8/bin/setenv.sh

#`docker inspect --format='{{range $p, $conf := .Config.Env}}{{(index $conf)}}
#{{end}}' wings | grep DOCKER | sed -e 's/^/export /'`
#rm --force /opt/wings/storage/default/TDB/{tdb.lock,journal.jrnl}
