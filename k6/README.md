# Load Testing with k6

This directory contains k6 load test scripts for performance testing the Denali application.

## Prerequisites

Install k6: https://k6.io/docs/get-started/installation/

```bash
# macOS
brew install k6

# Or download from https://k6.io/docs/get-started/installation/
```

## Scripts

| Script | Purpose |
|--------|---------|
| `denali-load-test.js` | Load test the main Rails application |

---

# Denali (Rails App) Load Testing

## Quick Start

```bash
# Basic run with required secret
DENALI_SECRET=your_secret_here k6 run denali-load-test.js

# With custom options
DENALI_SECRET=your_secret MAX_URLS=50 k6 run denali-load-test.js
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DENALI_SECRET` | (required) | Value for X-Denali-Secret header to bypass the CDN origin-protection redirect |
| `TARGET_HOST` | `denali.fly.dev` | Target host to test against |
| `SITEMAP_URL` | `https://www.allencompassingtrip.com/sitemap.xml` | Sitemap to crawl for URLs |
| `MAX_URLS` | `0` (no limit) | Limit number of URLs to test (useful for quick tests) |
| `SLEEP_MIN` | `0.5` | Minimum sleep between requests (seconds) |
| `SLEEP_MAX` | `2` | Maximum sleep between requests (seconds) |

## Modifying the Load Profile

Edit the `stages` array in `denali-load-test.js` to adjust the load pattern:

```javascript
stages: [
  { duration: '30s', target: 5 },   // Ramp up to 5 VUs over 30s
  { duration: '1m', target: 10 },   // Ramp up to 10 VUs over 1m
  { duration: '2m', target: 10 },   // Maintain 10 VUs for 2m
  { duration: '30s', target: 20 },  // Spike to 20 VUs
  { duration: '1m', target: 20 },   // Maintain 20 VUs
  { duration: '30s', target: 0 },   // Ramp down
],
```

**Key concepts:**
- `VUs` (Virtual Users): Concurrent users making requests
- `duration`: How long to spend at or ramping to the target
- `target`: Number of VUs to reach

## Understanding the Results

After the test completes, you'll see metrics including:

- **http_req_duration**: Response time statistics (avg, min, max, p90, p95)
- **http_reqs**: Total requests and requests per second
- **error_rate**: Percentage of failed requests

### What to Look For

1. **Response Time Degradation**: Watch for p95 response times climbing as VUs increase
2. **Error Rate Spikes**: Errors often indicate the server is overwhelmed
3. **Throughput Plateau**: When requests/second stops increasing with more VUs
4. **Memory/CPU Saturation**: Monitor via `fly status` or Fly.io dashboard

## Determining Optimal Settings

### Understanding the Relationship

```
Total Concurrent Requests = WEB_CONCURRENCY × RAILS_MAX_THREADS
```

For a single machine with your current settings:
- `WEB_CONCURRENCY=2` (Puma workers)
- `RAILS_MAX_THREADS=5` (threads per worker)
- Total capacity: 2 × 5 = 10 concurrent requests

The `soft_limit` in `fly.toml` tells Fly.io to start scaling when requests exceed this threshold.

### Testing Methodology

#### Step 1: Baseline Test (Current Settings)

```bash
# Run with current production settings
DENALI_SECRET=your_secret k6 run denali-load-test.js
```

Record:
- p95 response time at 10 VUs
- Error rate
- Requests per second

#### Step 2: Find the Breaking Point

Increase VUs until you see:
- p95 response time > 2 seconds
- Error rate > 5%
- Requests queuing (response times suddenly spike)

Edit the stages to go higher:

```javascript
stages: [
  { duration: '30s', target: 10 },
  { duration: '1m', target: 20 },
  { duration: '1m', target: 30 },
  { duration: '1m', target: 40 },
  { duration: '1m', target: 50 },
  { duration: '30s', target: 0 },
],
```

#### Step 3: Adjust Settings

**If requests queue before hitting capacity:**

Increase `RAILS_MAX_THREADS` (try 10):
```toml
# fly.toml
[env]
  RAILS_MAX_THREADS = '10'
```

Re-deploy and re-test.

**If memory becomes an issue:**

Reduce `WEB_CONCURRENCY` or upgrade VM size.

**If CPU saturates:**

Consider dedicated CPU (`cpu_kind = 'performance'`) or more machines.

### Setting `soft_limit`

The `soft_limit` determines when Fly.io starts routing requests to additional machines or queuing.

**Rule of thumb:**
```
soft_limit = (WEB_CONCURRENCY × RAILS_MAX_THREADS) × 0.8
```

For current settings: 2 × 5 × 0.8 = 8, rounded to 10.

**Conservative approach:**
Set `soft_limit` to roughly 80% of your total concurrent capacity. This gives headroom before requests start queuing.

**Aggressive approach:**
Set `soft_limit` equal to your total capacity if you want to maximize single-machine utilization before scaling.

### Recommended Test Sequence

1. **Single Machine Test**
   - Scale to 1 machine: `fly scale count 1`
   - Run load test, find the sustainable request rate
   - Note the p95 response time at capacity

2. **Adjust Thread Settings**
   - If p95 is low and machine isn't at 100% CPU, increase `RAILS_MAX_THREADS`
   - If memory is tight, decrease `WEB_CONCURRENCY`
   - Re-deploy and re-test

3. **Set `soft_limit`**
   - Set to ~80% of sustainable concurrent requests
   - This ensures new machines start before existing ones are overwhelmed

4. **Multi-Machine Test**
   - Scale to 2+ machines
   - Run load test to verify scaling behavior

---

# Monitoring During Tests

## Fly.io Dashboard

Watch the Fly.io dashboard during tests for:
- CPU utilization
- Memory usage
- Request count
- Machine scaling events

## Fly Logs

In a separate terminal:

```bash
fly logs -a denali
```

Look for:
- Timeout errors
- Memory warnings
- Connection errors

## Fly Status

Check machine status:

```bash
fly status -a denali
```

---

# Example Testing Session

```bash
# 1. Ensure single machine
fly scale count 1 -a denali

# 2. Quick test with limited URLs
DENALI_SECRET=your_secret MAX_URLS=20 k6 run denali-load-test.js

# 3. Full test if quick test looks good
DENALI_SECRET=your_secret k6 run denali-load-test.js

# 4. Review results and adjust fly.toml settings

# 5. Re-deploy with new settings
fly deploy

# 6. Re-test to verify improvements
```

---

# Troubleshooting

## "No URLs to test!"

- Check that the sitemap is accessible
- Verify the SITEMAP_URL is correct
- For denali, ensure the X-Denali-Secret header is correct if testing locally

## High Error Rate

- Check Fly.io logs for specific errors
- Verify the target host is correct and accessible
- Ensure machines are running: `fly status`

## Response Times Too High

- Server may be at capacity; reduce VUs
- Check database connection pool (for Rails app)
- Monitor CPU/memory on Fly.io dashboard

## Tests Complete Too Quickly

- Increase the duration in stages
- Add more VUs
- Decrease sleep times

---

# Output Files

After each test run, a JSON summary is saved:
- `denali-load-test-summary.json`

These contain detailed metrics for analysis and comparison between runs.
