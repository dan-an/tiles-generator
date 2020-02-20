all: build/openmaptiles.tm2source/data.yml build/mapping.yaml build/tileset.sql

help:
	@echo "=============================================================================="
	@echo " OpenMapTiles  https://github.com/openmaptiles/openmaptiles "
	@echo "Hints for testing areas                "
	@echo "  make download-geofabrik-list         # list actual geofabrik OSM extracts for download -> <<your-area>> "
	@echo "  make list                            # list actual geofabrik OSM extracts for download -> <<your-area>> "
	@echo "  ./quickstart.sh <<your-area>>        # example:  ./quickstart.sh madagascar "
	@echo "  "
	@echo "Hints for designers:"
	@echo "  make start-postserve                 # start Postserver + Maputnik Editor [ see localhost:8088 ] "
	@echo "  make start-tileserver                # start klokantech/tileserver-gl [ see localhost:8080 ] "
	@echo "  "
	@echo "Hints for developers:"
	@echo "  make                                 # build source code"
	@echo "  make download-geofabrik area=albania # download OSM data from geofabrik, and create config file"
	@echo "  make psql                            # start PostgreSQL console"
	@echo "  make psql-list-tables                # list all PostgreSQL tables"
	@echo "  make psql-vacuum-analyze             # PostgreSQL: VACUUM ANALYZE"
	@echo "  make psql-analyze                    # PostgreSQL: ANALYZE"
	@echo "  make generate-qareports              # generate reports [./build/qareports]"
	@echo "  make generate-devdoc                 # generate devdoc including graphs for all layers  [./build/devdoc]"
	@echo "  make etl-graph                       # hint for generating a single etl graph"
	@echo "  make mapping-graph                   # hint for generating a single mapping graph"
	@echo "  make import-sql-dev                  # start import-sql /bin/bash terminal"
	@echo "  make import-osm-dev                  # start import-osm /bin/bash terminal (imposm3)"
	@echo "  make clean-docker                    # remove docker containers, PG data volume"
	@echo "  make forced-clean-sql                # drop all PostgreSQL tables for clean environment"
	@echo "  make docker-unnecessary-clean        # clean unnecessary docker image(s) and container(s)"
	@echo "  make refresh-docker-images           # refresh openmaptiles docker images from Docker HUB"
	@echo "  make remove-docker-images            # remove openmaptiles docker images"
	@echo "  make pgclimb-list-views              # list PostgreSQL public schema views"
	@echo "  make pgclimb-list-tables             # list PostgreSQL public schema tables"
	@echo "  cat  .env                            # list PG database and MIN_ZOOM and MAX_ZOOM information"
	@echo "  cat  quickstart.log                  # backup of the last ./quickstart.sh"
	@echo "  make help                            # help about available commands"
	@echo "=============================================================================="

build:
	mkdir -p build

build/openmaptiles.tm2source/data.yml: build
	mkdir -p build/openmaptiles.tm2source
	docker-compose run --rm openmaptiles-tools generate-tm2source openmaptiles.yaml --host="postgres" --port=5432 --database="openmaptiles" --user="openmaptiles" --password="openmaptiles" > build/openmaptiles.tm2source/data.yml

build/mapping.yaml: build
	docker-compose run --rm openmaptiles-tools generate-imposm3 openmaptiles.yaml > build/mapping.yaml

build/tileset.sql: build
	docker-compose run --rm openmaptiles-tools generate-sql openmaptiles.yaml > build/tileset.sql

clean:
	rm -f build/openmaptiles.tm2source/data.yml && rm -f build/mapping.yaml && rm -f build/tileset.sql

clean-docker:
	docker-compose down -v --remove-orphans
	docker-compose rm -fv
	docker volume ls -q | grep openmaptiles  | xargs -r docker volume rm || true

db-start:
	docker-compose up   -d postgres

