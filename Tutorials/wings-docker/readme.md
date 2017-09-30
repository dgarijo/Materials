# Sharing WINGS workflows with Docker

**Authors**: Daniel Garijo, Varun Ratnakar and Rajiv Mayani.

**Goals**: This tutorial aims to capture the different ways of sharing scientific workflows with [WINGS](http://wings-workflows.org/) and [Docker](http://docker.com/).

**Requirements**: Have [Docker](http://docker.com/) installed.

## Table of contents
0. [Glossary of terms](#sec0)
1. [Sharing a single component](#sec1)
	1. [Building a wrapper to run a Docker image of our component](#sec1-1)
2. [Sharing a WINGS instance with pre-installed software](#sec2)
    1. [Run WINGS as a Docker image with existing software](#sec2-1)
	2. [Copy results produced by the executions of multiple workflows into your local computer](#sec2-2)
3. [Import a WINGS' domain into a WINGS dockerized image](#sec2-3)
4. [Run dockerized components in the WINGS Docker image, (i.e., upload custom Docker images of components in WINGS)](#sec2-4)
5. [Save workflow descriptions in a new Docker image](#sec2-5) 
	1. [Upload your image to DockerHub](#sec2-6) 

## Glossary of terms <a name="sec0"></a>
Throughout this tutorial we will be using a common set of terms, which is defined further below:

**Workflow component**: Identifies a script that is used to perform a computational step in your experiment. For example, if in your experiment you need to filter the data and use a script for that, we can consider that script a workflow component.

**Scientific workflow**: A set of components and their corresponding dependencies. In data-oriented experiments, scientific workflows tend to be represented as directed acyclic graphs, where the nodes represent components and data inputs and outputs, and the edges represent their connections. 

**Workflow system**: Framework that can design and use workflow specifications to execute them and produce the results. 

**WINGS**: The workflow system we will be using in this tutorial


## Sharing a single component <a name="sec1"></a>
Scientists usually describe the set of components or scripts they develop in a computational experiment for two main reasons: 1) To be able to reproduce their own experiments in the future and 2) to share these components with the rest of the scientific community. However, components often have dependencies and use particular types of data in their executions, being difficult to re-execute in other computers. 

In this section of the tutorial we aim to upload a dockerized version of our component to WINGS without having to install all the dependencies on the server ourselves.

### Building a wrapper to run a Docker image of our component <a name="sec1-1"></a>
There are two ways of running components in WINGS through Docker, and for both of them you first need to **install Docker on the WINGS server**. Then, the first option is to create a Docker file for your image, and use the name of that Docker file in your component. The second option is to directly import a Docker image from an external repository like DockerHub. 

A tutorial covering both approaches can be found in the following link:
https://dgarijo.github.io/Materials/Tutorials/stanford5Dec2016/#software2


## Sharing a WINGS instance with pre-installed software <a name="sec2"></a>
When you want to deploy your workflows in your local infrastructure, the best way to do so is to install an existing WINGS image with pre-installed software, workflows and dependencies. The workflows should be able to run, and you should be able to create new workflows and upload the appropriate data.
There are different actions that you might be interested in:
1. [Run WINGS as a Docker image with existing software](#sec2-1)
2. [Copy results produced by the executions of multiple workflows into your local computer](#sec2-2)
3. [Import a domain into a WINGS dockerized image](#sec2-3)
4. [Run dockerized components from the WINGS Docker image, (i.e., upload Docker images of components)](#sec2-4)

### Running WINGS as a Docker image  <a name="sec2-1"></a>

#### Alternative one: Pull the docker image from the WINGS repository
Execute the following to pull the image we built:

```docker pull kcapd/wings-base```

or, if you are interested in an image with pre-installed genomics components (such as TopHat, samtools, etc.), try: ```docker pull kcapd/wings-genomics```

(Jump to the ["Running the Docker image" section](#run))

#### Alternative two: Build the docker image yourself
The following [Docker file](https://dgarijo.github.io/Materials/Tutorials/wings-docker/resources/Dockerfile) defines WINGS and its dependencies. 

```
FROM debian:jessie
RUN sed -i 's/debian testing main/debian testing main contrib non-free/' /etc/apt/sources.list

# Install general tools
RUN apt-get update
RUN apt-get -y install graphviz unzip curl libssl-dev libcurl4-openssl-dev libxml2-dev python-pip tomcat8 git cgroupfs-mount maven

# Install WINGS
RUN mkdir -p /opt/wings/storage/default
ADD ./config/default/wings-portal.xml /etc/tomcat8/Catalina/localhost/wings-portal.xml
ADD ./config/default/portal.properties /opt/wings/storage/default/portal.properties
RUN mkdir /wings-src
ADD ./config/pom.xml /wings-src/pom.xml
RUN cd /wings-src && mvn package
RUN cp -R /wings-src/target/wings-portal-4.0 /opt/wings/server
RUN sed -i 's/Resource name="UserDatabase" auth/Resource name="UserDatabase" readonly="false" auth/' /etc/tomcat8/server.xml
RUN sed -i 's/=tomcat8/=root/' /etc/default/tomcat8
RUN sed -i 's/<\/tomcat-users>/  <user username="admin" password="4dm1n!23" roles="WingsUser,WingsAdmin"\/>\n<\/tomcat-users>/' /etc/tomcat8/tomcat-users.xml
ADD http://www.wings-workflows.org/downloads/docker/latest/portal/setenv.txt /setenv.sh
EXPOSE 8080

# Install Docker
RUN apt-get -y install --no-install-recommends apt-transport-https ca-certificates software-properties-common gnupg2
RUN curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | apt-key add -
RUN add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
   $(lsb_release -cs) \
   stable"
RUN apt-get update && apt-get -y install docker-ce

# Start WINGS
RUN chmod 755 /setenv.sh 
CMD /setenv.sh && service tomcat8 start && /bin/bash
```
**Remarks**: This Docker file also installs Docker, so we can run dockerized components within our container as well.

**Time to buid**: 10-15 min (depending on your internet connection). Size: 1.08 GB. The Docker file sets up the WINGS environment. 

Now you just have to build the docker image:

``` 
docker build -t [IMAGE_NAME] .
```
The IMAGE_NAME should be the name of the image. In my case I called it ```wings:latest```


#### Running the Docker image <a name="run"></a> 

Run the file [(download start-wings.sh)](https://dgarijo.github.io/Materials/Tutorials/wings-docker/resources/start-wings.sh) : 

```bash
# If [NAME] is not specified, it defaults to wings.
./start-wings.sh [NAME]
```

This file will execute the container with the following options (it is assumed that the image name is kcapd/wings-base:latest):

```bash
docker run --interactive \
               --tty \
               --env WINGS_MODE='dind' \
               --volume "${NAME}_vol":/opt/wings \
               --name ${NAME} \
               --publish 8080:8080 \
               ${ARGS} wings:latest
```
**Note:** If you pulled the image from the kcapd repository, use "kcapd/wings-base" instead of "wings:latest".

If you want to stop the WINGS container, execute the following command:

```bash
docker stop wings
```

**Attention: If you remove a container execution, you will delete the data, workflows and executions created on it. You can stop the execution without an issue.** See [Section 5](#sec2-5) to save your changes in the image.

If you start and stop your container several times, sometimes the volume is not mounted correctly and leads to errors. In those cases you should remove your volume: 

```bash
docker volume rm wings_vol
```
And call the ```start-wings.sh``` script again

**Attention: If you remove the volume, you will delete the data, workflows and executions created on the container.** See [Section 5](#sec2-5) to save your changes in the image.

Accessing the web interface from the Docker image: ```http://localhost:8080/wings-portal```

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

3. Go to http://www.wings-workflows.org/domains/ and select the URL of the domain to download. This tutorial has been tested successfully with the domain in students/CaesarCypher.zip, running the CaesarCypher workflow (it has no infrastructure dependencies). Other domains may have particular infrastructure requirements that would need to be installed on your Docker image.  

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

You can download [the component](https://dgarijo.github.io/Materials/Tutorials/wings-docker/resources/msort.zip) and a [sample file](https://dgarijo.github.io/Materials/Tutorials/wings-docker/resources/canary_test.bam) from this [github repository](https://github.com/dgarijo/Materials/tree/master/Tutorials/wings-docker/resources) as well.

### Save installed software in your image <a name="sec2-5"></a>

Imagine that you have installed additional software on your WINGS container, and now you want to preserve it. You have to follow the following steps:

1. Execute ```docker ps``` and save the container id of your wings:latest image.

2. Execute ```docker commit <container_id> <image name>```. For example, in my particular case this was:  ```docker commit f4723e4febb8 wings:latest```, because I wanted to save the image under the wings:latest name.

And that's all. Now, next time you start the [start-wings.sh script](https://dgarijo.github.io/Materials/Tutorials/wings-docker/resources/start-wings.sh), you will have all you commited changes available in the WINGS image. 

**Remember:** If you want to preserve further changes, you will have to commit them every time. The commit operation will not include any data contained in volumes mounted inside the container. If you want to preserve any data or workflow descriptions, you should copy the /opt/wings/storage folder into your computer (e.g., as we have done in [Section 2.2](#sec2-2)) and then copy it back when you load your image.


### Upload your image to DockerHub <a name="sec2-6"></a>

Once you have an image ready, the next step is to make it available online. First, you need to [create a Docker id](https://docs.docker.com/docker-id/), which will allow you to register images on the Docker cloud. Then, you just have to follow the steps [indicated in the Docker documentation](https://docs.docker.com/docker-cloud/builds/push-images/) to push your image online.






