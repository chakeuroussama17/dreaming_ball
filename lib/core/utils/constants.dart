class AppConstants {
  AppConstants._();

  static const String appName = 'Boundless';
  static const int defaultSlots = 10;
  static const int maxSlots = 20;

  static const Map<String, int> tierXpThresholds = {
    'bronze':   0,
    'silver':   500,
    'gold':     1500,
    'platinum': 3000,
    'diamond':  6000,
    'elite':    10000,
    'legend':   20000,
  };
}

