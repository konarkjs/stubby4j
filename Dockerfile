# A few useful Docker commands to build an image and run the stubby4j container.
#
# Build (run with '--no-cache' to ensure that Git repo new tags will be pulled down, as Docker caches RUNs):
# 'docker build --no-cache -t stubby4j:latest .'
#
# Run:
# 'docker run -p 8882:8882 -p 8889:8889 -p 7443:7443 stubby4j'

########################################################################################
# Stage 1 : build the app
########################################################################################
FROM gradle:6.7.1-jdk8-openj9 AS BUILD_JAR_STAGE
MAINTAINER azagniotov@gmail.com
ENV GRADLE_USER_HOME=/home/gradle
WORKDIR $GRADLE_USER_HOME

# Build from the latest tag
RUN git clone https://github.com/azagniotov/stubby4j.git && \
      cd stubby4j && \
      git fetch --tags && \
      LATEST_RELEASE_TAG="$(git tag --sort=committerdate | tail -1)" && \
      git checkout "$LATEST_RELEASE_TAG" && \
      gradle clean jar

########################################################################################
# Stage 2 : create the Docker final image
########################################################################################
FROM adoptopenjdk/openjdk8-openj9:alpine
ENV stubby4j=stubby4j
ENV STUBBY4J_USER_HOME=/home/$stubby4j

# Why --location=0.0.0.0 ??? Read: https://stackoverflow.com/a/59182290
ENV LOCATION=0.0.0.0
# To disable debug output, just set the ARG to an empty string
ENV WITH_DEBUG="--debug"
ENV STUBS_PORT=8882
ENV STUBS_TLS_PORT=7443
ENV ADMIN_PORT=8889

# Users & permissions
RUN addgroup -S $stubby4j && adduser -S $stubby4j -G $stubby4j
USER $stubby4j:$stubby4j
COPY --from=BUILD_JAR_STAGE /home/gradle/$stubby4j/build/libs/$stubby4j*SNAPSHOT.jar "${STUBBY4J_USER_HOME}/${stubby4j}.jar"

WORKDIR $STUBBY4J_USER_HOME
# Expose three ports and run the JAR
EXPOSE $ADMIN_PORT $STUBS_PORT $STUBS_TLS_PORT

ENTRYPOINT java -jar "${stubby4j}.jar" \
      --location ${LOCATION} \
      --admin ${ADMIN_PORT} \
      --stubs ${STUBS_PORT} \
      --tls ${STUBS_TLS_PORT} \
      ${WITH_DEBUG}
