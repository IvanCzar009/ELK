# Tool Integration Architecture 🔗

## Overview

This document provides detailed technical information about how each tool in the DevOps pipeline integrates with others, including data flow, API interactions, and configuration dependencies.

---

## Integration Matrix

| Source Tool | Target Tool | Integration Type | Data Flow | Configuration |
|-------------|-------------|------------------|-----------|---------------|
| GitHub | Jenkins | Webhook | Push events → Build triggers | GitHub webhook URL |
| Jenkins | SonarQube | API/Plugin | Code analysis requests | SonarQube server config |
| Jenkins | Tomcat | Deployment | WAR file deployment | Manager credentials |
| Jenkins | JIRA | API/Webhook | Issue updates | JIRA API token |
| All Services | ELK Stack | Log forwarding | Application logs | Logstash config |
| SonarQube | PostgreSQL | Database | Quality data storage | JDBC connection |
| Jenkins | GitHub | API | Status updates | GitHub token |

---

## Detailed Integration Mechanisms

### 1. GitHub ↔ Jenkins Integration

#### Webhook Configuration
```json
{
  "webhook_url": "http://<jenkins-server>:8080/github-webhook/",
  "events": ["push", "pull_request"],
  "content_type": "application/json",
  "secret": "<webhook-secret>"
}
```

#### Jenkins Configuration
```groovy
// Jenkinsfile pipeline trigger
pipeline {
    agent any
    triggers {
        githubPush()
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scmGit(
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        credentialsId: 'github-credentials',
                        url: 'https://github.com/user/repo.git'
                    ]]
                )
            }
        }
    }
}
```

#### Status Reporting Back to GitHub
```groovy
// In Jenkinsfile
post {
    always {
        script {
            def status = currentBuild.result ?: 'SUCCESS'
            githubNotify(
                account: 'username',
                context: 'Jenkins CI',
                repo: 'repository',
                sha: env.GIT_COMMIT,
                status: status.toLowerCase(),
                targetUrl: env.BUILD_URL
            )
        }
    }
}
```

### 2. Jenkins ↔ SonarQube Integration

#### SonarQube Server Configuration in Jenkins
```bash
# Jenkins Global Tool Configuration
SONAR_SCANNER_HOME=/opt/sonar-scanner
SONAR_HOST_URL=http://localhost:9000
SONAR_AUTH_TOKEN=<generated-token>
```

#### Pipeline Integration
```groovy
stage('SonarQube Analysis') {
    environment {
        scannerHome = tool 'SonarQubeScanner'
    }
    steps {
        withSonarQubeEnv('SonarQube') {
            sh """
                ${scannerHome}/bin/sonar-scanner \\
                -Dsonar.projectKey=react-app \\
                -Dsonar.sources=src \\
                -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info \\
                -Dsonar.testExecutionReportPaths=test-report.xml
            """
        }
    }
}

stage('Quality Gate') {
    steps {
        timeout(time: 1, unit: 'HOURS') {
            waitForQualityGate abortPipeline: true
        }
    }
}
```

#### SonarQube Webhook to Jenkins
```json
{
  "webhook_url": "http://<jenkins-server>:8080/sonarqube-webhook/",
  "payload": {
    "serverUrl": "http://localhost:9000",
    "taskId": "task-id",
    "status": "SUCCESS",
    "analysedAt": "2025-10-20T08:00:00Z",
    "project": {
      "key": "react-app",
      "name": "React Application"
    },
    "qualityGate": {
      "status": "OK",
      "conditions": []
    }
  }
}
```

### 3. Jenkins ↔ Tomcat Integration

#### Tomcat Manager Configuration
```xml
<!-- tomcat-users.xml -->
<tomcat-users>
    <role rolename="manager-script"/>
    <user username="deployer" password="<secure-password>" roles="manager-script"/>
</tomcat-users>
```

#### Jenkins Deployment Script
```groovy
stage('Deploy to Tomcat') {
    steps {
        script {
            def tomcatUrl = 'http://localhost:8081'
            def managerUrl = "${tomcatUrl}/manager/text"
            def appName = 'react-app'
            def warFile = "target/${appName}.war"
            
            // Undeploy existing application
            sh """
                curl -u deployer:<password> \\
                "${managerUrl}/undeploy?path=/${appName}" || true
            """
            
            // Deploy new application
            sh """
                curl -u deployer:<password> \\
                -T ${warFile} \\
                "${managerUrl}/deploy?path=/${appName}&update=true"
            """
            
            // Verify deployment
            def response = sh(
                script: "curl -s -o /dev/null -w '%{http_code}' ${tomcatUrl}/${appName}",
                returnStdout: true
            ).trim()
            
            if (response != '200') {
                error("Deployment verification failed. HTTP status: ${response}")
            }
        }
    }
}
```

### 4. Jenkins ↔ JIRA Integration

#### JIRA Configuration
```bash
# Environment variables
JIRA_URL=https://your-domain.atlassian.net
JIRA_USERNAME=jenkins-user@company.com
JIRA_API_TOKEN=<api-token>
JIRA_PROJECT_KEY=DEV
```

