#!/bin/bash
###############################################################################
# Jira Integration with DevOps Pipeline (External Jira)
# This script integrates existing Jira instance with Jenkins, SonarQube, and CI/CD pipeline
# Author: DevOps Team
# Date: October 2025
###############################################################################

set -e

echo "🎯 Starting Jira Integration Setup with External Jira..."
echo "======================================================="

# Configuration Variables - These will be set via environment or user input
JIRA_BASE_URL="${JIRA_BASE_URL:-}"
JIRA_USER="${JIRA_USER:-}"
JIRA_TOKEN="${JIRA_TOKEN:-}"
JIRA_PROJECT_KEY="${JIRA_PROJECT_KEY:-DEVOPS}"

# Function to prompt for Jira configuration
setup_jira_config() {
    echo "🔧 Setting up Jira Configuration..."
    echo "=================================="
    
    if [ -z "$JIRA_BASE_URL" ]; then
        echo "Please enter your Jira URL (e.g., https://your-company.atlassian.net):"
        read -r JIRA_BASE_URL
    fi
    
    if [ -z "$JIRA_USER" ]; then
        echo "Please enter your Jira username/email:"
        read -r JIRA_USER
    fi
    
    if [ -z "$JIRA_TOKEN" ]; then
        echo "Please enter your Jira API token:"
        echo "(Generate at: $JIRA_BASE_URL/secure/ViewProfile.jspa?selectedTab=com.atlassian.pats.pats-plugin:jira-user-personal-access-tokens)"
        read -r JIRA_TOKEN
    fi
    
    if [ -z "$JIRA_PROJECT_KEY" ]; then
        echo "Please enter your Jira project key (default: DEVOPS):"
        read -r input_project_key
        JIRA_PROJECT_KEY=${input_project_key:-DEVOPS}
    fi
    
    # Validate configuration
    if [ -z "$JIRA_BASE_URL" ] || [ -z "$JIRA_USER" ] || [ -z "$JIRA_TOKEN" ]; then
        echo "❌ Missing required Jira configuration. Please provide all values."
        exit 1
    fi
    
    echo "✅ Jira configuration set:"
    echo "   URL: $JIRA_BASE_URL"
    echo "   User: $JIRA_USER"
    echo "   Project: $JIRA_PROJECT_KEY"
}

# Function to test Jira connectivity
test_jira_connection() {
    echo "🔍 Testing Jira connectivity..."
    
    local response=$(curl -s -w "%{http_code}" -u "$JIRA_USER:$JIRA_TOKEN" \
        "$JIRA_BASE_URL/rest/api/2/serverInfo" -o /tmp/jira_test_response.json)
    
    if [ "$response" = "200" ]; then
        local jira_version=$(cat /tmp/jira_test_response.json | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        echo "✅ Successfully connected to Jira (Version: $jira_version)"
        return 0
    else
        echo "❌ Failed to connect to Jira (HTTP: $response)"
        echo "Response: $(cat /tmp/jira_test_response.json 2>/dev/null || echo 'No response')"
        return 1
    fi
}

# Setup Jira configuration
setup_jira_config

# Test Jira connection
if ! test_jira_connection; then
    echo "❌ Cannot proceed without valid Jira connection"
    exit 1
fi

# Create Jira integration directories
echo "📁 Creating Jira integration directory structure..."
sudo mkdir -p /opt/jira-integration/{scripts,templates,webhooks,config}
sudo chown -R ec2-user:ec2-user /opt/jira-integration/

echo "=== Setting up External Jira Integration ==="

# Create Jira API utility script
echo "📝 Creating Jira API utility script..."
cat > /opt/jira-integration/scripts/jira-api.sh << EOF
#!/bin/bash
# Jira API Utility Functions for External Jira

# Load configuration
source /opt/jira-integration/config/jira.env

# Function to make authenticated Jira API calls
jira_api_call() {
    local method=\$1
    local endpoint=\$2
    local data=\$3
    
    if [ -n "\$data" ]; then
        curl -s -u "\$JIRA_USER:\$JIRA_TOKEN" \\
             -X "\$method" \\
             -H "Content-Type: application/json" \\
             -d "\$data" \\
             "\$JIRA_BASE_URL/rest/api/2/\$endpoint"
    else
        curl -s -u "\$JIRA_USER:\$JIRA_TOKEN" \\
             -X "\$method" \\
             -H "Content-Type: application/json" \\
             "\$JIRA_BASE_URL/rest/api/2/\$endpoint"
    fi
}

# Create a new issue
create_jira_issue() {
    local project_key=\$1
    local summary=\$2
    local description=\$3
    local issue_type=\${4:-"Task"}
    
    local data='{
        "fields": {
            "project": {"key": "'\$project_key'"},
            "summary": "'\$summary'",
            "description": "'\$description'",
            "issuetype": {"name": "'\$issue_type'"}
        }
    }'
    
    jira_api_call "POST" "issue" "\$data"
}

