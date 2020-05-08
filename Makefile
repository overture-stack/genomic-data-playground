.PHONY:

# Required System files
DOCKER_COMPOSE_EXE := $(shell which docker-compose)
CURL_EXE := $(shell which curl)

# Variables
ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
MY_UID := $$(id -u)
MY_GID := $$(id -g)
THIS_USER := $(MY_UID):$(MY_GID)
ACCESS_TOKEN := f69b726d-d40f-4261-b105-1ec7e6bf04d5
PROJECT_NAME := $(shell echo $(ROOT_DIR) | sed 's/.*\///g')

# STDOUT Formatting
RED := $$(echo  "\033[0;31m")
YELLOW := $$(echo "\033[0;33m")
END := $$(echo  "\033[0m")
ERROR_HEADER :=  [ERROR]:
INFO_HEADER := "**************** "
DONE_MESSAGE := $(YELLOW)$(INFO_HEADER) "- done\n" $(END)

# Paths
SCRATCH_DIR := $(ROOT_DIR)/scratch/
RETRY_CMD := $(ROOT_DIR)/retry-command.sh
SCORE_SERVER_LOGS_DIR := $(SCRATCH_DIR)/score-server-logs
SCORE_CLIENT_LOGS_DIR := $(SCRATCH_DIR)/score-client-logs
SONG_SERVER_LOGS_DIR  := $(SCRATCH_DIR)/song-server-logs
SONG_CLIENT_LOGS_DIR  := $(SCRATCH_DIR)/song-client-logs
SCORE_CLIENT_LOG_FILE := $(SCORE_CLIENT_LOGS_DIR)/client.log
SONG_CLIENT_OUTPUT_DIR := $(SCRATCH_DIR)/song-client-output
SCORE_CLIENT_OUTPUT_DIR := $(SCRATCH_DIR)/score-client-output
SONG_CLIENT_ANALYSIS_ID_FILE_1 := $(SONG_CLIENT_OUTPUT_DIR)/analysisId1.txt
SONG_CLIENT_ANALYSIS_ID_FILE_2 := $(SONG_CLIENT_OUTPUT_DIR)/analysisId2.txt
SONG_CLIENT_ANALYSIS_ID_FILE_3 := $(SONG_CLIENT_OUTPUT_DIR)/analysisId3.txt
SONG_CLIENT_ANALYSIS_ID_FILE_4 := $(SONG_CLIENT_OUTPUT_DIR)/analysisId4.txt
SONG_CLIENT_SUBMIT_RESPONSE_FILE_1 := $(SONG_CLIENT_OUTPUT_DIR)/submit_response1.json
SONG_CLIENT_SUBMIT_RESPONSE_FILE_2:= $(SONG_CLIENT_OUTPUT_DIR)/submit_response2.json
SONG_CLIENT_SUBMIT_RESPONSE_FILE_3 := $(SONG_CLIENT_OUTPUT_DIR)/submit_response3.json
SONG_CLIENT_SUBMIT_RESPONSE_FILE_4 := $(SONG_CLIENT_OUTPUT_DIR)/submit_response4.json


OUTPUT_DIRS := $(SONG_CLIENT_OUTPUT_DIR) $(SCORE_CLIENT_OUTPUT_DIR)
LOG_DIRS := $(SCORE_SERVER_LOGS_DIR) $(SCORE_CLIENT_LOGS_DIR) $(SONG_SERVER_LOGS_DIR) $(SONG_CLIENT_LOGS_DIR)


# Commands
DOCKER_COMPOSE_CMD := MY_UID=$(MY_UID) MY_GID=$(MY_GID) $(DOCKER_COMPOSE_EXE) -f $(ROOT_DIR)/docker-compose.yml
SONG_CLIENT_CMD := $(DOCKER_COMPOSE_CMD) run --rm -u $(THIS_USER) song-client java --illegal-access=deny -Dlog.name=song -Dlog.path=/song-client/logs -Dlogback.configurationFile=/song-client/conf/logback.xml -jar /song-client/lib/song-client.jar /song-client/conf/application.yml
SCORE_CLIENT_CMD := $(DOCKER_COMPOSE_CMD) run --rm -u $(THIS_USER) score-client bin/score-client
DC_UP_CMD := $(DOCKER_COMPOSE_CMD) up -d --build

