@echo off
REM =============================================================================
REM ONE-COMMAND DEVOPS PIPELINE DEPLOYMENT
REM =============================================================================
REM Purpose: Deploy complete DevOps pipeline with a single command
REM Usage: deploy-complete.bat
REM =============================================================================

echo.
echo ===============================================================================
echo           🚀 ONE-COMMAND DEVOPS PIPELINE DEPLOYMENT 🚀
echo ===============================================================================
echo.

REM Check if running in correct directory
if not exist "main.tf" (
    echo ❌ Error: main.tf not found. Please run this script from the ELK directory.
    echo    Current directory: %CD%
    pause
    exit /b 1
)

REM Check if Pair06.pem exists
if not exist "Pair06.pem" (
    echo ❌ Error: Pair06.pem not found in current directory.
    echo    Please ensure your SSH key file is present.
    pause
    exit /b 1
)

echo ✅ Prerequisites check passed!
echo.

REM Option 1: With JIRA Integration
echo Choose your deployment option:
echo.
echo 1. Complete deployment WITH JIRA integration (recommended)
echo 2. Complete deployment WITHOUT JIRA integration
echo 3. Exit
echo.
set /p choice="Enter your choice (1, 2, or 3): "

if "%choice%"=="1" goto :jira_setup
if "%choice%"=="2" goto :no_jira
if "%choice%"=="3" goto :exit
echo Invalid choice. Please run the script again.
pause
exit /b 1

:jira_setup
echo.
echo 🎫 JIRA Integration Setup
echo ========================
echo.
echo Please provide your JIRA credentials:
echo (You can find these in your JIRA account settings)
echo.
set /p jira_url="JIRA URL (e.g., https://your-company.atlassian.net): "
set /p jira_username="JIRA Username (your email): "
set /p jira_token="JIRA API Token: "

if "%jira_url%"=="" (
    echo ❌ JIRA URL cannot be empty
    pause
    exit /b 1
)
if "%jira_username%"=="" (
    echo ❌ JIRA Username cannot be empty
    pause
    exit /b 1
)
if "%jira_token%"=="" (
    echo ❌ JIRA API Token cannot be empty
    pause
    exit /b 1
)

REM Set environment variables for JIRA
set JIRA_URL=%jira_url%
set JIRA_USERNAME=%jira_username%
set JIRA_API_TOKEN=%jira_token%

echo.
echo ✅ JIRA credentials configured!
echo.
goto :deploy

:no_jira
echo.
echo ℹ️  Proceeding without JIRA integration
echo   (You can add JIRA integration later)
echo.

:deploy
echo 🚀 Starting complete DevOps pipeline deployment...
echo ===============================================================================
echo.
echo This will:
echo   ✅ Deploy AWS infrastructure (EC2, Security Groups, etc.)
echo   ✅ Install Docker and all prerequisites
echo   ✅ Install Jenkins CI/CD server
echo   ✅ Install SonarQube code quality analysis
echo   ✅ Install ELK Stack (Elasticsearch, Logstash, Kibana)
echo   ✅ Install Tomcat application server
echo   ✅ Configure all tool integrations
if defined JIRA_URL echo   ✅ Setup JIRA integration
echo   ✅ Run comprehensive integration tests
echo   ✅ Provide complete access information
echo.
echo ⏱️  Estimated time: 15-20 minutes
echo.
set /p confirm="Do you want to proceed? (Y/N): "
if /i not "%confirm%"=="Y" if /i not "%confirm%"=="YES" (
    echo Deployment cancelled.
    pause
    exit /b 0
)

echo.
echo 🎯 Starting deployment...
echo ===============================================================================

REM Make the script executable (in case we're using Git Bash)
if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" -c "chmod +x deploy-complete-pipeline.sh"
    echo.
    echo 🚀 Running deployment script via Git Bash...
    echo ===============================================================================
    "C:\Program Files\Git\bin\bash.exe" deploy-complete-pipeline.sh
) else (
    echo.
    echo ❌ Git Bash not found. Please install Git for Windows or run manually:
    echo    bash deploy-complete-pipeline.sh
    pause
    exit /b 1
)

echo.
echo ===============================================================================
echo 🎉 DEPLOYMENT COMPLETED! 
echo ===============================================================================
echo.
echo Your complete DevOps pipeline is now ready!
echo.
echo Next steps:
echo   1. Access your services using the URLs displayed above
echo   2. Configure your React app repository in Jenkins
echo   3. Start your first pipeline build
echo.
echo 📚 Documentation available:
echo   - DEVOPS_PIPELINE_DOCUMENTATION.md
echo   - TOOL_INTEGRATION_GUIDE.md  
echo   - QUICK_REFERENCE.md
echo.
pause
goto :exit

:exit
echo Thank you for using the DevOps Pipeline Automation!
exit /b 0