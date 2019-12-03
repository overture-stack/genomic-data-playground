Welcome to the Overture Genomic Data Playground!
---

The purpose of this repository is to provide a sandbox for users to play with some of Overture's genomic services, such as Song, Score and Ego. 
Every release contains a stable and tested configuration of various Overture products using absolute versions, so that specific configurations can be reproduced. 
The services are managed by `docker-compose` and are bootstrapped with fixed data so that users can start playing around as fast as possible.

## System Requirements
- docker engine version >= **18.06.0**
- docker-compose version >= **1.22.0**
- compose file format version >= **3.7**
- bash

## Architecture
There are 3 core Overture services running: [Song](https://www.overture.bio/products/song), [Ego](https://www.overture.bio/products/ego), [Score](https://www.overture.bio/products/score). 

For Score the back-end object storage service that was used was [Minio](https://min.io/). For Song and Ego, `postgreSQL` was used as the database technology.

In addition, Song was configured to interact an example ID service. This is an **optional** configuration and is used to demonstrate Song's ability delegate ID generation to any external ID service. 

For more information on these services, visit the [Song documentation](https://song-docs.readthedocs.io), [Ego documentation](https://ego.readthedocs.io) and [Score documentation](https://score-docs.readthedocs.io). 

Insert image here

## Configuration
The following configurations
### Ego
- ego access token
- user id and infor
### Score
### Song
### Object Storage
- minio

## Usage
### Starting All Services and Initializing Data
### Destroying All Services and Data
### Service Interaction
#### Song
#### Score

## Examples
### Submit a payload using the song-client
### Generate a manifest using the song-client
### Upload the manifest using the score-client
### Publish the analysis using the song-client


Example
```bash

# manifest.txt located in /data dir
# files to be uploaded located in /data/example dir

./score-client upload --manifest /data/manifest.txt
```

## License
Copyright (c) 2019. Ontario Institute for Cancer Research

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
