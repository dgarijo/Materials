# Sharing WINGS workflows with Docker

This tutorial aims to capture the different ways of sharing workflows with WINGS and Docker.

## Table of contents
1. [Sharing a single component](#sec1)
	1. [Building a wrapper to run a Docker image of our component](#sec1-1)
2. [Sharing a WINGS instance with pre-installed software](#sec2)
    1. [Run WINGS as a Docker image with existing software](#sec2-1)
	2. [Copy results produced by the executions of multiple workflows into your local computer](#sec2-2)
	3. [Import a domain into a WINGS dockerized image](#sec2-3)
	4. [Run dockerized components from the WINGS Docker image, (i.e., upload Docker images of components](#sec2-4)
	5. [Save workflow descriptions in a new Docker image (Not included at the moment)](#sec2-5) 

## Sharing a single component <a name="sec1"></a>
Scientists usually write components in order to share them with other scientists. These components often have dependencies and use particular types of data in their executions. In this scenario, we aim to share a WINGS workflow component into an existing WINGS instance deployed in a server, or upload a dockerized version of our component to WINGS without having to install anything on the server ourselves.

### Building a wrapper to run a Docker image of our component <a name="sec1-1"></a>
There are two ways of running components in WINGS through Docker, and for both of them you first need to **install Docker on the WINGS server**. Then, the first option is to create a Docker file for your image, and use the name of that Docker file in your script. 

The second option is to directly import a Docker image from an external repository like DockerHub. A tutorial summarizes both approaches in the following link:
https://dgarijo.github.io/Materials/Tutorials/stanford5Dec2016/#software2


## Sharing a WINGS instance with pre-installed software <a name="sec2"></a>
When you want to deploy your workflows in your local infrastructure, the best way to do so is to install an existing WINGS image with pre-installed software, workflows and dependencies. The workflows should be able to run, and you should be able to create new workflows and upload the appropriate data.
There are different actions that you might be interested in:
1. [Run WINGS as a Docker image with existing software](#sec2-1)
2. [Copy results produced by the executions of multiple workflows into your local computer](#sec2-2)
3. [Import a domain into a WINGS dockerized image](#sec2-3)
4. [Run dockerized components from the WINGS Docker image, (i.e., upload Docker images of components](#sec2-4)

### Running WINGS as a Docker image  <a name="sec2-1"></a>	
The following [Docker file](https://dgarijo.github.io/Materials/Tutorials/wings-docker/resources/Dockerfile) defines WINGS and its dependencies, plus some additional software:

```
FROM r-base
MAINTAINER Varun Ratnakar <varunratnakar@gmail.com>
RUN sed -i 's/debian testing main/debian testing main contrib non-free/' /etc/apt/sources.list
RUN apt-get update
# Modified by Rajiv: Start
RUN userdel docker && apt-get -y install graphviz curl unzip curl openssl libssl-dev libcurl4-openssl-dev libxml2-dev python-pip tomcat8 docker.io
# Modified by Rajiv: End
RUN apt-get -y install samtools tophat cufflinks
RUN pip install RSeQC
RUN mkdir -p /opt/wings/storage/default /opt/wings/server
ADD http://www.wings-workflows.org/downloads/docker/latest/portal/wings-portal.xml /etc/tomcat8/Catalina/localhost/wings-portal.xml
ADD http://www.wings-workflows.org/downloads/docker/latest/portal/portal.properties /opt/wings/storage/default/portal.properties
RUN cd /opt/wings/server && curl -O http://www.wings-workflows.org/downloads/docker/latest/portal/wings-portal.war && unzip wings-portal.war && rm wings-portal.war
RUN sed -i 's/Resource name="UserDatabase" auth/Resource name="UserDatabase" readonly="false" auth/' /etc/tomcat8/server.xml
RUN sed -i 's/=tomcat8/=root/' /etc/default/tomcat8
RUN sed -i 's/<\/tomcat-users>/  <user username="admin" password="4dm1n!23" roles="WingsUser,WingsAdmin"\/>\n<\/tomcat-users>/' /etc/tomcat8/tomcat-users.xml
ADD http://www.wings-workflows.org/downloads/docker/latest/domain/R-install.R /tmp/R-install.R
RUN Rscript /tmp/R-install.R
# Added by Rajiv: Start
ADD ./setenv.sh /setenv.sh
EXPOSE 8080
# Added by Rajiv: End
CMD /setenv.sh && service tomcat8 start && /bin/bash
```
**Remarks**: This Docker file also installs samtools and tophat, so it’s somewhat heavyweight. It also installs Docker, so we can run dockerized components within our container as well.

**Time to buid**: 10-15 min (depending on your internet connection). Size: 1.56 GB. The Docker file sets up the WINGS environment. 

Guidelines:

1. Building the docker image:
``` 
docker build -t [IMAGE_NAME] .
```
The IMAGE_NAME should be the name of the image. In my case I called it ```wings:latest```

2. Running the Docker image. Just run the file [(download start-wings.sh)](https://dgarijo.github.io/Materials/Tutorials/wings-docker/resources/start-wings.sh) : 

```bash
# If [NAME] is not specified, it defaults to wings.
./start-wings.sh [NAME]
```

This file will execute the container with the following options (it is assumed that the image name is wings:latest):

```bash
docker run --interactive \
               --tty \
               --env WINGS_MODE='dind' \
               --volume "${NAME}_vol":/opt/wings \
               --name ${NAME} \
               --publish 8080:8080 \
               ${ARGS} wings:latest
```

If you start and stop your container several times, sometimes the volume is not mounted correctly and leads to errors. In those cases you should remove your volume: 

```bash
docker volume rm wings_vol
```
And call the ```start-wings.sh``` script again

**Attention: If you remove a container execution, you will delete the data, workflows and executions created on it.**

3. Accessing the web interface from the Docker image: ```http://localhost:8080/wings-portal```

### Copy results from different executions into your local computer <a name="sec2-2"></a>

You can access the results from your workflows, using the web browser: ```http://localhost:8080/wings-portal```, going to "Analysis->Access Runs" or "Advanced ->Manage Data". Whenever a file is downloaded, it will be saved to your local computer.

In order to save the results from your WINGS dockerized image, you have to **mount another volume**. The volume will be used to copy the results of the workflow to your localhost computer:

1.	Edit the ```start-wings.sh``` script adding another volume after the ```--volume "${NAME}_vol":/opt/wings \``` line: 

```bash
--volume "c:/Users/dgarijo/Desktop/sharedFolder":/out \
```
In the tutorial we are sharing a folder on the local computer on path ```c:/Users/dgarijo/Desktop/sharedFolder```. The shared folder in the container will be called ```out```

2. Execute the ```start-wings.sh```

3. Select the folder with results that you want to copy. Unless the Dockerfile is changed, it should be on 
```
cd /opt/wings/storage/default/users/username/domain/
```
4. Copy the results you want to the mounted volume: 
```
cp /opt/wings/storage/default/users/admin/blank/data/out1.txt /out/out1.txt
```

Those result will appear on your shared folder.

### Importing an existing domain inside the WINGS Docker image <a name="sec2-3"></a>

This functionality can be done as if we did it through the portal:

1. Go to ```http://localhost:8080/wings-portal/users/admin/domains```

2. Click on ```Add``` and ```Import domain```. 

3. Go to http://www.wings-workflows.org/domains/ and select the URL of the domain to download.

4. Click submit and wait until the domain is imported. It should appear shortly after in your domain list.

### Running Docker components inside the WINGS Docker image <a name="sec2-4"></a>
You can run dockerized components inside the WINGS Docker image too. Since we already introduced in another tutorial how to create an image with your components (see https://dgarijo.github.io/Materials/Tutorials/stanford5Dec2016/#software2), here we will just show how to reuse existing images.

In this case we are going to use the "sort" function included in the samtools package. We will reuse the image: comics/samtools, stored in [Dockerhub](https://hub.docker.com/). Your "run.sh" file should look like:

```bash
#!/bin/bash

checkExitCode() {
 if [ $? -ne 0 ]; then
     echo "Error"
     exit 1;
 fi
}

BASEDIR=`dirname $0`
. $BASEDIR/io.sh 1 0 1 "$@"

env

if [ "${WINGS_MODE}" == "dind" ]; then
set -x
    echo "Docker Mode"
    if [ -e ${BASEDIR}/Dockerfile ]; then
        pushd ${BASEDIR} > /dev/null
        docker build --tag html2text .
        popd > /dev/null
    fi

    docker run --volumes-from ${HOSTNAME} comics/samtools samtools sort -o $OUTPUTS1 $INPUTS1
    checkExitCode
	exit 0
fi
```

You can download [the component](https://dgarijo.github.io/Materials/Tutorials/wings-docker/resources/msort.zip) and a [sample file](https://dgarijo.github.io/Materials/Tutorials/wings-docker/resources/canary_test.bam) from this [github repository](https://github.com/dgarijo/Materials/tree/master/Tutorials/wings-docker/resources) as well






