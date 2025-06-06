#!/bin/bash

declare -A municipio=()

>claims.txt

# ***********
# Preparación
# ***********

# Tabla de municipios y su id

municipio["A"]="Q16854742"
municipio["B"]="Q16854743"
municipio["C"]="Q16854744"
municipio["CH"]="Q16609541"
municipio["D"]="Q16854747"
municipio["E"]="Q16854748"
municipio["F"]="Q16854749"
municipio["G"]="Q16854750"

# ***************
# Consulta SPARQL
# ***************

# El archivo "buscar.rq" tiene la búsqueda SPARQL
# por ejemplo, para escuelas primarias en Montevideo
# 
# SELECT ?school ?schoolLabel ?coordinate ?location ?locationLabel ?adminRegion ?adminRegionLabel WHERE {
#   ?school wdt:P31 wd:Q9842;
#     wdt:P131 wd:Q16594;
#     wdt:P625 ?coordinate;
#     wdt:P276 ?location;
#     wdt:P131 ?adminRegion.
#   SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],es". }
# }
#
# No importa que haya campos adicionales, que pueden ser útiles
# a la hora de verificar si la consulta está bien y devuelve los
# elementos correctos. Como mínimo se necesita el id Q????? y las
# coordenadas.
# 
# IMPORTANTE: ajustar en la línea siguiente el tipo de elemento
#             (para la consulta de arriba es "school")

ELEMENTO=school

# ***********************
# Asignación de municipio
# ***********************
# La búsqueda y asignación se hacen con comandos de wikidata-cli
# (https://github.com/WikiDonne/wikidata-cli).
# la salida (en json) es filtrada para obtener las coordenadas. Como
# las coordenadas que usa el servidor WFS de la intendencia de Montevideo
# EPGS 3271 son diferentes a las "normales" (EPGS 4326 / WGS 84),
# es necesario hacer una conversión previa antes de obtener el
# municipio $long,$lat -> $immlong,$immlat
#
# Al terminar el programa, en el archivo claims.txt está la
# información que necesita "wd add-claim --batch"
# Si está todo bien, entonces con el comando:
#
#   cat claims.txt | wd add-claim --batch --summary "Resumen ..."
#
# se suben a Wikidata.


wd sparql buscar.rq | jq -r ".[] | \"\(.$ELEMENTO.value), \(.coordinate)\"" |
sed -r 's/^([0-9Q]+).*Point.([0-9\. -]+) ([0-9\. -]+).*/\1 \2 \3/g'|
while read q long lat
do
        read immlong immlat <<< $(echo $long $lat | cs2cs +init=EPSG:4326 +to +init=EPSG:32721 | awk '{print $1" "$2}')
	lugar="$immlong,$immlat"

	# esta es la consulta al geoserver de la intendencia

	mun=$(cat wfs_query.txt | sed "s/_COORDINATES_/$lugar/g" | 
	curl -s -X POST "https://montevideo.gub.uy/app/geoserver/mapstore-tematicas/zon_v_sig_municipios/wfs" \
	-H "Content-Type: text/xml" \
	--data @- | jq -r '.features[0].properties.municipio')

	echo "$q $long $lat $mun $immlong $immlat"
	if test -n $mun -a -n ${municipio[$mun]}
	then
		# wikidata-cli "add claim"
		 echo "$q P131 ${municipio[$mun]}" >> claims.txt
	fi

done


