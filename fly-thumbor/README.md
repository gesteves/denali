# Thumbor on Fly.io

Deploy [Thumbor](https://thumbor.readthedocs.io/) image processing service to Fly.io with AWS S3 integration.

## Architecture

- **nginx** → reverse proxy on port 8888, handles `/thumbor/` prefix
- **Thumbor** → image processing on port 8000
- **supervisord** → process manager for nginx, Thumbor, and monit
- **monit** → disk usage monitoring, triggers cleanup when disk exceeds 80%

## Prerequisites

1. [Fly.io account](https://fly.io/app/sign-up)
2. [flyctl CLI installed](https://fly.io/docs/hands-on/install-flyctl/)
3. AWS S3 bucket(s) for image loading and result caching
4. AWS credentials with S3 access

## Quick Start

### 1. Install flyctl
```bash
curl -L https://fly.io/install.sh | sh
```

### 2. Login to Fly.io
```bash
fly auth login
```

### 3. Create the app
```bash
fly launch --no-deploy
```

### 4. Set secrets

```bash
# Thumbor security key (generate with: openssl rand -base64 32)
fly secrets set THUMBOR_SECURITY_KEY="your-security-key-here"

# AWS credentials
fly secrets set \
  AWS_ACCESS_KEY_ID="your-aws-access-key" \
  AWS_SECRET_ACCESS_KEY="your-aws-secret-key"

# Allowed S3 buckets for loading images (comma-separated)
fly secrets set AWS_ALLOWED_BUCKETS="bucket1.example.com,bucket2.example.com"

# S3 bucket for caching processed images
fly secrets set AWS_RESULT_STORAGE_BUCKET="your-cache-bucket"
```

### 5. Deploy
```bash
fly deploy
```

## Usage

Images are served via the `/thumbor/` path prefix:

```
https://your-app.fly.dev/thumbor/<signature>/<options>/<image-url>
```

### Health Check
```bash
curl https://your-app.fly.dev/healthcheck
```

## Configuration

### Environment Variables

Set via `fly secrets set`:

| Variable | Required | Description |
|----------|----------|-------------|
| `THUMBOR_SECURITY_KEY` | Yes | Secret key for URL signing |
| `AWS_ACCESS_KEY_ID` | Yes | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Yes | AWS secret key |
| `AWS_ALLOWED_BUCKETS` | Yes | Comma-separated list of allowed S3 buckets |
| `AWS_RESULT_STORAGE_BUCKET` | Yes | S3 bucket for cached results |
| `AWS_REGION` | No | AWS region (default: `us-east-1`, set in fly.toml) |

### fly.toml Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `info` | Log level (debug, info, warning, error) |
| `PORT` | `8888` | Internal port (don't change) |

### Managing Secrets

```bash
# List secret names (values are hidden)
fly secrets list

# Update a secret
fly secrets set THUMBOR_SECURITY_KEY="new-value"

# Remove a secret
fly secrets unset SECRET_NAME
```

## Scaling

### Vertical Scaling (more power per machine)

```bash
# Increase memory (recommended for image processing)
fly scale memory 2048

# Use dedicated CPUs for better performance
fly scale vm performance-2x
```

Or update `fly.toml`:

```toml
[[vm]]
  cpu_kind = 'performance'
  cpus = 2
  memory_mb = 2048
```

### Horizontal Scaling (more machines)

```bash
# Run multiple machines
fly scale count 3

# Add machines in other regions
fly scale count 2 --region lhr
fly scale count 2 --region syd
```

### Auto-scaling with Concurrency

Add to `fly.toml` for automatic scaling under load:

```toml
[http_service]
  min_machines_running = 1  # Avoid cold starts

  [http_service.concurrency]
    type = 'requests'
    soft_limit = 15   # Spawn new machine when exceeded
    hard_limit = 25   # Max concurrent requests per machine
```

### Check Current Scale

```bash
fly scale show
```

## Useful Commands

```bash
# App status
fly status

# View logs
fly logs

# Follow logs in real-time
fly logs -f

# SSH into container
fly ssh console

# Open in browser
fly open

# Restart app
fly apps restart

# View deployments
fly releases

# Rename app
fly apps rename old-name new-name
```

## Troubleshooting

### Check if app is running
```bash
fly status
fly logs
```

### Test health check
```bash
curl https://your-app.fly.dev/healthcheck
```

### View configuration inside container
```bash
fly ssh console
cat /etc/thumbor/thumbor.conf
cat /etc/nginx/nginx.conf
```

### Common Issues

**"Module not found" errors:**
```bash
fly deploy --no-cache
```

**AWS credentials not working:**
- Verify secrets: `fly secrets list`
- Check IAM permissions for S3 bucket access

**Images not loading:**
- Ensure bucket is in `AWS_ALLOWED_BUCKETS`
- Check S3 bucket permissions
- Review logs: `fly logs`

**Cold starts / slow first request:**
- Set `min_machines_running = 1` in `fly.toml`
- Increase VM resources for faster startup

## Files

| File | Purpose |
|------|---------|
| `fly.toml` | Fly.io app configuration |
| `Dockerfile` | Container build instructions |
| `thumbor.conf` | Thumbor settings |
| `nginx.conf` | nginx reverse proxy config |
| `supervisord.conf` | Process manager config |
| `monitrc` | Disk monitoring config |
| `cleanup.sh` | Cache cleanup script |

## Resources

- [Fly.io Documentation](https://fly.io/docs/)
- [Thumbor Documentation](https://thumbor.readthedocs.io/)
- [tc-aws (Thumbor AWS plugin)](https://github.com/thumbor-community/aws)