# Update issue status
update_issue_status() {
    local issue_key=\$1
    local transition_id=\$2
    
    local data='{
        "transition": {"id": "'\$transition_id'"}
    }'
    
    jira_api_call "POST" "issue/\$issue_key/transitions" "\$data"
}

# Add comment to issue
add_comment() {
    local issue_key=\$1
    local comment=\$2
    
    local data='{
        "body": "'\$comment'"
    }'
    
    jira_api_call "POST" "issue/\$issue_key/comment" "\$data"
}

# Get issue details
get_issue() {
    local issue_key=\$1
    jira_api_call "GET" "issue/\$issue_key"
}

# Get available transitions for an issue
get_transitions() {
    local issue_key=\$1
    jira_api_call "GET" "issue/\$issue_key/transitions"
}

# Search for issues
search_issues() {
    local jql=\$1
    local encoded_jql=\$(echo "\$jql" | sed 's/ /%20/g')
    jira_api_call "GET" "search?jql=\$encoded_jql"
}
EOF

chmod +x /opt/jira-integration/scripts/jira-api.sh

# Create Jenkins-Jira integration script
log "🔗 Creating Jenkins-Jira integration script..."
cat > /opt/jira-integration/scripts/jenkins-jira-integration.sh << 'EOF'
#!/bin/bash
# Jenkins-Jira Integration Script

source /opt/jira-integration/scripts/jira-api.sh

# Extract Jira issue keys from commit messages
extract_jira_keys() {
    local commit_message="$1"
    echo "$commit_message" | grep -oE '[A-Z]{2,}-[0-9]+' | sort -u
}

# Update Jira issues based on Jenkins build
update_jira_from_jenkins() {
    local build_status=$1
    local job_name=$2
    local build_number=$3
    local commit_message="$4"
    local build_url="$5"
    
    local jira_keys=$(extract_jira_keys "$commit_message")
    
    if [ -n "$jira_keys" ]; then
        for key in $jira_keys; do
            echo "Updating Jira issue: $key"
            
            # Add comment with build information
            local comment="Jenkins Build Update:\\n"
            comment+="Job: $job_name\\n"
            comment+="Build: #$build_number\\n"
            comment+="Status: $build_status\\n"
            comment+="URL: $build_url\\n"
            comment+="Timestamp: $(date)"
            
            add_comment "$key" "$comment"
            
            # Update status based on build result
            case $build_status in
                "SUCCESS")
                    # Transition to "In Review" or "Done" (depends on your workflow)
                    echo "Build successful for $key"
                    ;;
                "FAILURE")
                    # Transition back to "In Progress" or "To Do"
                    echo "Build failed for $key"
                    ;;
                "UNSTABLE")
                    echo "Build unstable for $key"
                    ;;
            esac
        done
    else
        echo "No Jira issue keys found in commit message"
    fi
}

# Create Jira issue for failed builds
create_issue_for_failed_build() {
    local project_key="DEVOPS"
    local job_name=$1
    local build_number=$2
    local error_log="$3"
    
    local summary="Jenkins Build Failure: $job_name #$build_number"
    local description="Automated issue created for failed Jenkins build.\\n\\n"
    description+="Job: $job_name\\n"
    description+="Build: #$build_number\\n"
    description+="Error Log:\\n$error_log"
    
    create_jira_issue "$project_key" "$summary" "$description" "Bug"
}

