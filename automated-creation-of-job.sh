#!/bin/bash
# automated-creation-of-job.sh - Script to create Jenkins pipeline jobs automatically

echo "=== Jenkins Job Creation Script ==="

# Configuration
JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD_FILE="/opt/jenkins/initial-password.txt"

# Check if Jenkins is running
if ! curl -s "$JENKINS_URL/login" > /dev/null; then
    echo "Jenkins is not accessible at $JENKINS_URL"
    exit 1
fi

# Get Jenkins password
if [ -f "$JENKINS_PASSWORD_FILE" ]; then
    JENKINS_PASSWORD=$(cat "$JENKINS_PASSWORD_FILE")
else
    echo "Jenkins password file not found. Using default setup."
    # In automated setup, we'll use API token after initial setup
    JENKINS_PASSWORD="admin"
fi

echo "Using Jenkins at: $JENKINS_URL"

# Wait for Jenkins to be fully ready
echo "Waiting for Jenkins to be fully ready..."
RETRY_COUNT=0
while [ $RETRY_COUNT -lt 30 ]; do
    if curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_URL/api/json" > /dev/null 2>&1; then
        echo "Jenkins API is ready!"
        break
    fi
    echo "Waiting for Jenkins API... (attempt $((RETRY_COUNT + 1))/30)"
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

# Install required plugins
echo "Installing Jenkins plugins..."
PLUGINS=(
    "workflow-aggregator"
    "pipeline-stage-view"
    "git"
    "github"
    "github-branch-source"
    "sonar"
    "publish-over-ssh"
    "deploy"
    "maven-plugin"
    "gradle"
    "junit"
    "jacoco"
    "html-publisher"
    "email-ext"
    "docker-workflow"
    "docker-plugin"
    "blueocean"
    "credentials-binding"
    "ssh-agent"
    "ansible"
)

for plugin in "${PLUGINS[@]}"; do
    echo "Installing plugin: $plugin"
    curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        "$JENKINS_URL/pluginManager/installNecessaryPlugins" \
        -d "<jenkins><install plugin='$plugin@latest' /></jenkins>" \
        -H "Content-Type: text/xml"
done

# Restart Jenkins to activate plugins
echo "Restarting Jenkins to activate plugins..."
curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_URL/safeRestart"

# Wait for Jenkins to restart
sleep 60
RETRY_COUNT=0
while [ $RETRY_COUNT -lt 30 ]; do
    if curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_URL/api/json" > /dev/null 2>&1; then
        echo "Jenkins restarted successfully!"
        break
    fi
    echo "Waiting for Jenkins to restart... (attempt $((RETRY_COUNT + 1))/30)"
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

# Create sample Maven project job
echo "Creating Sample Maven Pipeline Job..."
cat > /tmp/maven-pipeline-job.xml <<'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <actions/>
  <description>Sample Maven CI/CD Pipeline with SonarQube analysis and Tomcat deployment</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.plugins.jira.JiraProjectProperty plugin="jira@3.1.1"/>
    <com.dabsquared.gitlabjenkins.connection.GitLabConnectionProperty plugin="gitlab-plugin@1.5.12">
      <gitLabConnection></gitLabConnection>
    </com.dabsquared.gitlabjenkins.connection.GitLabConnectionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps@2.80">
    <script>