#############################################################
# Internal Targets
#############################################################
$(SCORE_CLIENT_LOG_FILE):
	@mkdir -p $(SCORE_CLIENT_LOGS_DIR)
	@touch $(SCORE_CLIENT_LOGS_DIR)/client.log
	@chmod 777 $(SCORE_CLIENT_LOG_FILE)

_ping_score_server:
	@echo $(YELLOW)$(INFO_HEADER) "Pinging score-server on http://localhost:8087" $(END)
	@$(RETRY_CMD) curl  \
		-XGET \
		--header "Authorization: Bearer f69b726d-d40f-4261-b105-1ec7e6bf04d5" \
		"http://localhost:8087/download/ping"
	@echo ""

_ping_song_server:
	@echo $(YELLOW)$(INFO_HEADER) "Pinging song-server on http://localhost:8080" $(END)
	@$(RETRY_CMD) curl --connect-timeout 5 \
		--max-time 10 \
		--retry 5 \
		--retry-delay 0 \
		--retry-max-time 40 \
		--retry-connrefuse \
		'http://localhost:8080/isAlive'
	@echo ""

_ping_elasticsearch_server:
	@echo $(YELLOW)$(INFO_HEADER) "Pinging ElasticSearch on http://localhost:9200" $(END)
	@$(RETRY_CMD) curl --retry 10 \
    --retry-delay 0 \
    --retry-max-time 40 \
    --retry-connrefuse \
    'localhost:9200/_cluster/health?wait_for_status=yellow&timeout=100s&wait_for_active_shards=all&wait_for_no_initializing_shards=true'
	@echo ""

KIBANA_STATUS = $$(if [[ "$$(curl -X GET --max-time 15 --retry 10 --retry-delay 5 --retry-max-time 40 --retry-connrefuse http://localhost:5601/status -I 2> /dev/null | head -n1 | awk '{ print $$3 }')" = "OK"* ]]; then echo "true"; else exit 1; fi )

_ping_kibana: SHELL:=/bin/bash
_ping_kibana:
	@echo -e $(YELLOW)$(INFO_HEADER) "Pinging kibana on http://localhost:5601" $(END)
	@$(RETRY_CMD) $(KIBANA_STATUS)
	@echo ""

_setup-object-storage: 
	@echo $(YELLOW)$(INFO_HEADER) "Setting up bucket oicr.icgc.test and heliograph" $(END)
	@if  $(DOCKER_COMPOSE_CMD) run aws-cli --endpoint-url http://object-storage:9000 s3 ls s3://oicr.icgc.test ; then \
		echo $(YELLOW)$(INFO_HEADER) "Bucket already exists. Skipping creation..." $(END); \
	else \
		$(DOCKER_COMPOSE_CMD) run aws-cli --endpoint-url http://object-storage:9000 s3 mb s3://oicr.icgc.test; \
	fi
	@$(DOCKER_COMPOSE_CMD) run aws-cli --endpoint-url http://object-storage:9000 s3 cp /score-data/heliograph s3://oicr.icgc.test/data/heliograph

_destroy-object-storage:
	@echo $(YELLOW)$(INFO_HEADER) "Removing bucket oicr.icgc.test" $(END)
	@if  $(DOCKER_COMPOSE_CMD) run aws-cli --endpoint-url http://object-storage:9000 s3 ls s3://oicr.icgc.test ; then \
		$(DOCKER_COMPOSE_CMD) run aws-cli --endpoint-url http://object-storage:9000 s3 rb s3://oicr.icgc.test --force; \
	else \
		echo $(YELLOW)$(INFO_HEADER) "Bucket does not exist. Skipping..." $(END); \
	fi

_setup: init-log-dirs init-output-dirs $(SCORE_CLIENT_LOG_FILE)

#############################################################
# Help
#############################################################

