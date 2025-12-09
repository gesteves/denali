import http from 'k6/http';
import { check, sleep } from 'k6';
import { parseHTML } from 'k6/html';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom metrics
const requestDuration = new Trend('request_duration', true);
const requestsSuccessful = new Counter('requests_successful');
const requestsFailed = new Counter('requests_failed');
const errorRate = new Rate('error_rate');
const bytesReceived = new Counter('bytes_received');

// Configuration via environment variables
const TARGET_HOST = __ENV.TARGET_HOST;
const SITEMAP_URL = __ENV.SITEMAP_URL || 'https://www.allencompassingtrip.com/sitemap.xml';
const MAX_URLS = parseInt(__ENV.MAX_URLS) || 0; // 0 = no limit
const SLEEP_MIN = parseFloat(__ENV.SLEEP_MIN) || 0.1;
const SLEEP_MAX = parseFloat(__ENV.SLEEP_MAX) || 0.5;

// Load test configuration
// Thumbor is typically more resource-intensive per request (image processing)
// Start with lower concurrency than the main app
export const options = {
  scenarios: {
    load_test: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: '30s', target: 5 },   // Ramp up to 5 users
        { duration: '1m', target: 10 },   // Ramp up to 10 users
        { duration: '2m', target: 10 },   // Stay at 10 users
        { duration: '30s', target: 20 },  // Spike to 20 users
        { duration: '1m', target: 20 },   // Stay at 20 users
        { duration: '30s', target: 0 },   // Ramp down
      ],
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    // Image processing typically takes longer than HTML rendering
    http_req_duration: ['p(95)<5000'], // 95% of requests should be under 5s
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

  doc.find('sitemap loc').each((idx, el) => {
    sitemapUrls.push(el.textContent());
  });

  return sitemapUrls;
}

// Fetch and parse individual sitemap to get image URLs
function fetchImageUrls(url) {
  const response = http.get(url);
  if (response.status !== 200) {
    console.error(`Failed to fetch sitemap: ${response.status}`);
    return [];
  }

  const doc = parseHTML(response.body);
  const imageUrls = [];

  // The XML uses namespace image:loc, but k6's parseHTML handles it as 'image\\:loc'
  // Try multiple selector patterns
  const body = response.body;

  // Use regex to extract image:loc URLs since namespace handling can be tricky
  const regex = /<image:loc>([^<]+)<\/image:loc>/g;
  let match;
  while ((match = regex.exec(body)) !== null) {
    const imageUrl = match[1].trim();
    // Only include thumbor URLs
    if (imageUrl.includes('/thumbor/')) {
      imageUrls.push(imageUrl);
    }
  }

  return imageUrls;
}

// Collect all image URLs during setup phase
export function setup() {
  console.log('Fetching sitemap index...');
  const sitemapUrls = fetchSitemapIndex(SITEMAP_URL);
  console.log(`Found ${sitemapUrls.length} sitemaps`);

  let allImageUrls = [];
  for (const sitemapUrl of sitemapUrls) {
    console.log(`Fetching ${sitemapUrl}...`);
    const urls = fetchImageUrls(sitemapUrl);
    allImageUrls = allImageUrls.concat(urls);
  }

  console.log(`Total image URLs found: ${allImageUrls.length}`);

  // Rewrite URLs to target host
  // Original: https://www.allencompassingtrip.com/thumbor/hash=/1200x0/filters:format(jpeg)/path
  // Target:   https://denali-thumbor.fly.dev/thumbor/hash=/1200x0/filters:format(jpeg)/path
  const rewrittenUrls = allImageUrls.map(url => {
    return url.replace('www.allencompassingtrip.com', TARGET_HOST);
  });

  // Optionally limit URLs for testing
  let finalUrls = rewrittenUrls;
  if (MAX_URLS > 0 && rewrittenUrls.length > MAX_URLS) {
    // Shuffle and take first MAX_URLS
    finalUrls = rewrittenUrls.sort(() => Math.random() - 0.5).slice(0, MAX_URLS);
  }

  console.log(`Image URLs to test: ${finalUrls.length}`);
  console.log(`Target host: ${TARGET_HOST}`);

  return { urls: finalUrls };
}

// Main test function
export default function(data) {
  const urls = data.urls;

  if (urls.length === 0) {
    console.error('No image URLs to test!');
    return;
  }

  // Pick a random URL from the list
  const url = urls[Math.floor(Math.random() * urls.length)];

  // Configure request headers
  const params = {
    headers: {
      'User-Agent': 'k6-load-test/1.0',
      'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Accept-Encoding': 'gzip, deflate',
    },
    tags: { name: 'image_request' },
    responseType: 'binary', // Important for image responses
  };

  // Make the request
  const response = http.get(url, params);

  // Record custom metrics
  requestDuration.add(response.timings.duration);
  // For binary responses, body is ArrayBuffer - use byteLength
  const bodySize = response.body ? (response.body.byteLength || response.body.length || 0) : 0;
  if (bodySize > 0) {
    bytesReceived.add(bodySize);
  }

  // Check response
  const success = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 5000ms': (r) => r.timings.duration < 5000,
    'response has content': (r) => {
      const size = r.body ? (r.body.byteLength || r.body.length || 0) : 0;
      return size > 0;
    },
    'content type is image': (r) => {
      // Headers may have different casing, check common variations
      const contentType = r.headers['Content-Type'] || r.headers['content-type'] || '';
      return contentType.includes('image/');
    },
  });

  if (success) {
    requestsSuccessful.add(1);
    errorRate.add(0);
  } else {
    requestsFailed.add(1);
    errorRate.add(1);
    console.log(`Request failed: ${url} - Status: ${response.status} - Duration: ${response.timings.duration}ms`);
  }

  // Shorter sleep for image requests (simulating browser parallel image loading)
  sleep(SLEEP_MIN + Math.random() * (SLEEP_MAX - SLEEP_MIN));
}

// Summary handler
export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'denali-thumbor-load-test-summary.json': JSON.stringify(data, null, 2),
  };
}

// Simple text summary function
function textSummary(data, options) {
  const { metrics } = data;
  let output = '\n';
  output += '='.repeat(60) + '\n';
  output += 'DENALI-THUMBOR LOAD TEST SUMMARY\n';
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

  if (metrics.bytes_received) {
    const mb = metrics.bytes_received.values.count / (1024 * 1024);
    output += `Data Transferred: ${mb.toFixed(2)} MB\n`;
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
