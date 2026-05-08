import http from 'k6/http';
import { check, sleep } from 'k6';
import exec from 'k6/execution';

const targetUrl = (__ENV.TARGET_URL || '').replace(/\/$/, '');
const users = (__ENV.USER_COUNT ? Number(__ENV.USER_COUNT) : 10);
const amountBase = (__ENV.AMOUNT_BASE ? Number(__ENV.AMOUNT_BASE) : 1000);

if (!targetUrl) {
  throw new Error('TARGET_URL is required. Example: TARGET_URL=http://alb... k6 run k6/event-pipeline-load.js');
}

export const options = {
  scenarios: {
    load: {
      executor: 'ramping-arrival-rate',
      startRate: Number(__ENV.START_RATE || 10),
      timeUnit: '1s',
      preAllocatedVUs: Number(__ENV.PREALLOCATED_VUS || 100),
      maxVUs: Number(__ENV.MAX_VUS || 1000),
      stages: [
        { target: Number(__ENV.STAGE1_RATE || 100), duration: __ENV.STAGE1_DURATION || '2m' },
        { target: Number(__ENV.STAGE2_RATE || 300), duration: __ENV.STAGE2_DURATION || '2m' },
        { target: Number(__ENV.STAGE3_RATE || 500), duration: __ENV.STAGE3_DURATION || '2m' },
        { target: Number(__ENV.STAGE4_RATE || 0), duration: __ENV.STAGE4_DURATION || '1m' },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
  },
  summaryTrendStats: ['min', 'avg', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

export default function () {
  const i = exec.scenario.iterationInTest;
  const userId = `u-${(i % users) + 1}`;
  const payload = JSON.stringify({
    user_id: userId,
    event_type: 'order.created',
    payload: {
      amount: amountBase + (i % 1000),
      source: 'k6-w4',
      sequence: i,
    },
  });

  const res = http.post(`${targetUrl}/v1/events`, payload, {
    headers: { 'Content-Type': 'application/json' },
    tags: { endpoint: 'ingest' },
  });

  check(res, {
    'accepted': (r) => r.status === 202,
  });

  sleep(Number(__ENV.SLEEP_SECONDS || 0));
}
