#!/usr/bin/env bash

function setProperty() {
  local configPath=$1
  local placeholder=$2
  local value=$3
  sed -i "s|${placeholder}|${value}|" $configPath
}

setProperty openmaptiles.yaml "\$BBOX" "$BBOX"
setProperty openmaptiles.yaml "\$MIN_ZOOM" "$MIN_ZOOM"
setProperty openmaptiles.yaml "\$MAX_ZOOM" "$MAX_ZOOM"

if [ -n "$OSM_AREA_NAME" ] && [ -n "$PREBUILD" ]; then
    if [ $PREBUILD == "true" ]; then
        make
    fi

    ./quickstart.sh $OSM_AREA_NAME

fi

#if [ -n "$SRC_MBTILES" ] && [ -n "$DST_MBTILES" ]; then
#    ./merge-mbtiles /app/tiles/$SRC_MBTILES /app/tiles/$DST_MBTILES
#fi