# Main function to be called from Jenkins
main() {
    local action=$1
    shift
    
    case $action in
        "update")
            update_jira_from_jenkins "$@"
            ;;
        "create-failure")
            create_issue_for_failed_build "$@"
            ;;
        *)
            echo "Usage: $0 {update|create-failure} [arguments...]"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

chmod +x /opt/jira-integration/scripts/jenkins-jira-integration.sh

# Create SonarQube-Jira integration script
log "📊 Creating SonarQube-Jira integration script..."
cat > /opt/jira-integration/scripts/sonarqube-jira-integration.sh << 'EOF'
#!/bin/bash
# SonarQube-Jira Integration Script

source /opt/jira-integration/scripts/jira-api.sh

# Get SonarQube project analysis results
get_sonarqube_metrics() {
    local project_key=$1
    local sonar_url="http://localhost:9000"
    local sonar_user="admin"
    local sonar_pass="admin"
    
    curl -s -u "$sonar_user:$sonar_pass" \
        "$sonar_url/api/measures/component?component=$project_key&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density"
}

# Create Jira issues for SonarQube findings
create_issues_from_sonarqube() {
    local project_key=$1
    local jira_project="DEVOPS"
    local sonar_results=$(get_sonarqube_metrics "$project_key")
    
    # Parse results and create issues for critical findings
    echo "Processing SonarQube results for $project_key..."
    echo "$sonar_results" | jq -r '.component.measures[] | select(.metric == "bugs" and (.value | tonumber) > 0) | "Found " + .value + " bugs in project"' | while read -r finding; do
        if [ -n "$finding" ]; then
            create_jira_issue "$jira_project" "SonarQube: Code Quality Issue" "$finding" "Bug"
        fi
    done
}

# Update Jira issue with code quality metrics
update_jira_with_quality_metrics() {
    local issue_key=$1
    local project_key=$2
    local metrics=$(get_sonarqube_metrics "$project_key")
    
    local comment="SonarQube Analysis Results:\\n"
    comment+="Project: $project_key\\n"
    comment+="Analysis Time: $(date)\\n"
    comment+="Metrics: $metrics"
    
    add_comment "$issue_key" "$comment"
}

main() {
    local action=$1
    shift
    
    case $action in
        "create-issues")
            create_issues_from_sonarqube "$@"
            ;;
        "update-metrics")
            update_jira_with_quality_metrics "$@"
            ;;
        *)
            echo "Usage: $0 {create-issues|update-metrics} [arguments...]"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

chmod +x /opt/jira-integration/scripts/sonarqube-jira-integration.sh

# Create webhook handler script
log "🔗 Creating webhook handler script..."
cat > /opt/jira-integration/webhooks/webhook-handler.sh << 'EOF'
#!/bin/bash
# Webhook Handler for Jira Integration

# Handle Jenkins webhook
handle_jenkins_webhook() {
    local payload="$1"
    
    # Extract build information from Jenkins webhook payload
    local job_name=$(echo "$payload" | jq -r '.name')
    local build_number=$(echo "$payload" | jq -r '.build.number')
    local build_status=$(echo "$payload" | jq -r '.build.status')
    local build_url=$(echo "$payload" | jq -r '.build.full_url')
    
    # Get commit message (this would need to be enhanced based on your setup)
    local commit_message=$(echo "$payload" | jq -r '.build.scm.commit.message // "No commit message"')
    
    # Call Jenkins-Jira integration
    /opt/jira-integration/scripts/jenkins-jira-integration.sh update \
        "$build_status" "$job_name" "$build_number" "$commit_message" "$build_url"
}

# Handle SonarQube webhook
handle_sonarqube_webhook() {
    local payload="$1"
    
    local project_key=$(echo "$payload" | jq -r '.project.key')
    local analysis_status=$(echo "$payload" | jq -r '.qualityGate.status')
    
    if [ "$analysis_status" = "ERROR" ]; then
        /opt/jira-integration/scripts/sonarqube-jira-integration.sh create-issues "$project_key"
    fi
}

