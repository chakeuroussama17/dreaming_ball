/// Agent subscription plans. Counted plans grant [games] games for [days] days;
/// unlimited plans ([games] == null) grant unlimited games for [days] days.
/// Prices are in Malaysian Ringgit (RM). The admin grants these manually after
/// off-platform payment (see grant_agent_plan in agent_subscriptions.sql).
class SubPlan {
  final String key; // stored in agent_profiles.current_plan
  final String label;
  final int priceRm;
  final int days;
  final int? games; // null = unlimited
  final String bestFor;

  const SubPlan({
    required this.key,
    required this.label,
    required this.priceRm,
    required this.days,
    required this.games,
    required this.bestFor,
  });

  bool get unlimited => games == null;

  /// e.g. "RM30 · 10 games · 30 days" or "RM50 · Unlimited · 40 days".
  String get summary =>
      'RM$priceRm · ${unlimited ? 'Unlimited' : '$games games'} · $days days';
}

/// The 7 plans agents can request, cheapest first.
const kSubPlans = <SubPlan>[
  SubPlan(key: 'WEEKLY', label: 'Weekly', priceRm: 10, days: 7, games: null, bestFor: 'Testing, 1 tournament'),
  SubPlan(key: 'BASIC', label: 'Basic', priceRm: 15, days: 30, games: 3, bestFor: '1–3 games/month'),
  SubPlan(key: 'STANDARD', label: 'Standard', priceRm: 30, days: 30, games: 10, bestFor: '5–10 games/month'),
  SubPlan(key: 'MONTHLY', label: 'Monthly', priceRm: 35, days: 30, games: null, bestFor: 'Regular agents'),
  SubPlan(key: 'PRO', label: 'Pro', priceRm: 50, days: 40, games: null, bestFor: '10+ games/month'),
  SubPlan(key: 'ELITE', label: 'Elite', priceRm: 80, days: 45, games: null, bestFor: '20+ games/month'),
  SubPlan(key: 'QUARTERLY', label: 'Quarterly', priceRm: 120, days: 90, games: null, bestFor: 'Year-long agents'),
];
