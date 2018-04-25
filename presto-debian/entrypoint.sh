#!/bin/bash

echo "Starting Presto ${ROLE}."

source /home/"${PRESTO_USER}"/.bashrc

UUID=$(cat /proc/sys/kernel/random/uuid)

# node.properties
# Configure the name of the environment, should be the same for every node in the cluster
# Also, set a unique id for this node and set the data dir
sed -i "s/{{PRESTO_ENVIRONMENT}}/${PRESTO_ENVIRONMENT}/g; s/{{PRESTO_UUID}}/${UUID}/g; s|{{PRESTO_DATA_DIR}}|${PRESTO_DATA}|g; s|{{PRESTO_SERVER_LOG}}|${PRESTO_LOGS}/server.log|g; s|{{PRESTO_LAUNCHER_LOG}}|${PRESTO_LOGS}/launcher.log|g" "${PRESTO_HOME}/etc/node.properties"

cat "${PRESTO_HOME}/etc/node.properties"

# Configure config.properties
# Copy the appropriate config.properties file

DISCOVERY_URI=""

case ${ROLE,,} in
	"coordinator")
		/bin/cp -f "${PRESTO_HOME}/etc/config.properties.coordinator" "${PRESTO_HOME}/etc/config.properties"
		DISCOVERY_URI="http://${HOSTNAME}:${PRESTO_PORT}"
	;;
	"worker" | *)
		/bin/cp -f "${PRESTO_HOME}/etc/config.properties.worker" "${PRESTO_HOME}/etc/config.properties"
		DISCOVERY_URI="${PRESTO_DISCOVERY_SERVER}"
	;;
esac

# Update the memory, port, and discovery uri
sed -i "s/{{MAX_MEMORY}}/${PRESTO_MAX_MEMORY}/g; s/{{MAX_MEMORY_PER_NODE}}/${PRESTO_MAX_MEMORY_PER_NODE}/g; s/{{PRESTO_PORT}}/${PRESTO_PORT}/g; s|{{DISCOVERY_URI}}|${DISCOVERY_URI}|g" "${PRESTO_HOME}/etc/config.properties"
cat "${PRESTO_HOME}/etc/config.properties"

# Since the AWS access key info could change, 
# load core-site.xml from a template each time
if [ -e "${PRESTO_HOME}/etc/core-site.xml.template" ]; then
	/bin/cp -f "${PRESTO_HOME}/etc/core-site.xml.template" "${PRESTO_HOME}/etc/core-site.xml"
else
	/bin/cp -f "${PRESTO_HOME}/etc/core-site.xml" "${PRESTO_HOME}/etc/core-site.xml.template"
fi

# Set the core-site.xml
sed -i "s/{{AWS_ACCESS_KEY}}/${AWS_ACCESS_KEY}/g; s/{{AWS_SECRET_KEY}}/${AWS_SECRET_KEY}/g" "${PRESTO_HOME}/etc/core-site.xml"

HIVE_TEMPLATE_PATH=""
HIVE_REPLACEMENT=""

case ${METASTORE_LOCATION,,} in
	"remote")
		HIVE_TEMPLATE_PATH="${PRESTO_HOME}/etc/catalog/hive.properties.remote"

		HIVE_HOST_PORT=$(echo "${HIVE_METASTORE_URI}" | cut -d "/" -f3)
		# Do this in case there is no path after host, so this trims the port off if it's there
		# If there was a path, it's already trimmed by cut
		HIVE_HOST=$(echo "${HIVE_HOST_PORT}" | cut -d ":" -f1)
		HIVE_PORT=$(echo "${HIVE_METASTORE_URI}" | cut -d ":" -f3)
		HIVE_IP=$(getent ahosts "${HIVE_HOST}" | awk 'NR==1{ print $1 }')

		# Substitute the host name for resolved IP address right now since docker's DNS
		# isn't being used by the Presto code
		HIVE_REPLACEMENT=$(echo "${HIVE_METASTORE_URI}" | sed -e "s/${HIVE_HOST}/${HIVE_IP}/g")

		# Based on a thrift://hostname:port
		# Make sure HIVE is running before starting Presto
		until nc -z -v -w60 "${HIVE_HOST}" "${HIVE_PORT}"
		do
			echo "Waiting for hive metastore connectivity to be available at ${METASTORE_URL}..."
			# wait for 5 seconds before check again
			sleep 5
		done
	;;
	"local" | *)
		HIVE_TEMPLATE_PATH="${PRESTO_HOME}/etc/catalog/hive.properties.local"
		HIVE_REPLACEMENT="${PRESTO_HIVE_CATALOG}"
	;;
esac

# Since the AWS access key info could change, 
# load the hive.properties from a template each time
if [ -e "${HIVE_TEMPLATE_PATH}" ]; then
	/bin/cp -f "${HIVE_TEMPLATE_PATH}" "${PRESTO_HOME}/etc/catalog/hive.properties"
else
	/bin/cp -f "${PRESTO_HOME}/etc/catalog/hive.properties" $HIVE_TEMPLATE_PATH
fi

# Set the hive connector config
sed -i "s|{{PRESTO_HOME}}|${PRESTO_HOME}|g; s|{{HIVE_DATA}}|${HIVE_REPLACEMENT}|g; s|{{HIVE_USER}}|${PRESTO_USER}|g; s/{{AWS_ACCESS_KEY}}/${AWS_ACCESS_KEY}/g; s/{{AWS_SECRET_KEY}}/${AWS_SECRET_KEY}/g; s|{{AWS_S3_ENDPOINT}}|${AWS_S3_ENDPOINT}|g" "${PRESTO_HOME}/etc/catalog/hive.properties"

cat "${PRESTO_HOME}/etc/catalog/hive.properties"

# Start the presto server as the presto user
su -l "${PRESTO_USER}" -c "source /home/${PRESTO_USER}/.bashrc"
su -l "${PRESTO_USER}" -c "${PRESTO_HOME}/bin/launcher run"