download-geofabrik:
	@echo ===============  download-geofabrik =======================
	@echo Download area :   $(area)
	@echo [[ example: make download-geofabrik  area=albania ]]
	@echo [[ list areas:  make download-geofabrik-list       ]]
	docker-compose run --rm import-osm  ./download-geofabrik.sh $(area)
	ls -la ./data/$(area).*
	@echo "Generated config file: ./data/docker-compose-config.yml"
	@echo " "
	cat ./data/docker-compose-config.yml
	@echo " "

psql: db-start
	docker-compose run --rm import-osm /usr/src/app/psql.sh

import-osm: db-start all
	docker-compose run --rm import-osm

import-sql: db-start all
	docker-compose run --rm import-sql

import-osmsql: db-start all
	docker-compose run --rm import-osm
	docker-compose run --rm import-sql

generate-tiles: db-start all
	rm -rf data/tiles.mbtiles
	if [ -f ./data/docker-compose-config.yml ]; then \
		docker-compose -f docker-compose.yml -f ./data/docker-compose-config.yml run --rm generate-vectortiles; \
	else \
		docker-compose run --rm generate-vectortiles; \
	fi
	docker-compose run --rm openmaptiles-tools  generate-metadata ./data/tiles.mbtiles
	docker-compose run --rm openmaptiles-tools  chmod 666         ./data/tiles.mbtiles


start-tileserver:
	@echo " "
	@echo "***********************************************************"
	@echo "* "
	@echo "* Download/refresh klokantech/tileserver-gl docker image"
	@echo "* see documentation: https://github.com/klokantech/tileserver-gl"
	@echo "* "
	@echo "***********************************************************"
	@echo " "
	docker pull klokantech/tileserver-gl
	@echo " "
	@echo "***********************************************************"
	@echo "* "
	@echo "* Start klokantech/tileserver-gl "
	@echo "*       ----------------------------> check localhost:8080 "
	@echo "* "
	@echo "***********************************************************"
	@echo " "
	docker run -it --rm --name tileserver-gl -v $$(pwd)/data:/data -p 8080:80 klokantech/tileserver-gl

start-postserve:
	@echo " "
	@echo "***********************************************************"
	@echo "* "
	@echo "* Bring up postserve at localhost:8090/tiles/{z}/{x}/{y}.pbf"
	@echo "* "
	@echo "***********************************************************"
	@echo " "
	docker-compose up -d postserve
	docker pull maputnik/editor
	@echo " "
	@echo "***********************************************************"
	@echo "* "
	@echo "* Start maputnik/editor "
	@echo "*       ----------------------------> check localhost:8088 "
	@echo "* "
	@echo "***********************************************************"
	@echo " "
	docker rm -f maputnik_editor || true
	docker run --name maputnik_editor -d -p 8088:8888 maputnik/editor

generate-qareports:
	./qa/run.sh

build/devdoc:
	mkdir -p ./build/devdoc

