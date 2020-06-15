#!/bin/bash

if [ ! -f "${1}" ]; then
	echo "Give a valid input file"
fi


#cat ${1} | sed 's/"type" : "text",/"type" : "text",\n"fielddata" : true,/g' > ${2}
cat ${1} | sed 's/"type" : "text",/"type" : "keyword",/g' > ${2}
sed -i "3d" ${2} 
sed -i "2d" ${2}
sed -i "$ d" ${2}
sed -i "$ d" ${2}
