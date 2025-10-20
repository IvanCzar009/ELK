# Using Your Existing Jira Account with DevOps Pipeline

## Quick Setup Guide

The Jira integration script has been updated to work with your existing Jira account instead of installing a new instance. This is much more efficient and allows you to use your existing projects and data.

## Prerequisites

Before running the deployment, you'll need:

1. **Jira URL**: Your Jira instance URL (e.g., `https://your-company.atlassian.net`)
2. **Jira Username**: Your Jira email/username
3. **API Token**: Generate from your Jira profile

## How to Generate a Jira API Token

1. Log into your Jira instance
2. Go to your profile settings
3. Navigate to **Security** → **API tokens**
4. Click **Create API token**
5. Give it a name like "DevOps Pipeline Integration"
6. Copy the token (you won't see it again!)

## Integration Process

When you run `terraform apply`, the script will:

1. **Prompt for your Jira details**:
   - Jira URL
   - Username/email
   - API token
   - Project key (default: DEVOPS)

2. **Test the connection** to ensure everything works

3. **Set up integration scripts** for:
   - Jenkins → Jira issue updates
   - SonarQube → Jira quality issues
   - Automated webhook handling

## How It Works

### 1. Commit Message Integration
When you commit code with Jira issue keys:
```bash
git commit -m "PROJ-123: Fix authentication bug"
```

Jenkins will automatically:
- Extract the issue key (PROJ-123)
- Update the issue with build status
- Add comments with build links
- Transition issue status based on results

### 2. SonarQube Quality Integration
- Code quality issues automatically create Jira tickets
- Quality metrics added as comments
- Failed quality gates trigger issue transitions

### 3. Real-time Updates
- Webhooks provide instant communication
- Build failures create incident tickets
- Deployment success updates issue status

## Security

- API token stored securely in `/opt/jira-integration/config/jira.env`
- File permissions set to 600 (owner read/write only)
- No credentials logged or exposed

## Benefits of Using Your Existing Jira

✅ **No additional infrastructure** - uses your existing Jira  
✅ **Access to existing projects** - work with current issues  
✅ **Familiar workflows** - use your established processes  
✅ **Better security** - API tokens vs passwords  
✅ **Cost effective** - no additional Jira license needed  
✅ **Immediate productivity** - start tracking work right away  

## Example Workflow

1. Create issue in your Jira: `PROJ-456: Add user dashboard`
2. Work on feature with proper commits:
   ```bash
   git commit -m "PROJ-456: Add dashboard component"
   git commit -m "PROJ-456: Implement user data fetching"
   ```
3. Push to trigger Jenkins build
4. Jenkins automatically updates PROJ-456 with build status
5. SonarQube analysis adds quality metrics to the issue
6. Successful deployment transitions issue to "Done"

## Configuration During Deployment

When prompted during `terraform apply`, provide:

```
Jira URL: https://your-company.atlassian.net
Username: your-email@company.com
API Token: [your-generated-token]
Project Key: PROJ (or your preferred project)
```

## Post-Deployment

After deployment, you can:

1. **Test integration**: `/opt/jira-integration/scripts/monitor-jira-integration.sh`
2. **View configuration**: `/opt/jira-integration/config/jira.env`
3. **Update Jenkins pipelines** to use the integration
4. **Set up webhooks** in your Jira for real-time updates

## Troubleshooting

If you encounter issues:

1. **Check connectivity**: Ensure the EC2 instance can reach your Jira URL
2. **Verify token**: Test API token in a browser or curl command
3. **Check permissions**: Ensure your user has project access
4. **Review logs**: Check `/opt/devops/logs/jira-integration-setup.log`

This approach is much cleaner and more practical than running a separate Jira instance!