layers = $(notdir $(wildcard layers/*)) # all layers

etl-graph:
	@echo 'Use'
	@echo '   make etl-graph-[layer]	to generate etl graph for [layer]'
	@echo '   example: make etl-graph-poi'
	@echo 'Valid layers: $(layers)'

# generate etl graph for a certain layer, e.g. etl-graph-building, etl-graph-place
etl-graph-%: layers/% build/devdoc
	docker run --rm -v $$(pwd):/tileset openmaptiles/openmaptiles-tools generate-etlgraph layers/$*/$*.yaml ./build/devdoc

mappingLayers = $(notdir $(patsubst %/mapping.yaml,%, $(wildcard layers/*/mapping.yaml))) # layers with mapping.yaml

# generate mapping graph for a certain layer, e.g. mapping-graph-building, mapping-graph-place
mapping-graph:
	@echo 'Use'
	@echo '   make mapping-graph-[layer]	to generate mapping graph for [layer]'
	@echo '   example: make mapping-graph-poi'
	@echo 'Valid layers: $(mappingLayers)'

mapping-graph-%: ./layers/%/mapping.yaml build/devdoc
	docker run --rm -v $$(pwd):/tileset openmaptiles/openmaptiles-tools generate-mapping-graph layers/$*/$*.yaml ./build/devdoc/mapping-diagram-$*

# generate all etl and mapping graphs
generate-devdoc: $(addprefix etl-graph-,$(layers)) $(addprefix mapping-graph-,$(mappingLayers))

import-sql-dev:
	docker-compose run --rm import-sql /bin/bash

import-osm-dev:
	docker-compose run --rm import-osm /bin/bash

# the `download-geofabrik` error message mention `list`, if the area parameter is wrong. so I created a similar make command
list:
	docker-compose run --rm import-osm  ./download-geofabrik-list.sh

# same as a `make list`
download-geofabrik-list:
	docker-compose run --rm import-osm  ./download-geofabrik-list.sh

download-wikidata:
	mkdir -p wikidata && docker-compose run --rm --entrypoint /usr/src/app/download-gz.sh import-wikidata

psql-list-tables:
	docker-compose run --rm import-osm /usr/src/app/psql.sh  -P pager=off  -c "\d+"

psql-pg-stat-reset:
	docker-compose run --rm import-osm /usr/src/app/psql.sh  -P pager=off  -c 'SELECT pg_stat_statements_reset();'

forced-clean-sql:
	docker-compose run --rm import-osm /usr/src/app/psql.sh -c "DROP SCHEMA IF EXISTS public CASCADE ; CREATE SCHEMA IF NOT EXISTS public; "
	docker-compose run --rm import-osm /usr/src/app/psql.sh -c "CREATE EXTENSION hstore; CREATE EXTENSION postgis; CREATE EXTENSION unaccent; CREATE EXTENSION fuzzystrmatch; CREATE EXTENSION osml10n; CREATE EXTENSION pg_stat_statements;"
	docker-compose run --rm import-osm /usr/src/app/psql.sh -c "GRANT ALL ON SCHEMA public TO public;COMMENT ON SCHEMA public IS 'standard public schema';"

pgclimb-list-views:
	docker-compose run --rm import-osm /usr/src/app/pgclimb.sh -c "select schemaname,viewname from pg_views where schemaname='public' order by viewname;" csv

pgclimb-list-tables:
	docker-compose run --rm import-osm /usr/src/app/pgclimb.sh -c "select schemaname,tablename from pg_tables where schemaname='public' order by tablename;" csv

psql-vacuum-analyze:
	@echo "Start - postgresql: VACUUM ANALYZE VERBOSE;"
	docker-compose run --rm import-osm /usr/src/app/psql.sh  -P pager=off  -c 'VACUUM ANALYZE VERBOSE;'

psql-analyze:
	@echo "Start - postgresql: ANALYZE VERBOSE ;"
	docker-compose run --rm import-osm /usr/src/app/psql.sh  -P pager=off  -c 'ANALYZE VERBOSE;'

list-docker-images:
	docker images | grep openmaptiles

refresh-docker-images:
	docker-compose pull --ignore-pull-failures

remove-docker-images:
	@echo "Deleting all openmaptiles related docker image(s)..."
	@docker-compose down
	@docker images | grep "openmaptiles" | awk -F" " '{print $$3}' | xargs --no-run-if-empty docker rmi -f
	@docker images | grep "osm2vectortiles/mapbox-studio" | awk -F" " '{print $$3}' | xargs --no-run-if-empty docker rmi -f
	@docker images | grep "klokantech/tileserver-gl"      | awk -F" " '{print $$3}' | xargs --no-run-if-empty docker rmi -f

docker-unnecessary-clean:
	@echo "Deleting unnecessary container(s)..."
	@docker ps -a  | grep Exited | awk -F" " '{print $$1}' | xargs  --no-run-if-empty docker rm
	@echo "Deleting unnecessary image(s)..."
	@docker images | grep \<none\> | awk -F" " '{print $$3}' | xargs  --no-run-if-empty  docker rmi
