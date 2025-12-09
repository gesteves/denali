import http from 'k6/http';
import { check, sleep } from 'k6';
import { parseHTML } from 'k6/html';
import { SharedArray } from 'k6/data';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom metrics
const requestDuration = new Trend('request_duration', true);
const requestsSuccessful = new Counter('requests_successful');
const requestsFailed = new Counter('requests_failed');
const errorRate = new Rate('error_rate');

// Configuration via environment variables
const DENALI_SECRET = __ENV.DENALI_SECRET || '';
const TARGET_HOST = __ENV.TARGET_HOST;
const SITEMAP_URL = __ENV.SITEMAP_URL || 'https://www.allencompassingtrip.com/sitemap.xml';
const MAX_URLS = parseInt(__ENV.MAX_URLS) || 0; // 0 = no limit
const SLEEP_MIN = parseFloat(__ENV.SLEEP_MIN) || 0.5;
const SLEEP_MAX = parseFloat(__ENV.SLEEP_MAX) || 2;

// Load test configuration
// Adjust these values based on your testing needs
export const options = {
  scenarios: {
    // Ramp-up load test scenario
    load_test: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: '30s', target: 20 },  // Ramp up to 20 users
        { duration: '1m', target: 40 },   // Ramp up to 40 users
        { duration: '1m', target: 60 },   // Ramp up to 60 users
        { duration: '1m', target: 80 },   // Ramp up to 80 users
        { duration: '1m', target: 100 },  // Push to 100 users
        { duration: '1m', target: 100 },  // Hold at 100 users
        { duration: '30s', target: 0 },   // Ramp down
      ],
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests should be under 2s
    error_rate: ['rate<0.1'],          // Error rate should be under 10%
  },
};

// Fetch and parse sitemap index to get all sitemap URLs
function fetchSitemapIndex(url) {
  const response = http.get(url);
  if (response.status !== 200) {
    console.error(`Failed to fetch sitemap index: ${response.status}`);
    return [];
  }

  const doc = parseHTML(response.body);
  const sitemapUrls = [];

  // Parse sitemap index to get individual sitemap URLs
  doc.find('sitemap loc').each((idx, el) => {
    sitemapUrls.push(el.textContent());
  });

  return sitemapUrls;
}

// Fetch and parse individual sitemap to get page URLs
function fetchSitemapUrls(url) {
  const response = http.get(url);
  if (response.status !== 200) {
    console.error(`Failed to fetch sitemap: ${response.status}`);
    return [];
  }

  const doc = parseHTML(response.body);
  const pageUrls = [];

  // Get all <loc> elements that are direct children of <url> (not image:loc)
  doc.find('url > loc').each((idx, el) => {
    pageUrls.push(el.textContent());
  });

  return pageUrls;
}

// Collect all URLs during setup phase
export function setup() {
  console.log('Fetching sitemap index...');
  const sitemapUrls = fetchSitemapIndex(SITEMAP_URL);
  console.log(`Found ${sitemapUrls.length} sitemaps`);

  let allUrls = [];
  for (const sitemapUrl of sitemapUrls) {
    console.log(`Fetching ${sitemapUrl}...`);
    const urls = fetchSitemapUrls(sitemapUrl);
    allUrls = allUrls.concat(urls);
  }

  console.log(`Total URLs found: ${allUrls.length}`);

  // Rewrite URLs to target host
  const rewrittenUrls = allUrls.map(url => {
    return url.replace('www.allencompassingtrip.com', TARGET_HOST);
  });

  // Optionally limit URLs for testing
  let finalUrls = rewrittenUrls;
  if (MAX_URLS > 0 && rewrittenUrls.length > MAX_URLS) {
    // Shuffle and take first MAX_URLS
    finalUrls = rewrittenUrls.sort(() => Math.random() - 0.5).slice(0, MAX_URLS);
  }

  console.log(`URLs to test: ${finalUrls.length}`);
  console.log(`Target host: ${TARGET_HOST}`);
  console.log(`Secret header configured: ${DENALI_SECRET ? 'Yes' : 'No'}`);

  return { urls: finalUrls };
}

// Main test function - runs for each VU iteration
export default function(data) {
  const urls = data.urls;

  if (urls.length === 0) {
    console.error('No URLs to test!');
    return;
  }

  // Pick a random URL from the list
  const url = urls[Math.floor(Math.random() * urls.length)];

  // Configure request headers
  const params = {
    headers: {
      'User-Agent': 'k6-load-test/1.0',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Accept-Encoding': 'gzip, deflate',
    },
    tags: { name: 'page_request' },
  };

  // Add secret header if configured
  if (DENALI_SECRET) {
    params.headers['X-Denali-Secret'] = DENALI_SECRET;
  }

  // Make the request
  const response = http.get(url, params);

  // Record custom metrics
  requestDuration.add(response.timings.duration);

  // Check response
  const success = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
    'response has content': (r) => r.body && r.body.length > 0,
  });

  if (success) {
    requestsSuccessful.add(1);
    errorRate.add(0);
  } else {
    requestsFailed.add(1);
    errorRate.add(1);
    console.log(`Request failed: ${url} - Status: ${response.status} - Duration: ${response.timings.duration}ms`);
  }

  // Random sleep between requests to simulate realistic user behavior
  sleep(SLEEP_MIN + Math.random() * (SLEEP_MAX - SLEEP_MIN));
}

// Summary handler
export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'denali-load-test-summary.json': JSON.stringify(data, null, 2),
  };
}

// Simple text summary function
function textSummary(data, options) {
  const { metrics } = data;
  let output = '\n';
  output += '='.repeat(60) + '\n';
  output += 'DENALI LOAD TEST SUMMARY\n';
  output += '='.repeat(60) + '\n\n';

  if (metrics.http_req_duration) {
    output += 'Response Times:\n';
    output += `  Avg: ${metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;
    output += `  Min: ${metrics.http_req_duration.values.min.toFixed(2)}ms\n`;
    output += `  Max: ${metrics.http_req_duration.values.max.toFixed(2)}ms\n`;
    output += `  p90: ${metrics.http_req_duration.values['p(90)'].toFixed(2)}ms\n`;
    output += `  p95: ${metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
    output += '\n';
  }

  if (metrics.http_reqs) {
    output += 'Requests:\n';
    output += `  Total: ${metrics.http_reqs.values.count}\n`;
    output += `  Rate: ${metrics.http_reqs.values.rate.toFixed(2)}/s\n`;
    output += '\n';
  }

  if (metrics.requests_successful) {
    output += `Successful: ${metrics.requests_successful.values.count}\n`;
  }
  if (metrics.requests_failed) {
    output += `Failed: ${metrics.requests_failed.values.count}\n`;
  }
  if (metrics.error_rate) {
    output += `Error Rate: ${(metrics.error_rate.values.rate * 100).toFixed(2)}%\n`;
  }

  output += '\n' + '='.repeat(60) + '\n';
  return output;
}