#### Issue Creation on Build Failure
```groovy
post {
    failure {
        script {
            def issueData = [
                fields: [
                    project: [key: 'DEV'],
                    summary: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    description: """
                        Build failed for job: ${env.JOB_NAME}
                        Build number: ${env.BUILD_NUMBER}
                        Branch: ${env.BRANCH_NAME}
                        Commit: ${env.GIT_COMMIT}
                        Build URL: ${env.BUILD_URL}
                        
                        Please investigate and fix the issues.
                    """,
                    issuetype: [name: 'Bug'],
                    priority: [name: 'High'],
                    assignee: [name: 'developer-team']
                ]
            ]
            
            def response = httpRequest(
                url: "${env.JIRA_URL}/rest/api/3/issue",
                httpMode: 'POST',
                authentication: 'jira-credentials',
                contentType: 'APPLICATION_JSON',
                requestBody: groovy.json.JsonOutput.toJson(issueData)
            )
            
            def issue = readJSON text: response.content
            echo "Created JIRA issue: ${issue.key}"
        }
    }
}
```

#### Issue Update on Build Success
```groovy
post {
    success {
        script {
            // Extract JIRA issue keys from commit messages
            def commitMessage = sh(
                script: "git log -1 --pretty=%B",
                returnStdout: true
            ).trim()
            
            def issuePattern = /([A-Z]+-\\d+)/
            def matcher = commitMessage =~ issuePattern
            
            matcher.each { match ->
                def issueKey = match[1]
                
                // Add comment to JIRA issue
                def commentData = [
                    body: [
                        type: 'doc',
                        version: 1,
                        content: [[
                            type: 'paragraph',
                            content: [[
                                type: 'text',
                                text: "Build completed successfully: ${env.BUILD_URL}"
                            ]]
                        ]]
                    ]
                ]
                
                httpRequest(
                    url: "${env.JIRA_URL}/rest/api/3/issue/${issueKey}/comment",
                    httpMode: 'POST',
                    authentication: 'jira-credentials',
                    contentType: 'APPLICATION_JSON',
                    requestBody: groovy.json.JsonOutput.toJson(commentData)
                )
            }
        }
    }
}
```

### 5. ELK Stack Log Integration

#### Logstash Configuration
```ruby
# /etc/logstash/conf.d/pipeline.conf
input {
  # Jenkins logs
  file {
    path => "/var/log/jenkins/*.log"
    start_position => "beginning"
    tags => ["jenkins"]
  }
  
  # SonarQube logs
  file {
    path => "/opt/sonarqube/logs/*.log"
    start_position => "beginning"
    tags => ["sonarqube"]
  }
  
  # Tomcat logs
  file {
    path => "/usr/local/tomcat/logs/*.log"
    start_position => "beginning"
    tags => ["tomcat"]
  }
  
  # Application logs from syslog
  syslog {
    port => 5000
    tags => ["application"]
  }
}

filter {
  if "jenkins" in [tags] {
    grok {
      match => { 
        "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:message}" 
      }
    }
  }
  
  if "sonarqube" in [tags] {
    grok {
      match => { 
        "message" => "%{TIMESTAMP_ISO8601:timestamp} %{WORD:level} %{GREEDYDATA:message}" 
      }
    }
  }
  
  if "tomcat" in [tags] {
    grok {
      match => { 
        "message" => "%{TOMCAT_DATESTAMP:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:message}" 
      }
    }
  }
  
  # Add common fields
  mutate {
    add_field => { "environment" => "development" }
    add_field => { "service" => "%{tags}" }
  }
  
  # Parse timestamp
  date {
    match => [ "timestamp", "ISO8601" ]
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "devops-logs-%{+YYYY.MM.dd}"
  }
  
  # Also output to stdout for debugging
  stdout { codec => rubydebug }
}
```

#### Jenkins Log Forwarding
```groovy
// In Jenkins pipeline
pipeline {
    agent any
    
    options {
        // Send logs to syslog
        ansiColor('xterm')
        timestamps()
    }
    
    stages {
        stage('Setup Logging') {
            steps {
                script {
                    // Configure log forwarding to ELK
                    sh '''
                        # Setup rsyslog forwarding to Logstash
                        echo "*.* @@localhost:5000" | sudo tee -a /etc/rsyslog.conf
                        sudo systemctl restart rsyslog
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                // Send pipeline results to ELK
                def logData = [
                    timestamp: new Date().format("yyyy-MM-dd'T'HH:mm:ss.SSSZ"),
                    job_name: env.JOB_NAME,
                    build_number: env.BUILD_NUMBER,
                    build_status: currentBuild.result ?: 'SUCCESS',
                    duration: currentBuild.duration,
                    git_commit: env.GIT_COMMIT,
                    git_branch: env.BRANCH_NAME
                ]
                
                writeJSON file: 'build-log.json', json: logData
                
                sh '''
                    # Send to Logstash via TCP
                    cat build-log.json | nc localhost 5000
                '''
            }
        }
    }
}
```