# Help menu, displaying all available targets
help:
	@echo
	@echo "**************************************************************"
	@echo "**************************************************************"
	@echo "To dry-execute a target run: make -n <target> "
	@echo
	@echo "Available Targets: "
	@grep '^[A-Za-z][A-Za-z0-9_-]\+:.*' $(ROOT_DIR)/Makefile | sed 's/:.*//' | sed 's/^/\t/'
	@echo

#############################################################
#  Cleaning targets
#############################################################

# Kills running services and removes created files/directories
clean-docker:
	@echo $(YELLOW)$(INFO_HEADER) "Destroying running docker services" $(END)
	@$(DOCKER_COMPOSE_CMD) down -v

# Delete all objects from object storage
clean-objects: _destroy-object-storage

clean-log-dirs:
	@echo $(YELLOW)$(INFO_HEADER) "Cleaning log directories" $(END);
	@rm -rf $(OUTPUT_DIRS)

clean-output-dirs:
	@echo $(YELLOW)$(INFO_HEADER) "Cleaning output directories" $(END);
	@rm -rf $(LOG_DIRS)

# Clean everything. Kills all services, maven cleans and removes generated files/directories
clean: clean-docker clean-log-dirs clean-output-dirs

#############################################################
#  Building targets
#############################################################

init-output-dirs:
	@echo $(YELLOW)$(INFO_HEADER) "Initializing output directories" $(END);
	@mkdir -p $(OUTPUT_DIRS)

init-log-dirs:
	@echo $(YELLOW)$(INFO_HEADER) "Initializing log directories" $(END);
	@mkdir -p $(LOG_DIRS)

#############################################################
#  Docker targets
#############################################################

# Start ego, song, score, and object-storage.
start-storage-services: _setup
	@echo $(YELLOW)$(INFO_HEADER) "Starting the following services: ego, score, song, score and object-storage" $(END)
	@$(DC_UP_CMD) ego-server score-server song-server object-storage
	@$(MAKE) _ping_song_server
	@$(MAKE) _ping_score_server
	@$(MAKE) _setup-object-storage
	@echo $(YELLOW)$(INFO_HEADER) Succesfully started services! $(END)

# Start maestro, elasticsearch, zookeeper, kafka, and the rest proxy
start-maestro-services:
	@echo $(YELLOW)$(INFO_HEADER) "Starting the following services: arranger, maestro, elasticsearch, zookeeper, kafka, and the rest proxy" $(END)
	@$(DC_UP_CMD) arranger-ui maestro rest-proxy
	@$(MAKE) _ping_elasticsearch_server
	@$(MAKE) _ping_kibana
	@echo $(YELLOW)$(INFO_HEADER) Succesfully started services! $(END)

start-maestro-services-and-indexing: start-maestro-services
	@$(CURL_EXE) -X POST http://localhost:11235/index/repository/local_song -H 'Content-Type: application/json' -H 'cache-control: no-cache'
	@echo $(YELLOW)$(INDO_HEADER) The indexing of song files has been launched! $(END)

start-services: start-storage-services
	@$(MAKE) start-maestro-services-and-indexing

#############################################################
#  Logging Targets
#############################################################
show-song-server-logs:
	@echo $(YELLOW)$(INFO_HEADER) "Showing logs for song-server" $(END)
	@$(DOCKER_COMPOSE_CMD) logs song-server
	@echo $(DONE_MESSAGE)

show-score-server-logs:
	@echo $(YELLOW)$(INFO_HEADER) "Showing logs for score-server" $(END)
	@$(DOCKER_COMPOSE_CMD) logs score-server
	@echo $(DONE_MESSAGE)


#############################################################
#  Client targets
#############################################################

GET_ANALYSIS_ID_CMD_1 := cat $(SONG_CLIENT_ANALYSIS_ID_FILE_1)
GET_ANALYSIS_ID_CMD_2 := cat $(SONG_CLIENT_ANALYSIS_ID_FILE_2)
GET_ANALYSIS_ID_CMD_3 := cat $(SONG_CLIENT_ANALYSIS_ID_FILE_3)
GET_ANALYSIS_ID_CMD_4 := cat $(SONG_CLIENT_ANALYSIS_ID_FILE_4)

