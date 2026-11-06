import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One place for currency symbols, flags and formatting.
///
///   Money.format(2064.29, 'EUR')            -> "2,064.29 €"
///   Money.format(-5, 'USD')                 -> "-$5.00"
///   Money.format(10, 'USD', signed: true)   -> "+$10.00"
///   Money.format(1234.4, 'JPY')             -> "¥1,234"
///   Money.compact(1500, 'EUR')              -> "€1.5k"   (chart axes)
///
/// Unknown currency codes show the code itself instead of a wrong "$".
class Money {
  Money._();

  static const Map<String, String> _symbols = {
    'EUR': '€', 'USD': r'$', 'GBP': '£', 'JPY': '¥', 'CNY': '¥',
    'CAD': r'C$', 'AUD': r'A$', 'NZD': r'NZ$', 'HKD': r'HK$', 'SGD': r'S$',
    'CZK': 'Kč', 'HUF': 'Ft', 'PLN': 'zł', 'CHF': 'CHF', 'RUB': '₽',
    'BRL': r'R$', 'MXN': r'MX$', 'CLP': r'CL$', 'COP': r'CO$',
    'SEK': 'kr', 'NOK': 'kr', 'DKK': 'kr', 'RON': 'lei', 'BGN': 'лв',
    'UAH': '₴', 'TRY': '₺', 'INR': '₹', 'KRW': '₩', 'ZAR': 'R',
  };

  static const Map<String, String> _flags = {
    'EUR': '🇪🇺', 'USD': '🇺🇸', 'CAD': '🇨🇦', 'GBP': '🇬🇧', 'CZK': '🇨🇿',
    'HUF': '🇭🇺', 'PLN': '🇵🇱', 'CHF': '🇨🇭', 'RUB': '🇷🇺', 'JPY': '🇯🇵',
    'CNY': '🇨🇳', 'HKD': '🇭🇰', 'SGD': '🇸🇬', 'AUD': '🇦🇺', 'BRL': '🇧🇷',
    'MXN': '🇲🇽', 'CLP': '🇨🇱', 'COP': '🇨🇴', 'SEK': '🇸🇪', 'NOK': '🇳🇴',
    'DKK': '🇩🇰', 'RON': '🇷🇴', 'BGN': '🇧🇬', 'UAH': '🇺🇦', 'TRY': '🇹🇷',
    'INR': '🇮🇳', 'KRW': '🇰🇷', 'NZD': '🇳🇿', 'ZAR': '🇿🇦',
  };

  /// Currencies written "1,234.00 €" (symbol after the number).
  static const Set<String> _symbolAfter = {
    'EUR', 'CZK', 'HUF', 'PLN', 'RUB', 'SEK', 'NOK', 'DKK', 'RON', 'BGN', 'UAH',
  };

  /// Currencies normally shown without decimals.
  static const Set<String> _zeroDecimal = {'JPY', 'KRW', 'CLP', 'HUF'};

  static final Map<int, NumberFormat> _numberFormats = {};

  static String symbol(String currency) {
    final code = currency.toUpperCase();
    return _symbols[code] ?? code;
  }

  static String flag(String currency) => _flags[currency.toUpperCase()] ?? '💱';

  static int decimalsFor(String currency) =>
      _zeroDecimal.contains(currency.toUpperCase()) ? 0 : 2;

  static String _number(double value, int decimals) {
    final fmt = _numberFormats.putIfAbsent(
      decimals,
      () => NumberFormat(decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0', 'en_US'),
    );
    return fmt.format(value);
  }

  /// Full amount with symbol, e.g. "2,064.29 €".
  ///
  /// [decimals] overrides the currency default. [symbolAfter] overrides where the
  /// symbol goes. [signed] adds "+" to positive amounts. Amounts that round to
  /// zero never get a sign (no "-0.00").
  static String format(
    double amount,
    String currency, {
    int? decimals,
    bool signed = false,
    bool? symbolAfter,
    bool showSymbol = true,
  }) {
    if (!amount.isFinite) return '—';

    final code = currency.toUpperCase();
    final d = decimals ?? decimalsFor(code);
    final body = _number(amount.abs(), d);

    String core;
    if (!showSymbol) {
      core = body;
    } else {
      final sym = symbol(code);
      final after = symbolAfter ?? _symbolAfter.contains(code);
      if (after) {
        core = '$body $sym';
      } else {
        final needsSpace = RegExp(r'[A-Za-z]$').hasMatch(sym);
        core = needsSpace ? '$sym $body' : '$sym$body';
      }
    }

    final roundsToZero = double.parse(amount.abs().toStringAsFixed(d)) == 0;
    if (roundsToZero) return core;
    if (amount < 0) return '-$core';
    if (signed) return '+$core';
    return core;
  }

  /// Short form for chart axes and tight spaces: "€1.5k", "-$2M".
  static String compact(double amount, String currency) {
    if (!amount.isFinite) return '—';

    final a = amount.abs();
    String body;
    if (a >= 1e9) {
      body = '${_trim(a / 1e9)}B';
    } else if (a >= 1e6) {
      body = '${_trim(a / 1e6)}M';
    } else if (a >= 1e3) {
      body = '${_trim(a / 1e3)}k';
    } else {
      body = a.toStringAsFixed(0);
    }

    final sign = (amount < 0 && body != '0') ? '-' : '';
    return '$sign${symbol(currency)}$body';
  }

  static String _trim(double x) {
    final s = x.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  /// The user's primary currency from settings (key `primaryCurrency`).
  static Future<String> loadPrimaryCurrency({String fallback = 'EUR'}) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('primaryCurrency');
    return (value == null || value.isEmpty) ? fallback : value.toUpperCase();
  }

  /// Primary currency first, then any secondary ones (same keys your cards read).
  static Future<List<String>> loadUserCurrencies({String fallback = 'EUR'}) async {
    final prefs = await SharedPreferences.getInstance();
    final primary = prefs.getString('primaryCurrency');
    final list = <String>[
      (primary == null || primary.isEmpty) ? fallback : primary.toUpperCase(),
    ];
    for (final key in const ['secondaryCurrency1', 'secondaryCurrency2', 'secondaryCurrency3']) {
      final v = prefs.getString(key);
      if (v != null && v.isNotEmpty && !list.contains(v.toUpperCase())) {
        list.add(v.toUpperCase());
      }
    }
    return list;
  }
}
