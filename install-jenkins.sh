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

# Install Node.js in Jenkins container for React app builds
echo "=== Installing Node.js in Jenkins Container ==="
echo "Installing Node.js 18.x for React app builds..."
docker exec -u 0 jenkins bash -c 'curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt-get install -y nodejs'

# Verify Node.js installation
echo "Verifying Node.js installation..."
NODE_VERSION=$(docker exec jenkins node --version 2>/dev/null || echo "Not installed")
NPM_VERSION=$(docker exec jenkins npm --version 2>/dev/null || echo "Not installed")
echo "Node.js version: $NODE_VERSION"
echo "npm version: $NPM_VERSION"

if [[ "$NODE_VERSION" != "Not installed" ]]; then
  echo "✅ Node.js successfully installed in Jenkins container"
else
  echo "❌ Node.js installation failed"
fi

# Install SonarQube Scanner for Jenkins container using Docker
echo "=== Setting up SonarQube Scanner via Docker ==="
echo "Pulling SonarQube Scanner Docker image..."

# Pull the official SonarQube Scanner Docker image
docker pull sonarsource/sonar-scanner-cli:latest

# Verify the image is available
if docker images | grep -q "sonarsource/sonar-scanner-cli"; then
    echo "✅ SonarQube Scanner Docker image ready"
    
    # Create a script wrapper for easy scanner execution
    docker exec jenkins mkdir -p /usr/local/bin
    docker exec jenkins bash -c 'cat > /usr/local/bin/sonar-scanner-docker << '"'"'EOF'"'"'
#!/bin/bash
# SonarQube Scanner Docker wrapper
# Usage: sonar-scanner-docker [sonar-scanner-arguments]

WORKSPACE_DIR="${PWD}"
SONAR_HOST_URL="${SONAR_HOST_URL:-http://host.docker.internal:9000}"

echo "🔍 Running SonarQube Scanner via Docker..."
echo "📁 Workspace: ${WORKSPACE_DIR}"
echo "🌐 SonarQube URL: ${SONAR_HOST_URL}"

docker run --rm \
    --network="host" \
    -v "${WORKSPACE_DIR}:/usr/src" \
    -w /usr/src \
    sonarsource/sonar-scanner-cli:latest "$@"
EOF'
    
    # Make the wrapper executable
    docker exec jenkins chmod +x /usr/local/bin/sonar-scanner-docker
    
    echo "✅ SonarQube Scanner Docker wrapper created at /usr/local/bin/sonar-scanner-docker"
else
    echo "❌ Failed to pull SonarQube Scanner Docker image"
fi

# Also install npm sonar-scanner as fallback
echo "Installing npm sonar-scanner as fallback..."
docker exec jenkins npm install -g sonar-scanner

# Verify installations
echo "Verifying SonarQube Scanner installations..."
DOCKER_SCANNER=$(docker exec jenkins test -f /usr/local/bin/sonar-scanner-docker && echo "Available" || echo "Not found")
NPM_SCANNER=$(docker exec jenkins npm list -g sonar-scanner >/dev/null 2>&1 && echo "Available" || echo "Not found")

echo "SonarQube Scanner Docker: $DOCKER_SCANNER"
echo "SonarQube Scanner NPM: $NPM_SCANNER"

if [[ "$DOCKER_SCANNER" == "Available" || "$NPM_SCANNER" == "Available" ]]; then
  echo "✅ SonarQube Scanner successfully configured in Jenkins container"
else
  echo "❌ SonarQube Scanner installation failed"
fi

# Copy SonarQube credentials to Jenkins container
echo "Setting up SonarQube integration credentials..."
docker exec jenkins mkdir -p /var/jenkins_home/.sonarqube
docker exec jenkins bash -c 'echo "SONAR_HOST_URL=http://localhost:9000" > /var/jenkins_home/.sonarqube/config'
docker exec jenkins bash -c 'echo "SONAR_LOGIN=admin" >> /var/jenkins_home/.sonarqube/config'
docker exec jenkins bash -c 'echo "SONAR_PASSWORD=admin" >> /var/jenkins_home/.sonarqube/config'
echo "✅ SonarQube credentials configured for Jenkins"

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