get-analysis-id_1:
	@echo "The cached analysisId is " $$($(GET_ANALYSIS_ID_CMD_1))

get-analysis-id_2:
	@echo "The cached analysisId is " $$($(GET_ANALYSIS_ID_CMD_2))

get-analysis-id_3:
	@echo "The cached analysisId is " $$($(GET_ANALYSIS_ID_CMD_3))

get-analysis-id_4:
	@echo "The cached analysisId is " $$($(GET_ANALYSIS_ID_CMD_4))

test-submit: test-submit_1

test-submit_1: start-storage-services
	@echo $(YELLOW)$(INFO_HEADER) "Submitting payload /song-client/input/exampleVariantCall.json" $(END)
	@$(SONG_CLIENT_CMD) submit -f /song-client/input/exampleVariantCall.json | tee $(SONG_CLIENT_SUBMIT_RESPONSE_FILE_1)
	@cat $(SONG_CLIENT_SUBMIT_RESPONSE_FILE_1) | grep analysisId | sed 's/.*://' | sed 's/"\|,//g'  > $(SONG_CLIENT_ANALYSIS_ID_FILE_1)
	@echo $(YELLOW)$(INFO_HEADER) "Successfully submitted. Cached analysisId: " $$($(GET_ANALYSIS_ID_CMD_1)) $(END)

test-submit_2: start-storage-services
	@echo $(YELLOW)$(INFO_HEADER) "Submitting payload /song-client/input/exampleVariantCall2.json" $(END)
	@$(SONG_CLIENT_CMD) submit -f /song-client/input/exampleVariantCall2.json | tee $(SONG_CLIENT_SUBMIT_RESPONSE_FILE_2)
	@cat $(SONG_CLIENT_SUBMIT_RESPONSE_FILE_2) | grep analysisId | sed 's/.*://' | sed 's/"\|,//g'  > $(SONG_CLIENT_ANALYSIS_ID_FILE_2)
	@echo $(YELLOW)$(INFO_HEADER) "Successfully submitted. Cached analysisId: " $$($(GET_ANALYSIS_ID_CMD_2)) $(END)

test-submit_3: start-storage-services
	@echo $(YELLOW)$(INFO_HEADER) "Submitting payload /song-client/input/exampleVariantCall3.json" $(END)
	@$(SONG_CLIENT_CMD) submit -f /song-client/input/exampleVariantCall3.json | tee $(SONG_CLIENT_SUBMIT_RESPONSE_FILE_3)
	@cat $(SONG_CLIENT_SUBMIT_RESPONSE_FILE_3) | grep analysisId | sed 's/.*://' | sed 's/"\|,//g'  > $(SONG_CLIENT_ANALYSIS_ID_FILE_3)
	@echo $(YELLOW)$(INFO_HEADER) "Successfully submitted. Cached analysisId: " $$($(GET_ANALYSIS_ID_CMD_3)) $(END)

test-submit_4: start-storage-services
	@echo $(YELLOW)$(INFO_HEADER) "Submitting payload /song-client/input/exampleVariantCall4.json" $(END)
	@$(SONG_CLIENT_CMD) submit -f /song-client/input/exampleVariantCall4.json | tee $(SONG_CLIENT_SUBMIT_RESPONSE_FILE_4)
	@cat $(SONG_CLIENT_SUBMIT_RESPONSE_FILE_4) | grep analysisId | sed 's/.*://' | sed 's/"\|,//g'  > $(SONG_CLIENT_ANALYSIS_ID_FILE_4)
	@echo $(YELLOW)$(INFO_HEADER) "Successfully submitted. Cached analysisId: " $$($(GET_ANALYSIS_ID_CMD_4)) $(END)

test-manifest: test-manifest_1

test-manifest_1: test-submit_1
	@echo $(YELLOW)$(INFO_HEADER) "Creating manifest at /song-client/output" $(END)
	@$(SONG_CLIENT_CMD) manifest -a $$($(GET_ANALYSIS_ID_CMD_1))  -f /song-client/output/manifest_1.txt -d /song-client/input
	@cat $(SONG_CLIENT_OUTPUT_DIR)/manifest_1.txt

