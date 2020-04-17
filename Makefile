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
SONG_CLIENT_ANALYSIS_ID_FILE := $(SONG_CLIENT_OUTPUT_DIR)/analysisId.txt
SONG_CLIENT_SUBMIT_RESPONSE_FILE := $(SONG_CLIENT_OUTPUT_DIR)/submit_response.json


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
		-H 'Authorization: Bearer f69b726d-d40f-4261-b105-1ec7e6bf04d5' \
		'http://localhost:8087/download/ping'
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
	@$(DC_UP_CMD) arranger-ui rest-proxy
	@echo $(YELLOW)$(INFO_HEADER) Succesfully started services! $(END)

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

GET_ANALYSIS_ID_CMD := cat $(SONG_CLIENT_ANALYSIS_ID_FILE)

get-analysis-id:
	@echo "The cached analysisId is " $$($(GET_ANALYSIS_ID_CMD))

test-submit: start-storage-services
	@echo $(YELLOW)$(INFO_HEADER) "Submitting payload /song-client/input/exampleVariantCall.json" $(END)
	@$(SONG_CLIENT_CMD) submit -f /song-client/input/exampleVariantCall.json | tee $(SONG_CLIENT_SUBMIT_RESPONSE_FILE)
	@cat $(SONG_CLIENT_SUBMIT_RESPONSE_FILE) | grep analysisId | sed 's/.*://' | sed 's/"\|,//g'  > $(SONG_CLIENT_ANALYSIS_ID_FILE)
	@echo $(YELLOW)$(INFO_HEADER) "Successfully submitted. Cached analysisId: " $$($(GET_ANALYSIS_ID_CMD)) $(END)

test-manifest: test-submit
	@echo $(YELLOW)$(INFO_HEADER) "Creating manifest at /song-client/output" $(END)
	@$(SONG_CLIENT_CMD) manifest -a $$($(GET_ANALYSIS_ID_CMD))  -f /song-client/output/manifest.txt -d /song-client/input
	@cat $(SONG_CLIENT_OUTPUT_DIR)/manifest.txt

# Upload a manifest using the score-client. Affected by DEMO_MODE
test-score-upload:  test-manifest _ping_score_server 
	@echo $(YELLOW)$(INFO_HEADER) "Uploading manifest /song-client/output/manifest.txt" $(END)
	@$(SCORE_CLIENT_CMD) upload --manifest /song-client/output/manifest.txt

test-publish: _ping_song_server
	@echo $(YELLOW)$(INFO_HEADER) "Publishing analysis: $$($(GET_ANALYSIS_ID_CMD))" $(END)
	@$(SONG_CLIENT_CMD) publish -a $$($(GET_ANALYSIS_ID_CMD))

test-upload-and-publish: test-score-upload _ping_song_server _ping_score_server
	@echo $(YELLOW)$(INFO_HEADER) "Publishing analysis: $$($(GET_ANALYSIS_ID_CMD))" $(END)
	@$(SONG_CLIENT_CMD) publish -a $$($(GET_ANALYSIS_ID_CMD))


test-unpublish: _ping_song_server
	@echo $(YELLOW)$(INFO_HEADER) "Unpublishing analysis: $$($(GET_ANALYSIS_ID_CMD))" $(END)
	@$(SONG_CLIENT_CMD) unpublish -a $$($(GET_ANALYSIS_ID_CMD))