# Main webhook handler
main() {
    local webhook_type=$1
    local payload="$2"
    
    case $webhook_type in
        "jenkins")
            handle_jenkins_webhook "$payload"
            ;;
        "sonarqube")
            handle_sonarqube_webhook "$payload"
            ;;
        *)
            echo "Unknown webhook type: $webhook_type"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

chmod +x /opt/jira-integration/webhooks/webhook-handler.sh

# Create project setup script
log "🎯 Creating Jira project setup script..."
cat > /opt/jira-integration/scripts/setup-jira-project.sh << 'EOF'
#!/bin/bash
# Setup Jira Project for DevOps Integration

source /opt/jira-integration/scripts/jira-api.sh

# Create DevOps project
create_devops_project() {
    local project_data='{
        "key": "DEVOPS",
        "name": "DevOps Pipeline",
        "projectTypeKey": "software",
        "projectTemplateKey": "com.pyxis.greenhopper.jira:gh-scrum-template",
        "description": "Project for tracking DevOps pipeline activities",
        "lead": "admin"
    }'
    
    echo "Creating DevOps project in Jira..."
    jira_api_call "POST" "project" "$project_data"
}

# Setup custom fields for DevOps tracking
setup_custom_fields() {
    echo "Setting up custom fields for DevOps tracking..."
    # This would require admin permissions and custom field creation
    # Implementation depends on your Jira configuration needs
}

# Create sample issues for demonstration
create_sample_issues() {
    echo "Creating sample DevOps issues..."
    
    # Create epic for CI/CD setup
    create_jira_issue "DEVOPS" "Setup CI/CD Pipeline" "Epic for setting up complete CI/CD pipeline with Jenkins, SonarQube, and deployment automation" "Epic"
    
    # Create stories for different components
    create_jira_issue "DEVOPS" "Configure Jenkins Jobs" "Setup Jenkins jobs for React app build and deployment" "Story"
    create_jira_issue "DEVOPS" "Integrate SonarQube Analysis" "Add code quality analysis with SonarQube in pipeline" "Story"
    create_jira_issue "DEVOPS" "Setup Monitoring Dashboard" "Create monitoring dashboard with ELK stack" "Story"
}

