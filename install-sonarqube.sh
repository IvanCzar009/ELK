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

# Create Group6-react-app project automatically
echo "=== Creating Group6-react-app Project ==="
PROJECT_KEY="group6-react-app"
PROJECT_NAME="Group 6 React Application"

# Wait for SonarQube API to be fully ready for project creation
echo "Waiting for SonarQube API to be ready for project operations..."
sleep 20

# Function to check if project exists
check_project_exists() {
  local project_key=$1
  local exists_count=$(curl -s -u admin:admin "http://localhost:9000/api/projects/search?q=${project_key}" 2>/dev/null | grep -c "\"key\":\"${project_key}\"" || echo "0")
  echo $exists_count
}

# Check if project already exists
echo "Checking if project '${PROJECT_KEY}' already exists..."
PROJECT_EXISTS=$(check_project_exists "$PROJECT_KEY")

if [ "$PROJECT_EXISTS" -eq "0" ]; then
  echo "Creating new SonarQube project: ${PROJECT_NAME}"
  
  # Create the project
  CREATE_RESULT=$(curl -s -u admin:admin -X POST "http://localhost:9000/api/projects/create" \
    -d "project=${PROJECT_KEY}" \
    -d "name=${PROJECT_NAME}" \
    -d "visibility=private" 2>/dev/null)
  
  # Wait a moment for project to be created
  sleep 5
  
  # Verify project creation
  VERIFY_EXISTS=$(check_project_exists "$PROJECT_KEY")
  
  if [ "$VERIFY_EXISTS" -gt "0" ]; then
    echo "✅ Project '${PROJECT_NAME}' created successfully!"
    echo "   Project Key: ${PROJECT_KEY}"
    echo "   Access at: http://localhost:9000/dashboard?id=${PROJECT_KEY}"
    
    # Set up quality gate (use default quality gate)
    echo "Configuring quality gate for project..."
    curl -s -u admin:admin -X POST "http://localhost:9000/api/qualitygates/select" \
      -d "projectKey=${PROJECT_KEY}" \
      -d "gateId=1" >/dev/null 2>&1
    
    echo "✅ Quality gate configured for project"
    
    # Save project info
    echo "PROJECT_KEY=${PROJECT_KEY}" > /opt/sonarqube/group6-react-app-info.txt
    echo "PROJECT_NAME=${PROJECT_NAME}" >> /opt/sonarqube/group6-react-app-info.txt
    echo "PROJECT_URL=http://localhost:9000/dashboard?id=${PROJECT_KEY}" >> /opt/sonarqube/group6-react-app-info.txt
    echo "📁 Project info saved to: /opt/sonarqube/group6-react-app-info.txt"
    
  else
    echo "❌ Failed to create project. API Response: $CREATE_RESULT"
    echo "⚠️  You may need to create the project manually at: http://localhost:9000"
  fi
else
  echo "✅ Project '${PROJECT_NAME}' already exists (found ${PROJECT_EXISTS} matches)"
  echo "   Project Key: ${PROJECT_KEY}"
  echo "   Access at: http://localhost:9000/dashboard?id=${PROJECT_KEY}"
fi

# Final verification
echo "=== Project Setup Verification ==="
FINAL_CHECK=$(curl -s -u admin:admin "http://localhost:9000/api/projects/show?project=${PROJECT_KEY}" 2>/dev/null)
if echo "$FINAL_CHECK" | grep -q "\"key\":\"${PROJECT_KEY}\""; then
  echo "✅ Project verification successful - ready for Jenkins integration"
  echo "📊 SonarQube project '${PROJECT_KEY}' is ready for code analysis"
else
  echo "⚠️  Project verification inconclusive - check manually at http://localhost:9000"
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