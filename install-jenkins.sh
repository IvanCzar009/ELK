#!/bin/bash
# install-jenkins.sh - Script to install Jenkins using Docker

echo "=== Starting Jenkins Installation ==="

# Create Jenkins data directory
echo "Creating Jenkins data directory..."
sudo mkdir -p /opt/jenkins/data
sudo chown -R 1000:1000 /opt/jenkins/

# Create Jenkins network
echo "Creating Jenkins Docker network..."
docker network create jenkins-network

# Install Jenkins
echo "Installing Jenkins..."
docker run -d \
  --name jenkins \
  --network jenkins-network \
  -p 8080:8080 \
  -p 50000:50000 \
  -v /opt/jenkins/data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(which docker):/usr/bin/docker \
  --group-add $(getent group docker | cut -d: -f3) \
  jenkins/jenkins:lts-jdk11

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
sleep 60

# Wait for Jenkins to be fully ready
echo "Waiting for Jenkins to be fully ready..."
while ! curl -s http://localhost:8080/login > /dev/null; do
  echo "Jenkins is starting up..."
  sleep 10
done

# Get initial admin password
echo "=== Jenkins Initial Setup ==="
echo "Getting Jenkins initial admin password..."
JENKINS_PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null)

if [ -n "$JENKINS_PASSWORD" ]; then
  echo "Jenkins Initial Admin Password: $JENKINS_PASSWORD"
  echo "Save this password! You'll need it for the initial setup."
else
  echo "Could not retrieve initial admin password. Check Jenkins logs:"
  docker logs jenkins --tail 50
fi

# Install recommended plugins via CLI
echo "Installing Jenkins plugins..."
sleep 30

# Install essential plugins
docker exec jenkins jenkins-plugin-cli --plugins \
  blueocean \
  build-timeout \
  credentials-binding \
  timestamper \
  ws-cleanup \
  ant \
  gradle \
  workflow-aggregator \
  github-branch-source \
  pipeline-github-lib \
  pipeline-stage-view \
  git \
  github \
  sonar \
  publish-over-ssh \
  deploy \
  maven-plugin \
  junit \
  jacoco \
  html-publisher \
  email-ext \
  mailer \
  docker-workflow \
  docker-plugin

# Restart Jenkins to apply plugins
echo "Restarting Jenkins to apply plugins..."
docker restart jenkins

# Wait for Jenkins to be ready again
echo "Waiting for Jenkins to restart..."
sleep 60
while ! curl -s http://localhost:8080/login > /dev/null; do
  echo "Jenkins is restarting..."
  sleep 10
done

# Check Jenkins status
echo "=== Jenkins Installation Status ==="
echo "Jenkins is running on: http://localhost:8080"
echo "Jenkins container status:"
docker ps | grep jenkins

# Display Jenkins logs for verification
echo "Recent Jenkins logs:"
docker logs jenkins --tail 20

echo "=== Jenkins Installation Complete ==="
echo "Access Jenkins at: http://localhost:8080"
echo "Initial Admin Password: $JENKINS_PASSWORD"

# Health check
echo "Jenkins health check:"
curl -s -I http://localhost:8080 | head -n 1