test-manifest_2: test-submit_2
	@echo $(YELLOW)$(INFO_HEADER) "Creating manifest at /song-client/output" $(END)
	@$(SONG_CLIENT_CMD) manifest -a $$($(GET_ANALYSIS_ID_CMD_2))  -f /song-client/output/manifest_2.txt -d /song-client/input
	@cat $(SONG_CLIENT_OUTPUT_DIR)/manifest_2.txt

test-manifest_3: test-submit_3
	@echo $(YELLOW)$(INFO_HEADER) "Creating manifest at /song-client/output" $(END)
	@$(SONG_CLIENT_CMD) manifest -a $$($(GET_ANALYSIS_ID_CMD_3))  -f /song-client/output/manifest_3.txt -d /song-client/input
	@cat $(SONG_CLIENT_OUTPUT_DIR)/manifest_3.txt

test-manifest_4: test-submit_4
	@echo $(YELLOW)$(INFO_HEADER) "Creating manifest at /song-client/output" $(END)
	@$(SONG_CLIENT_CMD) manifest -a $$($(GET_ANALYSIS_ID_CMD_4))  -f /song-client/output/manifest_4.txt -d /song-client/input
	@cat $(SONG_CLIENT_OUTPUT_DIR)/manifest_4.txt

# Upload a manifest using the score-client. Affected by DEMO_MODE
test-score-upload: test-score-upload_1

test-score-upload_1:  test-manifest_1 _ping_score_server 
	@echo $(YELLOW)$(INFO_HEADER) "Uploading manifest /song-client/output/manifest_1.txt" $(END)
	@$(SCORE_CLIENT_CMD) upload --manifest /song-client/output/manifest_1.txt

test-score-upload_2:  test-manifest_2 _ping_score_server
	@echo $(YELLOW)$(INFO_HEADER) "Uploading manifest /song-client/output/manifest_2.txt" $(END)
	@$(SCORE_CLIENT_CMD) upload --manifest /song-client/output/manifest_2.txt

test-score-upload_3:  test-manifest_3 _ping_score_server
	@echo $(YELLOW)$(INFO_HEADER) "Uploading manifest /song-client/output/manifest_3.txt" $(END)
	@$(SCORE_CLIENT_CMD) upload --manifest /song-client/output/manifest_3.txt

test-score-upload_4:  test-manifest_4 _ping_score_server
	@echo $(YELLOW)$(INFO_HEADER) "Uploading manifest /song-client/output/manifest_4.txt" $(END)
	@$(SCORE_CLIENT_CMD) upload --manifest /song-client/output/manifest_4.txt

test-publish: test-publish_1

test-publish_1: _ping_song_server
	@echo $(YELLOW)$(INFO_HEADER) "Publishing analysis: $$($(GET_ANALYSIS_ID_CMD_1))" $(END)
	@$(SONG_CLIENT_CMD) publish -a $$($(GET_ANALYSIS_ID_CMD_1))

test-publish_2: _ping_song_server
	@echo $(YELLOW)$(INFO_HEADER) "Publishing analysis: $$($(GET_ANALYSIS_ID_CMD_2))" $(END)
	@$(SONG_CLIENT_CMD) publish -a $$($(GET_ANALYSIS_ID_CMD_2))

test-publish_3: _ping_song_server
	@echo $(YELLOW)$(INFO_HEADER) "Publishing analysis: $$($(GET_ANALYSIS_ID_CMD_3))" $(END)
	@$(SONG_CLIENT_CMD) publish -a $$($(GET_ANALYSIS_ID_CMD_3))

test-publish_4: _ping_song_server
	@echo $(YELLOW)$(INFO_HEADER) "Publishing analysis: $$($(GET_ANALYSIS_ID_CMD_4))" $(END)
	@$(SONG_CLIENT_CMD) publish -a $$($(GET_ANALYSIS_ID_CMD_4))

test-upload-and-publish: test-upload-and-publish_1

test-upload-and-publish_1: test-score-upload_1 _ping_song_server _ping_score_server
	@echo $(YELLOW)$(INFO_HEADER) "Publishing analysis: $$($(GET_ANALYSIS_ID_CMD_1))" $(END)
	@$(SONG_CLIENT_CMD) publish -a $$($(GET_ANALYSIS_ID_CMD_1))

