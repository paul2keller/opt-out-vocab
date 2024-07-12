#!/bin/bash

# add x for debugging
set -eu

# define the docker containers
AD_DOCKER_IMG=asciidoctor/docker-asciidoctor
PD_DOCKER_IMG=pandoc/core

#detect platform that we're running on...
unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    *)          machine="UNKNOWN:${unameOut}"
esac

# make sure we have an output dir
mkdir -p output

# check the current path
# and get its parent
CURRENT_PATH=`pwd`
echo "CURRENT_PATH = ${CURRENT_PATH}"
if [ "${machine}" == "MinGw" ]; then
	CURRENT_PATH=/`pwd`
fi
PARENT_PATH="$(dirname "${CURRENT_PATH}")"
# echo "Parent = $PARENT_PATH"


# this is the core routine to process one file...
convertOne() {
	# make sure we have the docker images
	if [[ "$(docker images -q "${AD_DOCKER_IMG}" 2> /dev/null)" == "" ]]; then
		echo "Pulling AsciiDoc Docker image"
		docker pull "${AD_DOCKER_IMG}"
	fi

	# compute the base name
	filename=$(basename -- "$1")
	extension="${filename##*.}"
	filename="${filename%.*}"
	BASE_NAME=$filename
	# echo "BaseName = $BASE_NAME"

	# Create the HTML version
	echo "Converting "${BASE_NAME}".adoc to HTML"
	docker run --rm -v "${CURRENT_PATH}":"${CURRENT_PATH}" -w "${CURRENT_PATH}" \
			-v "${CURRENT_PATH}/fonts":"${CURRENT_PATH}/fonts"	\
			"${AD_DOCKER_IMG}" asciidoctor \
			--backend html5 \
			-D ./output \
			-a data-uri \
			-o "${BASE_NAME}".html "${BASE_NAME}".adoc	

	# Create the PDF version
	echo "Converting "${BASE_NAME}".adoc to PDF"
	docker run --rm -v "${CURRENT_PATH}":"${CURRENT_PATH}" -w "${CURRENT_PATH}" \
			-v "${CURRENT_PATH}/fonts":"${CURRENT_PATH}/fonts"	\
			"${AD_DOCKER_IMG}" asciidoctor-pdf -r asciidoctor-diagram \
			--backend=pdf \
			-D ./output \
			-a data-uri \
			-a pdf-theme="${BASE_NAME}"-theme.yml \
			-a pdf-fontsdir="fonts"  \
			-o "${BASE_NAME}".pdf "${BASE_NAME}".adoc	

	# This doesn't work as noted at https://github.com/asciidoctor/docker-asciidoctor/issues/430	
	# 	when that issue is resolved, we'll switch to this much better method for EPUB creation!
	# Create the EPUB3 version
	# echo "Converting "${BASE_NAME}".adoc to EPUB3"
	# docker run --rm -v "${CURRENT_PATH}":"${CURRENT_PATH}" -w "${CURRENT_PATH}" \
	# 		"${AD_DOCKER_IMG}" asciidoctor-epub3 -r asciidoctor-diagram \
	# 		-D ./output \
	# 		-o "${BASE_NAME}".epub "${BASE_NAME}".adoc	

	# Create the DocBook versions
	echo "Converting "${BASE_NAME}".adoc to DocBook"
	docker run --rm -v "${CURRENT_PATH}":"${CURRENT_PATH}" -w "${CURRENT_PATH}" \
			"${AD_DOCKER_IMG}" asciidoctor -r asciidoctor-diagram \
			--backend=docbook5 \
			-D ./output  \
			-o "${BASE_NAME}".xml "${BASE_NAME}".adoc

	# Convert the DocBook to Word
	echo "Converting "${BASE_NAME}".xml to Word/docx"
	docker run --rm -v "${CURRENT_PATH}":"${CURRENT_PATH}" -w "${CURRENT_PATH}"/output \
			"${PD_DOCKER_IMG}" \
			-f docbook -t docx \
			-o "${BASE_NAME}".docx "${BASE_NAME}".xml

	# TEMP method for creating an EPUB...
	# Convert the DocBook to EPUB
	echo "Converting "${BASE_NAME}".xml to EPUB3"
	docker run --rm -v "${CURRENT_PATH}":"${CURRENT_PATH}" -w "${CURRENT_PATH}"/output \
			"${PD_DOCKER_IMG}" \
			-f docbook -t epub \
			-o "${BASE_NAME}".epub "${BASE_NAME}".xml
}

# process all the files	

convertOne "./OptOutVocab.adoc"