pipeline {
    agent any
    
    tools {
        maven 'Maven-3.6.3'
        jdk 'JDK-11'
    }
    
    environment {
        SONAR_SERVER = 'SonarQube-Server'
        TOMCAT_SERVER = 'Tomcat-Server'
        ARTIFACT_NAME = 'sample-app'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                // For demo purposes, we'll create a simple Maven project
                script {
                    writeFile file: 'pom.xml', text: '''
&lt;?xml version="1.0" encoding="UTF-8"?&gt;
&lt;project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd"&gt;
    &lt;modelVersion&gt;4.0.0&lt;/modelVersion&gt;
    
    &lt;groupId&gt;com.devops&lt;/groupId&gt;
    &lt;artifactId&gt;sample-app&lt;/artifactId&gt;
    &lt;version&gt;1.0-SNAPSHOT&lt;/version&gt;
    &lt;packaging&gt;war&lt;/packaging&gt;
    
    &lt;properties&gt;
        &lt;maven.compiler.source&gt;11&lt;/maven.compiler.source&gt;
        &lt;maven.compiler.target&gt;11&lt;/maven.compiler.target&gt;
        &lt;sonar.projectKey&gt;sample-app&lt;/sonar.projectKey&gt;
        &lt;sonar.projectName&gt;Sample Application&lt;/sonar.projectName&gt;
        &lt;sonar.projectVersion&gt;1.0&lt;/sonar.projectVersion&gt;
        &lt;sonar.sources&gt;src/main/java&lt;/sonar.sources&gt;
        &lt;sonar.tests&gt;src/test/java&lt;/sonar.tests&gt;
    &lt;/properties&gt;
    
    &lt;dependencies&gt;
        &lt;dependency&gt;
            &lt;groupId&gt;javax.servlet&lt;/groupId&gt;
            &lt;artifactId&gt;javax.servlet-api&lt;/artifactId&gt;
            &lt;version&gt;4.0.1&lt;/version&gt;
            &lt;scope&gt;provided&lt;/scope&gt;
        &lt;/dependency&gt;
        &lt;dependency&gt;
            &lt;groupId&gt;junit&lt;/groupId&gt;
            &lt;artifactId&gt;junit&lt;/artifactId&gt;
            &lt;version&gt;4.13.2&lt;/version&gt;
            &lt;scope&gt;test&lt;/scope&gt;
        &lt;/dependency&gt;
    &lt;/dependencies&gt;
    
    &lt;build&gt;
        &lt;plugins&gt;
            &lt;plugin&gt;
                &lt;groupId&gt;org.apache.maven.plugins&lt;/groupId&gt;
                &lt;artifactId&gt;maven-compiler-plugin&lt;/artifactId&gt;
                &lt;version&gt;3.8.1&lt;/version&gt;
            &lt;/plugin&gt;
            &lt;plugin&gt;
                &lt;groupId&gt;org.apache.maven.plugins&lt;/groupId&gt;
                &lt;artifactId&gt;maven-war-plugin&lt;/artifactId&gt;
                &lt;version&gt;3.2.3&lt;/version&gt;
            &lt;/plugin&gt;
            &lt;plugin&gt;
                &lt;groupId&gt;org.sonarsource.scanner.maven&lt;/groupId&gt;
                &lt;artifactId&gt;sonar-maven-plugin&lt;/artifactId&gt;
                &lt;version&gt;3.7.0.1746&lt;/version&gt;
            &lt;/plugin&gt;
            &lt;plugin&gt;
                &lt;groupId&gt;org.jacoco&lt;/groupId&gt;
                &lt;artifactId&gt;jacoco-maven-plugin&lt;/artifactId&gt;
                &lt;version&gt;0.8.6&lt;/version&gt;
                &lt;executions&gt;
                    &lt;execution&gt;
                        &lt;goals&gt;
                            &lt;goal&gt;prepare-agent&lt;/goal&gt;
                        &lt;/goals&gt;
                    &lt;/execution&gt;
                    &lt;execution&gt;
                        &lt;id&gt;report&lt;/id&gt;
                        &lt;phase&gt;test&lt;/phase&gt;
                        &lt;goals&gt;
                            &lt;goal&gt;report&lt;/goal&gt;
                        &lt;/goals&gt;
                    &lt;/execution&gt;
                &lt;/executions&gt;
            &lt;/plugin&gt;
        &lt;/plugins&gt;
    &lt;/build&gt;
&lt;/project&gt;
                    '''
                    
                    // Create source directories and files
                    sh 'mkdir -p src/main/java/com/devops'
                    sh 'mkdir -p src/main/webapp/WEB-INF'
                    sh 'mkdir -p src/test/java/com/devops'
                    
                    writeFile file: 'src/main/java/com/devops/HelloServlet.java', text: '''
package com.devops;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;

@WebServlet("/hello")
public class HelloServlet extends HttpServlet {
    
    public String getMessage() {
        return "Hello from DevOps CI/CD Pipeline!";
    }
    
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.setContentType("text/html");
        PrintWriter out = response.getWriter();
        out.println("&lt;html&gt;&lt;body&gt;");
        out.println("&lt;h1&gt;" + getMessage() + "&lt;/h1&gt;");
        out.println("&lt;p&gt;Build Number: " + System.getenv("BUILD_NUMBER") + "&lt;/p&gt;");
        out.println("&lt;p&gt;Build Time: " + new java.util.Date() + "&lt;/p&gt;");
        out.println("&lt;/body&gt;&lt;/html&gt;");
    }
}
                    '''
                    
                    writeFile file: 'src/main/webapp/WEB-INF/web.xml', text: '''
&lt;?xml version="1.0" encoding="UTF-8"?&gt;
&lt;web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee 
         http://xmlns.jcp.org/xml/ns/javaee/web-app_4_0.xsd"
         version="4.0"&gt;
    &lt;display-name&gt;Sample DevOps Application&lt;/display-name&gt;
&lt;/web-app&gt;
                    '''
                    
                    writeFile file: 'src/test/java/com/devops/HelloServletTest.java', text: '''
package com.devops;

import org.junit.Test;
import static org.junit.Assert.*;

public class HelloServletTest {
    
    @Test
    public void testGetMessage() {
        HelloServlet servlet = new HelloServlet();
        String message = servlet.getMessage();
        assertNotNull(message);
        assertTrue(message.contains("Hello"));
    }
}
                    '''
                }
            }
        }
        
        stage('Build') {
            steps {
                echo 'Building the application...'
                sh 'mvn clean compile'
            }
        }
        
        stage('Test') {
            steps {
                echo 'Running tests...'
                sh 'mvn test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'target/site/jacoco',
                        reportFiles: 'index.html',
                        reportName: 'Code Coverage Report'
                    ])
                }
            }
        }
        
        stage('Code Quality Analysis') {
            steps {
                echo 'Running SonarQube analysis...'
                script {
                    try {
                        withSonarQubeEnv('SonarQube-Server') {
                            sh 'mvn sonar:sonar'
                        }
                    } catch (Exception e) {
                        echo "SonarQube analysis failed: ${e.getMessage()}"
                        echo "Continuing with build..."
                    }
                }
            }
        }
        
        stage('Package') {
            steps {
                echo 'Packaging the application...'
                sh 'mvn package -DskipTests'
            }
            post {
                success {
                    archiveArtifacts artifacts: 'target/*.war', fingerprint: true
                }
            }
        }
        
        stage('Deploy to Tomcat') {
            steps {
                echo 'Deploying to Tomcat...'
                script {
                    try {
                        sh '''
                            # Copy WAR file to Tomcat webapps directory
                            docker cp target/sample-app-1.0-SNAPSHOT.war tomcat:/usr/local/tomcat/webapps/sample-app.war
                            
                            # Verify deployment
                            sleep 10
                            curl -f http://localhost:8081/sample-app/hello || echo "Deployment verification failed"
                        '''
                    } catch (Exception e) {
                        echo "Deployment failed: ${e.getMessage()}"
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
        
        stage('Integration Tests') {
            steps {
                echo 'Running integration tests...'
                script {
                    try {
                        sh '''
                            # Test the deployed application
                            response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/sample-app/hello)
                            if [ "$response" = "200" ]; then
                                echo "Integration test passed: Application is responding"
                            else
                                echo "Integration test failed: HTTP $response"
                                exit 1
                            fi
                        '''
                    } catch (Exception e) {
                        echo "Integration tests failed: ${e.getMessage()}"
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
        
        stage('Notify') {
            steps {
                echo 'Sending notifications...'
                script {
                    def deploymentUrl = "http://localhost:8081/sample-app/hello"
                    def message = """
                    Pipeline Build ${BUILD_NUMBER} completed successfully!
                    
                    Application deployed to: ${deploymentUrl}
                    Build Time: ${new Date()}
                    
                    Jenkins: http://localhost:8080/job/${JOB_NAME}/${BUILD_NUMBER}/
                    SonarQube: http://localhost:9000/dashboard?id=sample-app
                    """
                    
                    echo message
                }
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline execution completed.'
            cleanWs()
        }
        success {
            echo 'Pipeline executed successfully!'
        }
        failure {
            echo 'Pipeline execution failed!'
        }
        unstable {
            echo 'Pipeline execution was unstable!'
        }
    }
}
    </script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

# Create the job
echo "Creating Maven Pipeline job..."
curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
    "$JENKINS_URL/createItem?name=Sample-Maven-Pipeline" \
    -H "Content-Type: application/xml" \
    --data-binary @/tmp/maven-pipeline-job.xml

# Create a simple freestyle job
echo "Creating Simple Freestyle Job..."
cat > /tmp/freestyle-job.xml <<'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <actions/>
  <description>Simple freestyle job for testing Jenkins setup</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.scm.NullSCM"/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers/>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>#!/bin/bash
echo "=== Jenkins Test Job ==="
echo "Job Name: $JOB_NAME"
echo "Build Number: $BUILD_NUMBER"
echo "Jenkins URL: $JENKINS_URL"
echo "Workspace: $WORKSPACE"
echo "Date: $(date)"

echo ""
echo "=== System Information ==="
uname -a
whoami
pwd
ls -la

echo ""
echo "=== Docker Information ==="
docker --version
docker ps --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "=== Testing Service Connectivity ==="
echo "Testing Elasticsearch..."
curl -s http://localhost:9200/_cluster/health | head -1 || echo "Elasticsearch not accessible"

echo "Testing SonarQube..."
curl -s -I http://localhost:9000 | head -1 || echo "SonarQube not accessible"

echo "Testing Tomcat..."
curl -s -I http://localhost:8081 | head -1 || echo "Tomcat not accessible"

echo "Testing Kibana..."
curl -s -I http://localhost:5601 | head -1 || echo "Kibana not accessible"

echo ""
echo "=== Job Completed Successfully ==="
      </command>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
EOF

curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
    "$JENKINS_URL/createItem?name=System-Test-Job" \
    -H "Content-Type: application/xml" \
    --data-binary @/tmp/freestyle-job.xml

# Create Docker pipeline job
echo "Creating Docker Pipeline job..."
cat > /tmp/docker-pipeline-job.xml <<'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <actions/>
  <description>Docker-based CI/CD Pipeline</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps@2.80">
    <script>
pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = 'sample-web-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Creating sample Docker application...'
                script {
                    writeFile file: 'Dockerfile', text: '''
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
                    '''
                    
                    writeFile file: 'index.html', text: '''
&lt;!DOCTYPE html&gt;
&lt;html&gt;
&lt;head&gt;
    &lt;title&gt;DevOps CI/CD Pipeline&lt;/title&gt;
    &lt;style&gt;
        body { font-family: Arial, sans-serif; margin: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .container { max-width: 800px; margin: 0 auto; text-align: center; }
        h1 { font-size: 3em; margin-bottom: 20px; }
        .info { background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px; margin: 20px 0; }
    &lt;/style&gt;
&lt;/head&gt;
&lt;body&gt;
    &lt;div class="container"&gt;
        &lt;h1&gt;🚀 DevOps CI/CD Pipeline&lt;/h1&gt;
        &lt;div class="info"&gt;
            &lt;h2&gt;Docker Application Deployed Successfully!&lt;/h2&gt;
            &lt;p&gt;&lt;strong&gt;Build Number:&lt;/strong&gt; ${BUILD_NUMBER}&lt;/p&gt;
            &lt;p&gt;&lt;strong&gt;Deployment Time:&lt;/strong&gt; ${new Date()}&lt;/p&gt;
            &lt;p&gt;&lt;strong&gt;Pipeline:&lt;/strong&gt; Docker-based CI/CD&lt;/p&gt;
        &lt;/div&gt;
        &lt;div class="info"&gt;
            &lt;h3&gt;Services&lt;/h3&gt;
            &lt;p&gt;✅ Jenkins Pipeline&lt;/p&gt;
            &lt;p&gt;✅ Docker Build&lt;/p&gt;
            &lt;p&gt;✅ Automated Deployment&lt;/p&gt;
            &lt;p&gt;✅ Integration Testing&lt;/p&gt;
        &lt;/div&gt;
    &lt;/div&gt;
&lt;/body&gt;
&lt;/html&gt;
                    '''
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo 'Building Docker image...'
                script {
                    sh "docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} ."
                    sh "docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest"
                }
            }
        }
        
        stage('Test Docker Image') {
            steps {
                echo 'Testing Docker image...'
                script {
                    sh """
                        # Run container for testing
                        docker run -d --name test-container-${BUILD_NUMBER} -p 8090:80 ${DOCKER_IMAGE}:${DOCKER_TAG}
                        
                        # Wait for container to start
                        sleep 5
                        
                        # Test the application
                        curl -f http://localhost:8090/ || (echo "Test failed" && exit 1)
                        
                        # Cleanup test container
                        docker stop test-container-${BUILD_NUMBER}
                        docker rm test-container-${BUILD_NUMBER}
                    """
                }
            }
        }
        
        stage('Deploy') {
            steps {
                echo 'Deploying Docker container...'
                script {
                    sh """
                        # Stop and remove existing container if it exists
                        docker stop sample-web-app || true
                        docker rm sample-web-app || true
                        
                        # Run new container
                        docker run -d --name sample-web-app -p 8090:80 ${DOCKER_IMAGE}:${DOCKER_TAG}
                        
                        # Verify deployment
                        sleep 5
                        curl -f http://localhost:8090/ || echo "Deployment verification failed"
                    """
                }
            }
        }
        
        stage('Integration Test') {
            steps {
                echo 'Running integration tests...'
                script {
                    sh '''
                        # Test deployed application
                        response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8090/)
                        if [ "$response" = "200" ]; then
                            echo "Integration test passed"
                        else
                            echo "Integration test failed: HTTP $response"
                            exit 1
                        fi
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo 'Cleaning up...'
            sh 'docker system prune -f'
        }
        success {
            echo 'Docker pipeline completed successfully!'
            echo 'Application available at: http://localhost:8090'
        }
        failure {
            echo 'Docker pipeline failed!'
        }
    }
}
    </script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
    "$JENKINS_URL/createItem?name=Docker-Pipeline" \
    -H "Content-Type: application/xml" \
    --data-binary @/tmp/docker-pipeline-job.xml

# List created jobs
echo "=== Created Jenkins Jobs ==="
curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_URL/api/json?tree=jobs[name]" | jq -r '.jobs[].name'

# Trigger a test build
echo "Triggering test build for System-Test-Job..."
curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_URL/job/System-Test-Job/build"

echo "=== Jenkins Job Creation Complete ==="
echo "Access Jenkins at: $JENKINS_URL"
echo "Available jobs:"
echo "1. Sample-Maven-Pipeline - Complete Maven CI/CD with SonarQube and Tomcat"
echo "2. System-Test-Job - Simple system connectivity test"
echo "3. Docker-Pipeline - Docker-based application deployment"

# Clean up temporary files
rm -f /tmp/*-job.xml

echo "Job creation script completed successfully!"