test-upload-and-publish_2: test-score-upload_2 _ping_song_server _ping_score_server
	@echo $(YELLOW)$(INFO_HEADER) "Publishing analysis: $$($(GET_ANALYSIS_ID_CMD_2))" $(END)
	@$(SONG_CLIENT_CMD) publish -a $$($(GET_ANALYSIS_ID_CMD_2))

test-upload-and-publish_3: test-score-upload_3 _ping_song_server _ping_score_server
	@echo $(YELLOW)$(INFO_HEADER) "Publishing analysis: $$($(GET_ANALYSIS_ID_CMD_3))" $(END)
	@$(SONG_CLIENT_CMD) publish -a $$($(GET_ANALYSIS_ID_CMD_3))

test-upload-and-publish_4: test-score-upload_4 _ping_song_server _ping_score_server
	@echo $(YELLOW)$(INFO_HEADER) "Publishing analysis: $$($(GET_ANALYSIS_ID_CMD_4))" $(END)
	@$(SONG_CLIENT_CMD) publish -a $$($(GET_ANALYSIS_ID_CMD_4))

test-upload-publish-and-index: test-upload-publish-and-index_1

test-upload-publish-and-index_1: test-upload-and-publish_1
	@$(CURL_EXE) -X POST http://localhost:11235/index/repository/local_song -H 'Content-Type: application/json' -H 'cache-control: no-cache'

test-upload-publish-and-index_2: test-upload-and-publish_2
	@$(CURL_EXE) -X POST http://localhost:11235/index/repository/local_song -H 'Content-Type: application/json' -H 'cache-control: no-cache'

test-upload-publish-and-index_3: test-upload-and-publish_3
	@$(CURL_EXE) -X POST http://localhost:11235/index/repository/local_song -H 'Content-Type: application/json' -H 'cache-control: no-cache'

test-upload-publish-and-index_4: test-upload-and-publish_4
	@$(CURL_EXE) -X POST http://localhost:11235/index/repository/local_song -H 'Content-Type: application/json' -H 'cache-control: no-cache'

test-workflow_1: start-services
	@$(MAKE) test-upload-publish-and-index_1
	@$(MAKE) test-upload-publish-and-index_2

test-unpublish: test-unpublish_1

test-unpublish_1: _ping_song_server
	@echo $(YELLOW)$(INFO_HEADER) "Unpublishing analysis: $$($(GET_ANALYSIS_ID_CMD_1))" $(END)
	@$(SONG_CLIENT_CMD) unpublish -a $$($(GET_ANALYSIS_ID_CMD_1))

test-unpublish_2: _ping_song_server
	@echo $(YELLOW)$(INFO_HEADER) "Unpublishing analysis: $$($(GET_ANALYSIS_ID_CMD_2))" $(END)
	@$(SONG_CLIENT_CMD) unpublish -a $$($(GET_ANALYSIS_ID_CMD_2))

test-unpublish_3: _ping_song_server
	@echo $(YELLOW)$(INFO_HEADER) "Unpublishing analysis: $$($(GET_ANALYSIS_ID_CMD_3))" $(END)
	@$(SONG_CLIENT_CMD) unpublish -a $$($(GET_ANALYSIS_ID_CMD_3))

test-unpublish_4: _ping_song_server
	@echo $(YELLOW)$(INFO_HEADER) "Unpublishing analysis: $$($(GET_ANALYSIS_ID_CMD_4))" $(END)
	@$(SONG_CLIENT_CMD) unpublish -a $$($(GET_ANALYSIS_ID_CMD_4))

test-elastic-status:
	@echo $(YELLOW)$(INFO_HEADER) "Available indices:" $(END)
	@$(CURL_EXE) -X GET "localhost:9200/_cat/indices"
	@echo $(YELLOW)$(INFO_HEADER) "file_centric_1.0 content:" $(END)
	@$(CURL_EXE) -X GET "localhost:9200/file_centric_1.0/_search?size=100"
