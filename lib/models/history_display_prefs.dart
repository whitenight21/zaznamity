import 'package:shared_preferences/shared_preferences.dart';

class HistoryDisplayPrefs {
  bool showDescription;
  bool showDate;
  bool showLabel;
  bool showOwner;
  bool showAmount;
  bool showPool;
  bool showCurrency; // <-- Added Currency flag
  bool showEdit;
  bool showDelete;
  bool showConfirmStatus;
  bool showAttachments;
  bool isCustomFilterEnabled;

  HistoryDisplayPrefs({
    this.showDescription = true,
    this.showDate = true,
    this.showLabel = true,
    this.showOwner = true,
    this.showAmount = true,
    this.showPool = true,
    this.showCurrency = true, // <-- Default true
    this.showEdit = true,
    this.showDelete = true,
    this.showConfirmStatus = true,
    this.showAttachments = true,
    this.isCustomFilterEnabled = false,
  });

  static Future<HistoryDisplayPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return HistoryDisplayPrefs(
      showDescription: prefs.getBool('hist_showDescription') ?? true,
      showDate: prefs.getBool('hist_showDate') ?? true,
      showLabel: prefs.getBool('hist_showLabel') ?? true,
      showOwner: prefs.getBool('hist_showOwner') ?? true,
      showAmount: prefs.getBool('hist_showAmount') ?? true,
      showPool: prefs.getBool('hist_showPool') ?? true,
      showCurrency: prefs.getBool('hist_showCurrency') ?? true, // <-- Read from SharedPreferences
      showEdit: prefs.getBool('hist_showEdit') ?? true,
      showDelete: prefs.getBool('hist_showDelete') ?? true,
      showConfirmStatus: prefs.getBool('hist_showConfirmStatus') ?? true,
      showAttachments: prefs.getBool('hist_showAttachments') ?? true,
      isCustomFilterEnabled: prefs.getBool('hist_isCustomFilterEnabled') ?? false,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hist_showDescription', showDescription);
    await prefs.setBool('hist_showDate', showDate);
    await prefs.setBool('hist_showLabel', showLabel);
    await prefs.setBool('hist_showOwner', showOwner);
    await prefs.setBool('hist_showAmount', showAmount);
    await prefs.setBool('hist_showPool', showPool);
    await prefs.setBool('hist_showCurrency', showCurrency); // <-- Save to SharedPreferences
    await prefs.setBool('hist_showEdit', showEdit);
    await prefs.setBool('hist_showDelete', showDelete);
    await prefs.setBool('hist_showConfirmStatus', showConfirmStatus);
    await prefs.setBool('hist_showAttachments', showAttachments);
    await prefs.setBool('hist_isCustomFilterEnabled', isCustomFilterEnabled);
  }
}