main() {
    echo "Setting up Jira project for DevOps integration..."
    create_devops_project
    sleep 5
    setup_custom_fields
    create_sample_issues
    echo "Jira project setup completed!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

chmod +x /opt/jira-integration/scripts/setup-jira-project.sh

# Create monitoring script for external Jira integration
echo "📈 Creating Jira integration monitoring script..."
cat > /opt/jira-integration/scripts/monitor-jira-integration.sh << 'EOF'
#!/bin/bash
# Monitor External Jira Integration Health

# Load configuration
source /opt/jira-integration/config/jira.env

# Check external Jira connectivity
check_jira_health() {
    echo "=== External Jira Health Check ==="
    local response=$(curl -s -w "%{http_code}" -u "$JIRA_USER:$JIRA_TOKEN" \
        "$JIRA_BASE_URL/rest/api/2/serverInfo" -o /tmp/jira_health_check.json)
    
    if [ "$response" = "200" ]; then
        local version=$(cat /tmp/jira_health_check.json | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        echo "✅ External Jira is accessible (Version: $version)"
        echo "   URL: $JIRA_BASE_URL"
        return 0
    else
        echo "❌ External Jira is not accessible (HTTP: $response)"
        echo "   URL: $JIRA_BASE_URL"
        return 1
    fi
}

# Check project accessibility
check_project_access() {
    echo "=== Project Access Check ==="
    local response=$(curl -s -w "%{http_code}" -u "$JIRA_USER:$JIRA_TOKEN" \
        "$JIRA_BASE_URL/rest/api/2/project/$JIRA_PROJECT_KEY" -o /tmp/jira_project_check.json)
    
    if [ "$response" = "200" ]; then
        local project_name=$(cat /tmp/jira_project_check.json | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        echo "✅ Project '$JIRA_PROJECT_KEY' is accessible: $project_name"
        return 0
    else
        echo "❌ Project '$JIRA_PROJECT_KEY' is not accessible (HTTP: $response)"
        return 1
    fi
}

# Check integration scripts
check_integration_scripts() {
    echo "=== Integration Scripts Check ==="
    local scripts=(
        "/opt/jira-integration/scripts/jira-api.sh"
        "/opt/jira-integration/scripts/jenkins-jira-integration.sh"
        "/opt/jira-integration/scripts/sonarqube-jira-integration.sh"
    )
    
    local all_ok=true
    for script in "${scripts[@]}"; do
        if [ -x "$script" ]; then
            echo "✅ $script is executable"
        else
            echo "❌ $script is missing or not executable"
            all_ok=false
        fi
    done
    
    return $all_ok
}

# Test API functionality
test_api_functionality() {
    echo "=== API Functionality Test ==="
    
    # Test creating a test issue (won't actually create, just validate)
    echo "Testing issue creation API..."
    local test_data='{
        "fields": {
            "project": {"key": "'$JIRA_PROJECT_KEY'"},
            "summary": "API Test Issue - Do Not Create",
            "description": "This is a test to validate API access",
            "issuetype": {"name": "Task"}
        }
    }'
    
    # Use a dry-run approach by checking required fields instead
    local response=$(curl -s -w "%{http_code}" -u "$JIRA_USER:$JIRA_TOKEN" \
        "$JIRA_BASE_URL/rest/api/2/issue/createmeta?projectKeys=$JIRA_PROJECT_KEY" -o /tmp/jira_api_test.json)
    
    if [ "$response" = "200" ]; then
        echo "✅ Issue creation API is accessible"
    else
        echo "❌ Issue creation API is not accessible (HTTP: $response)"
    fi
}

# Generate integration status report
generate_status_report() {
    echo "=== External Jira Integration Status Report ==="
    echo "Generated: $(date)"
    echo "================================================"
    
    check_jira_health
    check_project_access
    check_integration_scripts
    test_api_functionality
    
    echo ""
    echo "=== Configuration Summary ==="
    echo "Jira URL: $JIRA_BASE_URL"
    echo "Jira User: $JIRA_USER"
    echo "Project Key: $JIRA_PROJECT_KEY"
    echo "Jenkins Integration: Enabled"
    echo "SonarQube Integration: Enabled"
}

main() {
    generate_status_report
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

chmod +x /opt/jira-integration/scripts/monitor-jira-integration.sh

echo "=== Setting up Jenkins Pipeline Integration ==="

# Update Jenkins jobs to include Jira integration
log "🔧 Updating Jenkins pipeline with Jira integration..."
cat > /opt/jira-integration/templates/Jenkinsfile-with-jira << 'EOF'
pipeline {
    agent any
    
    environment {
        JIRA_INTEGRATION_SCRIPT = '/opt/jira-integration/scripts/jenkins-jira-integration.sh'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.COMMIT_MESSAGE = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Build') {
            steps {
                sh 'npm install'
                sh 'npm run build'
            }
            post {
                always {
                    script {
                        sh """
                            ${JIRA_INTEGRATION_SCRIPT} update \
                                "${currentBuild.result ?: 'SUCCESS'}" \
                                "${env.JOB_NAME}" \
                                "${env.BUILD_NUMBER}" \
                                "${env.COMMIT_MESSAGE}" \
                                "${env.BUILD_URL}"
                        """
                    }
                }
            }
        }
        
        stage('Test') {
            steps {
                sh 'npm test'
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                script {
                    def scannerHome = tool 'SonarQubeScanner'
                    withSonarQubeEnv('SonarQube') {
                        sh "${scannerHome}/bin/sonar-scanner"
                    }
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
        
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh 'npm run deploy'
            }
        }
    }
    
    post {
        failure {
            script {
                sh """
                    ${JIRA_INTEGRATION_SCRIPT} create-failure \
                        "${env.JOB_NAME}" \
                        "${env.BUILD_NUMBER}" \
                        "${currentBuild.rawBuild.getLog(50).join('\\n')}"
                """
            }
        }
        always {
            script {
                sh """
                    ${JIRA_INTEGRATION_SCRIPT} update \
                        "${currentBuild.result}" \
                        "${env.JOB_NAME}" \
                        "${env.BUILD_NUMBER}" \
                        "${env.COMMIT_MESSAGE}" \
                        "${env.BUILD_URL}"
                """
            }
        }
    }
}
EOF

echo "=== Creating Configuration Files ==="

# Create configuration file with user's Jira details
echo "⚙️ Creating Jira integration configuration..."
cat > /opt/jira-integration/config/jira.env << EOF
# Jira Integration Configuration
JIRA_BASE_URL=$JIRA_BASE_URL
JIRA_USER=$JIRA_USER
JIRA_TOKEN=$JIRA_TOKEN
JIRA_PROJECT_KEY=$JIRA_PROJECT_KEY

# Jenkins Configuration
JENKINS_URL=http://localhost:8080
JENKINS_USER=admin

# SonarQube Configuration
SONARQUBE_URL=http://localhost:9000
SONARQUBE_USER=admin
SONARQUBE_PASS=admin
EOF

chmod 600 /opt/jira-integration/config/jira.env  # Protect sensitive credentials

# Create installation summary
log "📋 Creating installation summary..."
cat > /tmp/jira-integration-summary.txt << EOF
🎯 Jira Integration Installation Summary
=======================================
Installation Date: $(date)
Jira Version: $JIRA_VERSION
Database: PostgreSQL $POSTGRES_VERSION

📊 Services Installed:
- Jira Software: http://localhost:31274
- PostgreSQL Database: localhost:5433

🔧 Integration Scripts Created:
- Jira API Utilities: /opt/jira-integration/scripts/jira-api.sh
- Jenkins Integration: /opt/jira-integration/scripts/jenkins-jira-integration.sh
- SonarQube Integration: /opt/jira-integration/scripts/sonarqube-jira-integration.sh
- Webhook Handler: /opt/jira-integration/webhooks/webhook-handler.sh
- Project Setup: /opt/jira-integration/scripts/setup-jira-project.sh
- Monitoring: /opt/jira-integration/scripts/monitor-jira-integration.sh

📁 Directory Structure:
/opt/jira-integration/
├── scripts/          # Integration scripts
├── templates/        # Pipeline templates
├── webhooks/         # Webhook handlers
└── config.env        # Configuration file

🎯 Next Steps:
1. Access Jira at http://localhost:$JIRA_PORT
2. Complete Jira setup wizard
3. Run project setup: /opt/jira-integration/scripts/setup-jira-project.sh
4. Configure webhooks in Jenkins and SonarQube
5. Update Jenkins pipelines to use Jira integration

🔐 Default Credentials:
- Jira: admin/admin (change after first login)
- Database: jira/jira123

🔍 Health Check:
Run: /opt/jira-integration/scripts/monitor-jira-integration.sh
EOF

echo "=== Installation Completed ==="
echo "✅ External Jira integration installation completed successfully!"
echo "📊 Using existing Jira at: $JIRA_BASE_URL"
echo "📋 Installation summary: /tmp/jira-integration-summary.txt"
echo "🔍 Health check: /opt/jira-integration/scripts/monitor-jira-integration.sh"

echo ""
echo "🎯 EXTERNAL JIRA INTEGRATION SETUP COMPLETED!"
echo "=============================================="
echo "🌐 Jira URL: $JIRA_BASE_URL"
echo "👤 Jira User: $JIRA_USER"
echo "� Using API Token: ****$(echo $JIRA_TOKEN | tail -c 5)"
echo "📊 Project Key: $JIRA_PROJECT_KEY"
echo ""
echo "📋 Next Steps:"
echo "1. Test connection: /opt/jira-integration/scripts/monitor-jira-integration.sh"
echo "2. Update Jenkins pipelines to include Jira issue keys in commit messages"
echo "3. Configure webhook endpoints in your external Jira instance"
echo ""
echo "🔍 Monitor integration health:"
echo "/opt/jira-integration/scripts/monitor-jira-integration.sh"