#!/bin/bash
# install-tomcat.sh - Script to install Apache Tomcat using Docker

echo "=== Starting Tomcat Installation ==="

# Create Tomcat data directories
echo "Creating Tomcat data directories..."
sudo mkdir -p /opt/tomcat/webapps
sudo mkdir -p /opt/tomcat/logs
sudo mkdir -p /opt/tomcat/conf
sudo mkdir -p /opt/tomcat/work
sudo chown -R 1000:1000 /opt/tomcat/

# Create Tomcat network
echo "Creating Tomcat Docker network..."
docker network create tomcat-network

# Create custom server.xml for Tomcat configuration
echo "Creating Tomcat server configuration..."
cat > /opt/tomcat/conf/server.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

  <GlobalNamingResources>
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>

  <Service name="Catalina">
    <Connector port="8081" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />

    <Engine name="Catalina" defaultHost="localhost">
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <Host name="localhost"  appBase="webapps"
            unpackWARs="true" autoDeploy="true">
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b" />
      </Host>
    </Engine>
  </Service>
</Server>
EOF

# Create tomcat-users.xml for management interface
echo "Creating Tomcat users configuration..."
cat > /opt/tomcat/conf/tomcat-users.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <role rolename="admin-gui"/>
  <role rolename="admin-script"/>
  <user username="admin" password="admin123" roles="manager-gui,manager-script,manager-jmx,manager-status,admin-gui,admin-script"/>
  <user username="deployer" password="deployer123" roles="manager-script"/>
</tomcat-users>
EOF

# Create context.xml to allow manager access from any host
echo "Creating Tomcat context configuration..."
sudo mkdir -p /opt/tomcat/webapps/manager/META-INF
cat > /opt/tomcat/webapps/manager/META-INF/context.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <!--
  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" />
  -->
  <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|org\.apache\.catalina\.filters\.CsrfPreventionFilter\$LruCache(?:\$1)?|java\.util\.(?:Linked)?HashMap"/>
</Context>
EOF

# Install Tomcat
echo "Installing Tomcat..."
docker run -d \
  --name tomcat \
  --network tomcat-network \
  -p 8081:8081 \
  -v /opt/tomcat/webapps:/usr/local/tomcat/webapps \
  -v /opt/tomcat/logs:/usr/local/tomcat/logs \
  -v /opt/tomcat/conf/server.xml:/usr/local/tomcat/conf/server.xml \
  -v /opt/tomcat/conf/tomcat-users.xml:/usr/local/tomcat/conf/tomcat-users.xml \
  -e CATALINA_OPTS="-Xmx512m -XX:MaxPermSize=256m" \
  tomcat:9.0-jdk11

# Wait for Tomcat to start
echo "Waiting for Tomcat to start..."
sleep 30

# Wait for Tomcat to be fully ready
echo "Waiting for Tomcat to be fully ready..."
RETRY_COUNT=0
MAX_RETRIES=20

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if curl -s http://localhost:8081/ | grep -q "Apache Tomcat"; then
    echo "Tomcat is ready!"
    break
  else
    echo "Tomcat is starting up... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT + 1))
  fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "Tomcat failed to start within expected time. Check logs:"
  docker logs tomcat --tail 50
fi

# Deploy sample application
echo "Deploying sample application..."
cat > /opt/tomcat/webapps/ROOT/index.jsp <<EOF
<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
    <title>DevOps CI/CD Pipeline - Tomcat Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #d35400; text-align: center; }
        .info { background-color: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .status { color: #27ae60; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 DevOps CI/CD Pipeline</h1>
        <div class="info">
            <h3>Tomcat Application Server</h3>
            <p><strong>Status:</strong> <span class="status">✅ Running Successfully</span></p>
            <p><strong>Server:</strong> Apache Tomcat 9.0</p>
            <p><strong>Java Version:</strong> <%= System.getProperty("java.version") %></p>
            <p><strong>Server Time:</strong> <%= new java.util.Date() %></p>
            <p><strong>Deploy Path:</strong> /usr/local/tomcat/webapps/</p>
        </div>
        <div class="info">
            <h3>Deployment Information</h3>
            <p>This application is ready for CI/CD deployments via Jenkins.</p>
            <p><strong>Manager URL:</strong> <a href="/manager">Tomcat Manager</a></p>
            <p><strong>Credentials:</strong> admin/admin123</p>
        </div>
    </div>
</body>
</html>
EOF

# Check Tomcat status
echo "=== Tomcat Installation Status ==="
echo "Tomcat is running on: http://localhost:8081"
echo "Tomcat Manager: http://localhost:8081/manager"
echo "Manager credentials: admin/admin123"
echo "Deployer credentials: deployer/deployer123"
echo "Tomcat container status:"
docker ps | grep tomcat

# Display Tomcat logs for verification
echo "Recent Tomcat logs:"
docker logs tomcat --tail 20

echo "=== Tomcat Installation Complete ==="

# Health check
echo "Tomcat health check:"
curl -s -I http://localhost:8081 | head -n 1

# Test manager application
echo "Testing Tomcat Manager access..."
curl -s -u admin:admin123 http://localhost:8081/manager/text/list | head -5

# Restart Tomcat to ensure it's running properly
echo "Restarting Tomcat to ensure proper startup..."
docker restart tomcat
sleep 30

echo "=== Tomcat Ready ==="
echo "Access Tomcat at: http://localhost:8081"
echo "Access Tomcat Manager at: http://localhost:8081/manager"