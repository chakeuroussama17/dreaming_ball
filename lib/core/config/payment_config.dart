/// Payment configuration.
///
/// While [billplzEnabled] is false, the app uses an instant mock so you can
/// keep testing joins without a payment account. Flip it to true once the
/// Billplz Edge Functions are deployed and their secrets are set (see
/// database/BILLPLZ_SETUP.md).
class PaymentConfig {
  static const bool billplzEnabled = false;
}
