// Secrets are injected by the deployment environment; never commit their values.
interface Env {
  APPLE_PRIVATE_KEY?: string;
  APPLE_KEY_ID?: string;
  APPLE_ISSUER_ID?: string;
  APPLE_BUNDLE_ID?: string;
  APPLE_APP_ID?: string;
  APPLE_ROOT_CERTIFICATES?: string;
}
