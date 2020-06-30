The purpose of this repository is to provide users with a local and isolated sandbox to play with some of Overture's genomic services, such as Song, Score, Ego, Maestro and Arranger. 
Every release contains a stable and tested configuration of various Overture products using absolute versions, so that specific configurations can be reproduced. 
The services are managed by `docker-compose` and are bootstrapped with fixed data so that users can start playing around as fast as possible.

##  <a name="toc"></a> Table of Contents
* [Software Requirements](#software-requirements)
* [Quick Start](#quick-start)
* [Software Installation for x86_64](#software-installation-for-x86_64)
  * [Ubuntu 18.04 or Higher](#ubuntu-18.04-or-higher)
    * [Docker](#ubuntu-docker)
    * [Docker Compose](#ubuntu-docker-compose)
    * [GNU Make](#ubuntu-gnu-make)
  * [OSX](#osx)
    * [Docker](#osx-docker)
    * [Docker Compose](#osx-docker-compose)
    * [Homebrew](#homebrew)
    * [GNU Make](#osx-gnu-make)
* [Architecture](#architecture)
* [Bootstrapped Configurations](#bootstrapped-configurations)
  * [Docker host and container path mappings](#docker-host-and-container-path-mappings)
  * [Ego](#ego)
  * [Score](#score)
  * [Song](#song)
  * [Object Storage](#object-storage)
  * [Zookeeper](#zookeeper)
  * [ElasticSearch](#elasticsearch)
  * [Kibana](#kibana)
  * [Kafka Broker](#kafka)
  * [Maestro](#maestro)
  * [Arranger](#arranger)
* [Usage](#usage)
  * [Environment Setup](#environment-setup)
    * [Cloning the Repository](#clone-repo)
    * [Starting All Services and Initializing Data](#starting-all-services-and-initializing-data)
    * [View Running Services](#view-running-services)
    * [Stopping All Services](#stopping-all-services)
    * [Destroying All Services and Data](#destroying-all-services-and-data)
  * [Interaction Examples with Storage Services](#storage-services-interaction-examples)
    * [Check Song is running](#song-health-check)
    * [Check Score is running](#score-health-check)
    * [Check Ego is running](#ego-health-check)
    * [Submit a payload](#submit-a-payload)
    * [Generate a manifest](#generate-a-manifest)
    * [Upload the files](#upload-the-files)
    * [Publish the analysis](#publish-the-analysis)
    * [Download analysis files](#download-analysis-files)
	* [Perform All Steps in One](#all-in-one)
  * [Optional Song Service Interaction Examples](#advanced-song-examples)
    * [Create a Study](#create-study)
    * [Registering an AnalysisType](#registering-analysis-type)
      * [1. Creating the RegisterAnalysisType Request](#creating-register-analysis-type-payload)
      * [2. Execute the RegisterAnalysisType Endpoint](#executing-register-analysis-type-request)
    * [Unpublish the analysis](#unpublish-the-analysis)
    * [Update an Analysis](#update-analysis)
      * [1. Prepare UpdateAnalysis Request](#prepare-update-analysis)
      * [2. Execute UpdateAnalysis Request](#execute-analysis-update)
  * [Interaction Examples with Indexing Services](#indexing-services-interaction-examples)
    * [Automatic Index Creation](#automatic-index-creation)
    * [Delete ES Documents](#delete-es-documents)
    * [Trigger Indexing of a Repository](#trigger-index-repo)
    * [Trigger Indexing of a Study](#trigger-index-study)
    * [Trigger Indexing of an AnalysisId](#trigger-index-anid)
    * [Configuring Exclusion Rules in Maestro](#configure-index-exclusion-rules)
    * [Get existing indices and file_centric data](#elastic-content)
  * [Interaction Examples with Portal Services](#portal-services-interaction-examples)
    * [Special Notes for the Arranger Portal](#special-arranger-note)
    * [Configuring the Arranger Portal](#configuring-arranger-portal)
    * [Customize the Arranger Configuration](#customize-arranger-configuration)
    * [Viewing the Arranger Portal](#viewing-portal)
* [License](#license)

## <a name="software-requirements"></a> Software Requirements
- docker engine version >= **18.06.0**
- docker-compose version >= **1.22.0**
- compose file format version >= **3.7**
- Bash Shell
- GNU Make
- curl

## <a name="quick-start"></a>Quick Start
Assuming docker, docker-compose and make are already installed, 
you can jump straight to the following sections in order:
1. [All in One](#all-in-one)
2. [Configuring the Arranger Portal](#configuring-arranger-portal)
3. [Viewing the Arranger Portal](#viewing-portal)

[Back to Contents](#toc)

## <a name="software-installation-for-x86_64"></a>Software Installation for x86_64
### <a name="ubuntu-18.04-or-higher"></a>Ubuntu 18.04 or Higher
#### <a name="ubuntu-docker"></a> Docker
```bash
sudo apt update
sudo apt remove docker docker-engine docker.io
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository  "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce
sudo usermod -aG docker <your_user_name>

# Logout and log back in

# Test with
docker ps
```

[Back to Contents](#toc)

#### <a name="ubuntu-docker-compose"></a> Docker Compose
```bash
# You can replace 1.25.0 with any version
sudo curl -L "https://github.com/docker/compose/releases/download/1.25.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Test with
docker-compose --version
```

[Back to Contents](#toc)

#### <a name="ubuntu-gnu-make"></a> GNU Make
```bash
sudo apt update 
sudo apt install -y make
```

[Back to Contents](#toc)

### <a name="osx"></a> OSX

#### <a name="osx-docker"></a> Docker
Refer to the instructions for [Installing Docker Desktop on Mac](https://docs.docker.com/docker-for-mac/install/)

#### <a name="osx-docker-compose"></a> Docker Compose
Already included in Docker Desktop on Mac

#### <a name="homebrew"></a>Homebrew
Needed in order to install GNU Make
```bash
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

#### <a name="osx-gnu-make"></a> GNU Make
```bash
brew install coreutils make
```

[Back to Contents](#toc)

## <a name="architecture"></a>Architecture
There are 3 core Overture services used to manage genomic data: [Song](https://www.overture.bio/products/song) for genomic metadata, [Ego](https://www.overture.bio/products/ego) for security, and [Score](https://www.overture.bio/products/score) for genomic object data. 

For Score the back-end object storage service that was used was [Minio](https://min.io/). For Song and Ego, `postgreSQL` was used as the database technology.

The core Overture service to manage Elasticsearch indices is [Maestro](https://www.overture.bio/products/maestro). Maestro can be configured to optionally use kafka for event-driven indexing of Song genomic metadata into Elasticsearch, or it can just be used to manually trigger indexing via its REST API.

The core Overture service to manage the genomic portal is [Arranger](https://www.overture.bio/products/arranger). In this playground, there are 3 key components to Arranger: the server which is a graphql gateway to the Elasticsearch index, the admin-ui which is used to configure the server, and the portal which is used to display the data.

For more information on these services, visit their `Read the Docs` documentation:
- [Ego documentation](https://ego.readthedocs.io)
- [Song documentation](https://song-docs.readthedocs.io)
- [Score documentation](https://score-docs.readthedocs.io). 
- [Maestro documentation](https://maestro-overture.readthedocs.io)
- [Arranger documentation](https://arranger.readthedocs.io)

<img src="images/architecture.png" width="100%">

[Back to Contents](#toc)

## <a name="bootstrapped-configurations"></a>Bootstrapped Configurations

[Back to Contents](#toc)

### <a name="docker-host-and-container-path-mappings"></a>Docker host and container path mappings
Since all clients and services communicate through a docker network, any files from the docker host that are to be used with the clients must be mounted into the docker containers. 
Similarly, any files that need to be output from the containers to the docker host must also be mounted. Since these files are not apart of this repository, they can be located in the `./scratch` directory.
This has already been pre-configured in the `docker-compose.yml`. 
The following represent the docker host path to docker container path mappings:

**NOTE:** All file paths below are relative to the root directory of this repository.

| Host path | Container path | Description |
| ----------| ---------------|-------------|
| ./song-example-data             | /song-client/input   | Contains example files for submitting to Song and uploading to Score. Used by the `song-client` and `score-client` |
| ./scratch/song-client-output    | /song-client/output  | Contains files generated by the `song-client`. Used by the `song-client` and `score-client`. |
| ./scratch/score-client-output   | /score-client/output | Contains files generated by the `score-client`. Used only by the `score-client`. |
| ./scratch/song-client-logs      | /song-client/logs    | Contains logs generated by the `song-client`. Used only by `song-client`. |
| ./scratch/score-client-logs     | /score-client/logs   | Contains logs generated by the `score-client`. Used only by `score-client`. |
| ./scratch/song-server-logs      | /song-server/logs    | Contains logs generated by the `song-server`. Used only by `song-server`. |
| ./scratch/score-server-logs     | /score-server/logs   | Contains logs generated by the `score-server`. Used only by `score-server`. |

The following configurations are initialized when the services are started. 


### <a name="ego"></a>Ego
- Swagger URL: http://localhost:9082/swagger-ui.html
- User Id: `c6608c3e-1181-4957-99c4-094493391096`
- User Email: `john.doe@example.com`
- User Name: `john.doe@example.com`
- JWT: `any_jwt` (**Note**: although security is disabled, the Authorization header field must be present with all requests and can have ANY value)
- Api Key: `f69b726d-d40f-4261-b105-1ec7e6bf04d5` (**Note**: this Api Key is the same as the Access Token for both Song and Score)
- Api Key Scopes: `score.WRITE`, `song.WRITE`, `id.WRITE`
- Database
    - Host: `localhost`
    - Port: `9444`
    - Name: `ego`
    - Username: `postgres`
    - Password: `password`

### <a name="score"></a>Score
- Score-client Location: `./tools/score-client`
- Client Access Token: `f69b726d-d40f-4261-b105-1ec7e6bf04d5`

### <a name="song"></a>Song
- Swagger URL: http://localhost:8080/swagger-ui.html
- Song-client Location: `./tools/song-client`
- Client Access Token: `f69b726d-d40f-4261-b105-1ec7e6bf04d5`
- Default StudyId:  `ABC123`
- Database
    - Name: `song`
    - Username: `postgres`
    - Password: `password`

### <a name="object-storage"></a>Object Storage
- UI URL: http://localhost:8085
- Minio Client Id: `minio`
- Minio Client Secret: `minio123`

### <a name="zookeeper"></a>Zookeeper
- URL: http://localhost:2181

### <a name="elasticsearch"></a>ElasticSearch
- URL: http://localhost:9200

### <a name="kibana"></a>Kibana
- URL: http://localhost:5601

### <a name="kafka"></a>Kafka Broker
- URL: http://localhost:9092

### <a name="maestro"></a>Maestro
- URL: http://localhost:11235

### <a name="arranger"></a>Arranger
- Server URL: http://localhost:5050
- Admin UI URL: http://localhost:9080
    - Project Config Dir: `./arranger-data/project/file_centric/`
- Portal URL: http://localhost:3000

[Back to Contents](#toc)

## <a name="usage"></a>Usage
The following sections describe Makefile targets and how they can be executed to achieve a specific goal. A list of all available targets can be found by running `make help`. Multiple targets can be run in a specific order from left to right. All Makefile targets must be run from the root directory of this repository.

[Back to Contents](#toc)

### <a name="environment-setup"></a>Environment Setup
These scenarios are related to starting and stopping the docker services.  In order to successfully run the following instructions, the following commands shoud be run in the root directory of the repository.

#### <a name="clone-repo"></a>Cloning the Repository
Firstly, clone this repo and ensure you are in the root directory:

```bash
git clone https://github.com/overture-stack/genomic-data-playground

# Switch to the root directory of the repo
cd genomic-data-playground
```

#### <a name="starting-all-services-and-initializing-data"></a>Starting All Services and Initializing Data

To start the song, score, ego and kafka services and initialize their data, simply run the following command:

```bash
make start-storage-services
```

To start the elasticsearch, kafka, and maestro services simply run the following command:

```bash
make start-maestro-services
```

To start the arranger server, arranger admin ui, and arranger portal simply run the following command:

```bash
make start-arrangers-services
```

To execute all the previous steps and start all services, simply run the command below. 
Since there are many services, it will take several minutes for the command to complete.

 ```bash
make start-all-services
 ```
#### <a name="view-running-services"></a>View Running Services
To view all the running services, run:
 ```bash
make ps
 ```
 
#### <a name="stopping-all-services"></a>Stopping All Services
To just halt all services without deleting any data, run:
 ```bash
make stop-all-services
 ```

#### <a name="destroying-all-services-and-data"></a>Destroying All Services and Data
To kill all services and delete their data, run:
```bash
make clean
```
This will delete all files and directories located in the `./scratch` directory, including logs and generated files.

[Back to Contents](#toc)

### <a name="storage-services-interaction-examples"></a>Interaction Examples with Storage Services
This section contains the instructions for interacting with the storage services: `song` and `score`. The examples below are the most common use cases and were crafted in a way to allow the user to interact with a docker network of running services. For a more documentation on these services, please refer to the [Song documentation](https://song-docs.readthedocs.io/) and the [Score documentation](https://score-docs.readthedocs.io/)

#### <a name="song-health-check"></a>Check Song is running
Ping the Song server to see if its running
```bash
./tools/song-client ping
```

[Back to Contents](#toc)

#### <a name="score-health-check"></a>Check Score is running
Execute the following command to ensure Score is running
```bash
curl -s -XGET http://localhost:8087/download/ping
```

[Back to Contents](#toc)

#### <a name="ego-health-check"></a>Check Ego is running
Execute the following command to ensure Ego is running
```bash
curl -s -XGET http://localhost:9082/oauth/token/public_key
```

[Back to Contents](#toc)


#### <a name="submit-a-payload"></a>Submit a payload
Submit the `exampleVariantCall.json` file located in the `/song-client/input` directory
```bash
./tools/song-client submit -f /song-client/input/exampleVariantCall.json
```

If successful, the output will contain the `analysisId` which will be needed in the following steps.

Alternatively, the following command can be run, which will:
  - ensure all corresponding services are running
  - execute the above command for several payloads, including the one above
  - return the `analysisId` for each submitted payload

```bash
make test-submit
```

[Back to Contents](#toc)

#### <a name="generate-a-manifest"></a>Generate a manifest
Using the `analysisId` from the previous [submit step](#submit-a-payload) execute the following command to generate a `manifest.txt` file.

```bash
./tools/song-client manifest -f /song-client/output/manifest.txt -d /song-client/input -a <analysisId>
```
The output `manifest.txt` file is used with the `score-client` to upload the files.

[Back to Contents](#toc)

#### <a name="upload-the-files"></a>Upload the files
Using the `manifest.txt` from the previous [manifest generation step](#generate-a-manifest) execute the following command to upload files to the object storage

```bash
./tools/score-client upload --manifest /song-client/output/manifest.txt
```

[Back to Contents](#toc)

#### <a name="publish-the-analysis"></a>Publish the analysis
Once the files of an analysis are uploaded, the analysis can be published using the `analysisId` returned from the [submit step](#submit-a-payload)
```bash
./tools/song-client publish -a <analysisId>
```

[Back to Contents](#toc)

#### <a name="download-analysis-files"></a>Download analysis files

Before downloading a file, the `objectId` must be known. 
Using the following command, search Song for the analysis given the `analysisId`, and then
extract the `objectId` for the `example.vcf.gz` file.

```bash
./tools/song-client search -a <analysisId>
```

Using the extracted `objectId`, run the following command to download the file:

```bash
./tools/score-client download --object-id <objectId> --output-dir /score-client/output/download1
```
This will download the file to the specified directory. 
The file can be accessed on the docker host by referring to the [docker path mapping table](#docker-host-and-container-path-mappings)

[Back to Contents](#toc)

#### <a name="all-in-one"></a>Perform All Steps in One
It is possible to launch all the steps explained in this section with a single command that:

  - initializes all the services
  - submits 4 payloads
  - generates a manifest for each of the submitted payloads
  - uploads the files
  - publishes the analyses

```bash
make test-workflow
```

[Back to Contents](#toc)

### <a name="advanced-song-examples"></a>Optional Song Service Interaction Examples
This section contains **optional** advanced usage of Song.

#### <a name="create-study"></a>Create a Study
Before submitting any data, a study must be created. The study used in this playground is `ABC123`.
In this playground, the study `ABC123` does not need to be created because the Song database is automatically bootstrapped for convenience, so this is an **optional** step. However, to create a new studyId, for example `myNewStudyId`, execute the following:

```bash
curl -X POST \
  --header 'Authorization: Bearer f69b726d-d40f-4261-b105-1ec7e6bf04d5'  \
  -d '{"studyId":"myNewStudyId"}' \
  'http://localhost:8080/studies/myNewStudyId/'
```

[Back to Contents](#toc)

#### <a name="registering-analysis-type"></a>Registering an AnalysisType
In order to validate submitted payloads, an `analysisType` must be registered and then later referenced in a payload. 
The `analysisType` is described by a jsonSchema that provides the necessary constraints to validate submitted payloads.
For convenience, the analysisType `variantCall` is automatically registered when Song is started, so this section is **optional** for the curious user.

##### <a name="creating-register-analysis-type-payload"></a>1. Creating the RegisterAnalysisType Request
In order to register the `analysisType`, a json document needs 
to be prepared containing the schema and name of the `analysisType`.
This file is referred to as the `RegisterAnalysisType` request, the following is an example of the contents:

```
{
  "name": "<name of analysisType>".
  "schema": {
     ... valid jsonSchema ...
  }
}
```

When writing the schema, the meta-schema (also described using jsonSchema) must be used for reference.
The meta-schema describes the structure and constraints for the `analysisType` schema.
This can be thought of as "a schema that describes a schema".
The meta-schema can be retrieved using the following command:

```bash
curl -X GET "http://localhost:8080/schemas/registration"
```

Once written, save the document in the `./song-example-data/` directory. 
Recall from the [docker host and container path mappings table](#docker-host-and-container-path-mappings), the `./song-example-data/` directory is mounted in the song-client as `/song-client/input`. For convenience, an example `analysisType` located in `./song-example-data/exampleAnalysisType.json` has already been created for the next step.


##### <a name="executing-register-analysis-type-request"></a>2. Execute the RegisterAnalysisType Endpoint
Using the `RegisterAnalysisType` request document from the previous step, execute the following:

```bash
./tools/song-client register-analysis-type -f /song-client/input/<file-from-previous-step>.json
```

Using the example located in `./song-example-data/exampleAnalysisType.json`, the following command will register the example `analysisType`:

```bash
./tools/song-client register-analysis-type -f /song-client/input/exampleAnalysisType.json
```

If the `analysisType` did not previously exist, the `analysisType` will be registered with version 1.
If the `analysisType` existed previously, then a **new** version will be created, 
since analysisTypes are **immutable**. This is effectively the same as an **update**.

Only users with system admin scope permissions can use this functionality, 
however for convenience this playground has been bootstrapped with a dummy user that has admin privileges.

[Back to Contents](#toc)

#### <a name="unpublish-the-analysis"></a>Unpublish the analysis
In order to re-upload files, the analysis must be unpublished. 
They can be unpublished using the `analysisId` used in the [publish step](#publish-the-analysis)

```bash
./tools/song-client unpublish -a <analysisId>
```

[Back to Contents](#toc)

#### <a name="update-analysis"></a>Update an Analysis
Even after an analysis has been created, using its `analysisId`, 
only the fields described by it's `analysisType` schema can be updated using the following steps:

##### <a name="prepare-update-analysis"></a>1. Prepare UpdateAnalysis Request
Prepare a json document that contains the updated fields for the analysis.
In addition to the fields described by the analysisType, the analysisType object must also be present.
For example, after submitting the payload from the [submit a payload](#submit-a-payload) step, 
if the `matchedNormalSampleSubmitterId` needs to be updated, the update analysis request would look like the following:

```json
{
	"analysisType": {
		"name": "variantCall"
	},
	"experiment" :{
		"matchedNormalSampleSubmitterId": "updatedMatchedSubmitterId",
		"variantCallingTool": "sameVariantCallingTool"
	}
}
```

Since there are no partial updates, **all** fields must be defined.


[Back to Contents](#toc)

##### <a name="execute-analysis-update"></a>2. Execute UpdateAnalysis Request

Using the json file prepared in the previous step, say `myUpdateRequest.json`, execute the following request:

```bash
curl -XPUT \
	-H 'Authorization: Bearer f69b726d-d40f-4261-b105-1ec7e6bf04d5'  \
	--data "@myUpdateRequest.json" \
	"http://localhost:8080/ABC123/analysis/<analysisId>"
```


### <a name="indexing-services-interaction-examples"></a>Interaction Examples with Indexing Services


#### <a name="automatic-index-creation"></a>Automatic Index Creation
When the `maestro` service is started, 
it automatically creates the `file_centric` index in elasticsearch if it does not already exist.
This is important, since the **default** `maestro` index mappings are compatible with `arranger` related services.
Refer to [Special Arranger Notes](#special-arranger-note)

[Back to Contents](#toc)

#### <a name="delete-es-documents"></a>Delete ES Documents
In order to delete all non-kibana and non-arranger documents for elasticsearch, the following command can be run:

``` bash
curl -s -XGET \ 
	"http://localhost:9200/_cat/indices" \
	| grep -v kibana | grep -v arranger | grep -v configuration \
	| awk '{ print $3 }' \
	| sed  's/^/http:\/\/localhost:9200\//' \
	| sed 's/$/\/_delete_by_query/' \
	| xargs curl -XPOST \
		--header 'Content-Type: application/json' \
		-d '{"query":{"match_all":{}}}' }'
```

For convenience, the following Makefile command executes the above command:

```bash
make clear-es-documents
```

[Back to Contents](#toc)

#### <a name="trigger-index-repo"></a>Trigger Indexing of a Repository
The following command triggers indexing of an entire repository.
This is not necessary when using `maestro` with a `kafka-broker` since 
analysis events are automatically indexed by `maestro`.
However, in the event the `kafka` service was unavailable for a period of time 
while analyses for a particular study were created or published in Song, 
this endpoint can be used to re-index the entire repository.

```bash
curl -s -XPOST \
	-H 'Content-Type: application/json' \
	-H 'cache-control: no-cache' \
	"http://localhost:11235/index/repository/<repositoryName>"
```

In this playground, the `repositoryName` is configured to `local_song` and the command would be:

```bash
curl -s -XPOST \
	-H 'Content-Type: application/json' \
	-H 'cache-control: no-cache' \
	"http://localhost:11235/index/repository/local_song"
```

For convenience, the above command can be run using the following command:

```bash
make trigger-maestro-indexing
```

[Back to Contents](#toc)

#### <a name="trigger-index-study"></a>Trigger Indexing of a Study
Similar to the [Trigger Indexing of a Repository](#trigger-indexing-of-a-repository) section, 
the indexing of an entire study for a repository can be done by executing the following command:

```bash
curl -s -XPOST \
	-H 'Content-Type: application/json' \
	-H 'cache-control: no-cache' \
	"http://localhost:11235/index/repository/<repositoryName>/study/<studyId>"
```

In this playground, the `repositoryName` is configured to `local_song`,
and the `studyId` is configured to `ABC123`, so the command would be:

```bash
curl -s -XPOST \
	-H 'Content-Type: application/json' \
	-H 'cache-control: no-cache' \
	"http://localhost:11235/index/repository/local_song/study/ABC123"
```

[Back to Contents](#toc)

#### <a name="trigger-index-anid"></a>Trigger Indexing of an AnalysisId
Similar to the [Trigger Indexing of a Study](#trigger-indexing-of-a-study) section, 
a single analysis can be indexed using its `analysisId`, `studyId` and `repositoryName`:

```bash
curl -s -XPOST \
	-H 'Content-Type: application/json' \
	-H 'cache-control: no-cache' \
	"http://localhost:11235/index/repository/<repositoryName>/study/<studyId>/analysis/<analysisId>"
```

In this playground, after publishing an analysis (refer to the [Publish the Analysis](#publish-the-analysis) section),
using that `analysisId`, the studyId `ABC123` and the repositoryName `local_song`, 
the analysis can be indexed by executing:

```bash
curl -s -XPOST \
	-H 'Content-Type: application/json' \
	-H 'cache-control: no-cache' \
	"http://localhost:11235/index/repository/local_song/study/ABC123/analysis/<analysisId>"
```

[Back to Contents](#toc)

#### <a name="configure-index-exclusion-rules"></a>Configuring Exclusion Rules in Maestro
In certain scenarios, some entities need to be excluded from indexing. 
There are 6 types of entities which `maestro` can exclude by id:
- study
- analysis
- donor
- specimen
- sample
- file (or object)

This is a static server configuration that requires a reboot of the `maestro` service.
The following is an example of how environment variables can be used to exclude indexing for more than 1 id for each entity:

```
# Excluding multiple studyIds
MAESTRO_EXCLUSIONRULES_BYID_STUDYID_0: <studyId0>
MAESTRO_EXCLUSIONRULES_BYID_STUDYID_1: <studyId1>

# Excluding multiple analysisIds
MAESTRO_EXCLUSIONRULES_BYID_ANALYSIS_0: <analysisId0>
MAESTRO_EXCLUSIONRULES_BYID_ANALYSIS_1: <analysisId1>

# Excluding multiple donorIds
MAESTRO_EXCLUSIONRULES_BYID_DONOR_0: <donorId0>
MAESTRO_EXCLUSIONRULES_BYID_DONOR_1: <donorId1>

# Excluding multiple specimenIds
MAESTRO_EXCLUSIONRULES_BYID_SPECIMEN_0: <specimenId0>
MAESTRO_EXCLUSIONRULES_BYID_SPECIMEN_1: <specimenId1>

# Excluding multiple sampleIds
MAESTRO_EXCLUSIONRULES_BYID_SAMPLE_0: <sampleId0>
MAESTRO_EXCLUSIONRULES_BYID_SAMPLE_1: <sampleId1>

# Excluding multiple objectIds
MAESTRO_EXCLUSIONRULES_BYID_FILE_0: <objectId0>
MAESTRO_EXCLUSIONRULES_BYID_FILE_1: <objectId1>

```

Since `maestro` uses the Spring Framework for Configuration, 
there are specific rules for binding environment variables to 
a list of values when configuring a server statically, 
called [Relaxed Bindings](https://github.com/spring-projects/spring-boot/wiki/Relaxed-Binding-2.0#lists-1)

#### <a name="elastic-content"></a> Get existing indices and file_centric data
Existing indices can be found by running the following command:

```bash
curl -s -XGET "http://localhost:9200/_cat/indices"
```

The first 10 file_centric documents can be displayed by running:

```bash
curl -s -XGET "http://localhost:9200/file_centric/_search?size=10"
```

For convenience, both of the previous commands can be executed by running:

```bash
make get-es-info
```

[Back to Contents](#toc)

### <a name="portal-services-interaction-examples"></a>Interaction Examples with Portal Services

#### <a name="special-arranger-note"></a>Special Notes for the Arranger Portal
In order to use `arranger` with an elasticsearch index, the index must have compatible mappings. 
Arranger expects elasticsearch fields to be of type `keyword` instead of type `text`.

For this reason, the [Automatic Index Creation](#automatic-index-creation) feature of `maestro` is leveraged 
\to create the correct elasticsearch mapping for the `file_centric` index. 
Without a predefined index mapping, elasticsearch will infer the type of a field as `text` 
which is incompatible with `arranger`. 
In addition, it is not possible to change the type of a field after documents have been indexed.

[Back to Contents](#toc)

#### <a name="configuring-arranger-portal"></a>Configuring the Arranger Portal
In order to display the previously uploaded data in the Arranger Portal, a few simple configurations must be made:

1. In a browser, visit http://localhost:9080

2. Click on `Add Project`

3. Enter the project name in the `Project ID` field. The project name must contain at least 1 underscore (`_`)

4. Click on `Add Index`

5. Fill the fields `Name` with the `arranger` alias for the elasticsearch index and `ES index` with the elasticsearch index `file_centric`.
<img src="images/add_project.png" width="100%">

6. Click on `Choose Files` and select the all files located in `./arranger-data/project/file_centric/*`. These files contain sensible configurations for the purpose of this playground. 

7. Click `Add` to apply the configuration. 

For more instructions on how to customize the `arranger` configuration, 
continue to the [Customize the Arranger Configuration](#customize-arranger-configuration) section. 
Otherwise, to view the portal with these configurations, 
go to the [Viewing the Arranger Portal](#viewing-portal) section.

[Back to Contents](#toc)

#### <a name="customize-arranger-configuration"></a>Customize the Arranger Configuration
8. Click on the project name

	On this page, there are 3 important tabs:
	
	* **Fields**: allows the user to rename fields and specify their types. 
	
	* **Aggs Panel**: allows the user to select which fields can be used to filter files.
	
	* **Table**: allows the user to select which fields will be shown in the main table.
	
	Since `arranger` cannot have fields of type `id`, fields of type `id` must be changed to `keyword`. To do this:

9. Filter the fields by `Type` equal to `id`.

10. In the top right corner, change the `Aggregation Type` from `id` to `keyword` for all fields that are named `id`. In this playground, the fields of interest are:

	* analysis.id
	* donors.id
	* donors.specimens.id
	* donors.specimens.samples.id

11. For the following fields, ensure the `Is array` box is checked:

	* donors
	* donors.specimens
	* donors.specimens.samples

12. Click on the `Aggs Panel` tab
<img src="images/aggs_panel.png" width="100%">

13. Check the box `Shown` for fields that can be used to filter files.
These fields will be shown in the aggregation panel.
It is also possible to disable fields so they are not accessible from the aggregation panel.

14. Click on the `Table` tab
<img src="images/table.png" width="100%">

11. Select the fields that should be shown by default in the table. 
In addition, fields can be disabled so they are not accessible from the table.

12. Click on `Save Project`, on the top right corner
<img src="images/modified_project.png" width="60%" style="padding-left: 20%">

13. At this point, the setup is finished. 
Continue to [Viewing the Arranger Portal](#viewing-portal) section on how to access the search portal.

[Back to Contents](#toc)

#### <a name="viewing-portal"></a>Viewing the Arranger Portal
1. Assuming `arranger` has been configured (refer to [Configuring the Arranger Portal](#configuring-arranger-portal)), visit http://localhost:3000

2. If at the top right, the text `Log out` is present, click it. 
If a blank screen is present, clear the page data or open the link in a private/incognito tab, 
otherwise continue to the next step.

3. A page with the text `Data Portal` should be displayed with 2 drop downs:
	* Select a version
	* Select an index

	For the `Select a version` drop down, select the desired project name. For the `Select an index` drop down, select the `file_centric` index.

4. At this point, the `Data Portal Search Page` should be displayed with a table containing published files and an aggregation panel with fields to search on. To add more data to the table, publish new analyses. 
As new analyses are published, refresh the page to see the analysis files added. 

	For convenience, multiple analyses can be published with this simple command:

	```bash
	make test-workflow
	```

## <a name="license"></a>License
Copyright (c) 2020. Ontario Institute for Cancer Research

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

[Back to Contents](#toc)
