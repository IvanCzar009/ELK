#!/bin/bash
# install-sonarqube.sh - Script to install SonarQube using Docker

echo "=== Starting SonarQube Installation ==="

# Create SonarQube data directories
echo "Creating SonarQube data directories..."
sudo mkdir -p /opt/sonarqube/data
sudo mkdir -p /opt/sonarqube/logs
sudo mkdir -p /opt/sonarqube/extensions
sudo chown -R 999:999 /opt/sonarqube/

# Create SonarQube network
echo "Creating SonarQube Docker network..."
docker network create sonarqube-network

# Install PostgreSQL for SonarQube
echo "Installing PostgreSQL database for SonarQube..."
docker run -d \
  --name sonarqube-db \
  --network sonarqube-network \
  -e POSTGRES_USER=sonarqube \
  -e POSTGRES_PASSWORD=sonarqube \
  -e POSTGRES_DB=sonarqube \
  -v /opt/sonarqube/postgresql:/var/lib/postgresql/data \
  postgres:13

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
sleep 30

# Install SonarQube
echo "Installing SonarQube..."
docker run -d \
  --name sonarqube \
  --network sonarqube-network \
  -p 9000:9000 \
  -e SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonarqube \
  -e SONAR_JDBC_USERNAME=sonarqube \
  -e SONAR_JDBC_PASSWORD=sonarqube \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  -v /opt/sonarqube/data:/opt/sonarqube/data \
  -v /opt/sonarqube/logs:/opt/sonarqube/logs \
  -v /opt/sonarqube/extensions:/opt/sonarqube/extensions \
  sonarqube:community

# Wait for SonarQube to start
echo "Waiting for SonarQube to start..."
sleep 120

# Wait for SonarQube to be fully ready
echo "Waiting for SonarQube to be fully ready..."
RETRY_COUNT=0
MAX_RETRIES=30

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; then
    echo "SonarQube is ready!"
    break
  else
    echo "SonarQube is starting up... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT + 1))
  fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "SonarQube failed to start within expected time. Check logs:"
  docker logs sonarqube --tail 50
fi

# Check SonarQube status
echo "=== SonarQube Installation Status ==="
echo "SonarQube is running on: http://localhost:9000"
echo "Default credentials: admin/admin"
echo "SonarQube container status:"
docker ps | grep sonarqube

# Create admin token for Jenkins integration
echo "Creating SonarQube admin token..."
sleep 10

# Generate a random token name
TOKEN_NAME="jenkins-integration-$(date +%s)"

# Create token using API
SONAR_TOKEN=$(curl -s -u admin:admin -X POST "http://localhost:9000/api/user_tokens/generate" \
  -d "name=$TOKEN_NAME" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$SONAR_TOKEN" ]; then
  echo "SonarQube token created successfully!"
  echo "Token name: $TOKEN_NAME"
  echo "Token: $SONAR_TOKEN"
  echo "Save this token for Jenkins integration!"
  
  # Save token to file for later use
  echo "$SONAR_TOKEN" > /opt/sonarqube/jenkins-token.txt
  echo "Token saved to: /opt/sonarqube/jenkins-token.txt"
else
  echo "Failed to create SonarQube token. You may need to create it manually."
  echo "Go to http://localhost:9000 -> Administration -> Security -> Users -> Tokens"
fi

# Display SonarQube logs for verification
echo "Recent SonarQube logs:"
docker logs sonarqube --tail 20

echo "=== SonarQube Installation Complete ==="
echo "Access SonarQube at: http://localhost:9000"
echo "Default credentials: admin/admin"

# Health check
echo "SonarQube health check:"
curl -s http://localhost:9000/api/system/status | grep -o '"status":"[^"]*"'

# Restart SonarQube to ensure it's running properly
echo "Restarting SonarQube to ensure proper startup..."
docker restart sonarqube
sleep 60

echo "=== SonarQube Ready ==="