# BAMCIS Presto Docker Containers

This repo contains Prestodb Docker Containers running both Alpine Linux and
Debian Linux using OpenJDK 8.

## Options

Both OS options contain two main environment variable options. The first is the **`ROLE`**
variable. This can be either `coordinator` or `worker` with the default being `worker`.
There should only be 1 coordinator node in the cluster.

The second option is the **`METASTORE_LOCATION`** variable. This can be either `local` or
`remote` with `local` being the default option. `Local` specifies that the 'experimental' 
local file metastore will be used. This has the advantage of not needing
to run a remote Hive metastore service, with the downside that the syntax and 
complexity Presto supports natively on building tables is not as robust as Hive.

The `remote` option requires you to include an additional environment variable,  
**`HIVE_METASTORE_URI`**. This is the url path to the Hive metastore service. This is the standard
and probably only "officially supported" configuration.

The containers were built for the express purpose of querying data stored in AWS S3
and/or HDFS and have the required catalog file for those connectors. It is also setup for
the files to be stored in AVRO format, which can be easily modified in the `hive.properties`
file. The entrypoint.sh script also contains all of the logic necessary to inject the 
required AWS Access Key and AWS Secret Key into the config files based on a `.env` file 
provided to the docker-compose.yml file. You could also supply these environment variables 
as part of a Kubernetes pod configuration.

## Configuration

Running the top-level `build.ps1` script will build the docker image. You will want to edit 
the `presto.env` file to include your AWS credentials if you are using S3, if you are just using HDFS, you
shouldn't need to make any changes. Update the max memory per node to fit your environment.

The docker containers default some properties inside the docker files.

* `query.max-memory` = 50GB (in config.properties, this is the max memory the cluster can use per query)
* `node.environment` = 'production' (in node.properties, this is the environment for the group of presto nodes)
* `com.facebook.presto` = 'INFO' (in log.properties, this is the log level)

These defaults are set in the dockerfile.

## Usage

* Run `.\build.ps1` in the presto-alpine or presto-debian directory
* Adjust the `docker-compose.yml` file to contain as many workers as desired, this defaults to 2
* Run `docker-compose up`
* Connect to the coordinator, find its Id with `docker ps -a`, then connect with `docker exec -it <containerid> /bin/bash`
* If using hive, the `docker-compose-with-hive.yml` can be used, but you will need to supply the docker container running
the hive metastore service. See my `bamcis/alpine-hive` or `bamcis/debian-hive` containers.