#### Kibana Dashboard Configuration
```json
{
  "dashboard": {
    "title": "DevOps Pipeline Dashboard",
    "panels": [
      {
        "title": "Build Success Rate",
        "type": "metric",
        "query": {
          "bool": {
            "filter": [
              {"term": {"service": "jenkins"}},
              {"range": {"@timestamp": {"gte": "now-24h"}}}
            ]
          }
        },
        "aggregations": {
          "success_rate": {
            "terms": {"field": "build_status"}
          }
        }
      },
      {
        "title": "Code Quality Trends",
        "type": "line",
        "query": {
          "bool": {
            "filter": [
              {"term": {"service": "sonarqube"}},
              {"exists": {"field": "quality_gate_status"}}
            ]
          }
        }
      },
      {
        "title": "Deployment Frequency",
        "type": "histogram",
        "query": {
          "bool": {
            "filter": [
              {"term": {"service": "tomcat"}},
              {"term": {"event_type": "deployment"}}
            ]
          }
        }
      }
    ]
  }
}
```

### 6. Database Integrations

#### SonarQube PostgreSQL Integration
```yaml
# docker-compose.yml snippet
services:
  sonarqube-db:
    image: postgres:13
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - postgresql-data:/var/lib/postgresql/data
    networks:
      - sonarqube-network

  sonarqube:
    image: sonarqube:community
    depends_on:
      - sonarqube-db
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://sonarqube-db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    networks:
      - sonarqube-network
```

#### Database Backup Integration
```bash
#!/bin/bash
# backup-databases.sh

# PostgreSQL backup for SonarQube
docker exec sonarqube-db pg_dump -U sonar sonar > "backup/sonarqube-$(date +%Y%m%d).sql"

# Jenkins configuration backup
docker exec jenkins tar -czf - /var/jenkins_home/config.xml /var/jenkins_home/jobs > "backup/jenkins-config-$(date +%Y%m%d).tar.gz"

# Upload to S3 or other storage
aws s3 cp backup/ s3://devops-backups/$(date +%Y/%m/%d)/ --recursive
```

---

## API Endpoints and Webhooks

### Jenkins API Endpoints
```bash
# Trigger build
POST /job/{job-name}/build

# Get build status
GET /job/{job-name}/{build-number}/api/json

# Get job configuration
GET /job/{job-name}/config.xml

# Create/update job
POST /createItem?name={job-name}
POST /job/{job-name}/config.xml
```

### SonarQube API Endpoints
```bash
# Get project analysis
GET /api/measures/component?component={project-key}&metricKeys=bugs,vulnerabilities,code_smells

# Get quality gate status
GET /api/qualitygates/project_status?projectKey={project-key}

# Create project
POST /api/projects/create
```

### JIRA API Endpoints
```bash
# Create issue
POST /rest/api/3/issue

# Update issue
PUT /rest/api/3/issue/{issue-key}

# Add comment
POST /rest/api/3/issue/{issue-key}/comment

# Get project info
GET /rest/api/3/project/{project-key}
```

---

## Security Considerations

### Authentication & Authorization
1. **Jenkins**: Role-based access control (RBAC)
2. **SonarQube**: Token-based authentication
3. **JIRA**: API token authentication
4. **ELK Stack**: Basic authentication for Kibana

### Network Security
```bash
# Docker network isolation
docker network create --driver bridge jenkins-network
docker network create --driver bridge sonarqube-network
docker network create --driver bridge elk-network

# Inter-service communication
docker network connect jenkins-network jenkins
docker network connect sonarqube-network jenkins
docker network connect elk-network jenkins
```

### Secrets Management
```groovy
// Jenkins credentials store
withCredentials([
    string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN'),
    usernamePassword(credentialsId: 'github-creds', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_TOKEN'),
    usernamePassword(credentialsId: 'jira-creds', usernameVariable: 'JIRA_USER', passwordVariable: 'JIRA_TOKEN')
]) {
    // Use credentials securely
}
```

---

## Monitoring Integration Points

### Health Checks
```bash
# Jenkins health
curl -s http://localhost:8080/login | grep -q "Jenkins" && echo "UP" || echo "DOWN"

# SonarQube health
curl -s http://localhost:9000/api/system/status | jq -r '.status'

# Elasticsearch health
curl -s http://localhost:9200/_cluster/health | jq -r '.status'

# Tomcat health
curl -s -o /dev/null -w "%{http_code}" http://localhost:8081
```

### Metrics Collection
```json
{
  "metrics": {
    "build_duration": "collect from Jenkins API",
    "code_quality_score": "collect from SonarQube API",
    "deployment_frequency": "collect from Tomcat logs",
    "error_rate": "collect from ELK aggregations",
    "system_resources": "collect from Docker stats"
  }
}
```

---

This integration documentation provides the technical foundation for understanding how all components work together in the DevOps pipeline. Each integration point is designed to be reliable, secure, and maintainable.