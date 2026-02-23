import * as Sentry from '@sentry/node';

const dsn = process.env.SENTRY_DSN;
let initialized = false;

export function initSentry() {
  if (initialized || !dsn) return;
  Sentry.init({
    dsn,
    environment: process.env.VERCEL_ENV || 'development',
    tracesSampleRate: 0.1,
  });
  initialized = true;
}

export function captureError(err, context) {
  if (!dsn) return;
  initSentry();
  if (context) {
    Sentry.withScope(scope => {
      for (const [key, val] of Object.entries(context)) {
        scope.setExtra(key, val);
      }
      Sentry.captureException(err);
    });
  } else {
    Sentry.captureException(err);
  }
}
