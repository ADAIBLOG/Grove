import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grove/models/grove_models.dart';
import 'package:grove/services/widget_bridge.dart';

class GroveModel extends ChangeNotifier {
  List<HabitTree> _habits = [];
  List<HabitTree> get habits => List.unmodifiable(_habits);

  SharedPreferences? _prefs;
  static const _idsKey = 'grove_v2_ids';

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _load();
    } catch (e) {
      debugPrint('GroveModel init error: $e');
    }
  }

  void _load() {
    if (_prefs == null) return;
    final ids = _prefs!.getStringList(_idsKey) ?? [];
    _habits = ids.map((id) {
      final json = _prefs!.getString(id);
      if (json == null) return null;
      try { return HabitTree.fromJson(json); }
      catch (e) { debugPrint('Failed to parse habit $id: $e'); return null; }
    }).whereType<HabitTree>().toList();
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_prefs == null) return;
    try {
      await _prefs!.setStringList(_idsKey, _habits.map((h) => h.id).toList());
      for (final h in _habits) { await _prefs!.setString(h.id, h.toJson()); }
      await GroveWidgetBridge.instance.renderAndUpdate(_habits);
    } catch (e) { debugPrint('Persist error: $e'); }
  }

  void addHabit({required String name, required Color color}) {
    final now = DateTime.now();
    _habits.add(HabitTree(
      id:        'habit_${now.millisecondsSinceEpoch}',
      name:      name,
      color:     color,
      startDate: now,
      lastReset: now,
    ));
    _persist();
    notifyListeners();
  }

  void recordCustomRelapse(String habitId, String reason, DateTime customDate) {
    final i = _habits.indexWhere((h) => h.id == habitId);
    if (i == -1) return;
    final target = _habits[i];
    target.relapses.removeWhere((r) =>
    r.timestamp.year  == customDate.year  &&
    r.timestamp.month == customDate.month &&
    r.timestamp.day   == customDate.day);
    target.relapses.add(RelapseEvent(timestamp: customDate, reason: reason));
    target.relapses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    target.lastReset = target.relapses.isNotEmpty
    ? target.relapses.first.timestamp
    : target.startDate;
    if (target.lastReset.isAfter(DateTime.now())) target.lastReset = DateTime.now();
    _sweepPeaks(target);
    _persist();
    notifyListeners();
  }

  void removeRelapseOnDate(String habitId, DateTime date) {
    final i = _habits.indexWhere((h) => h.id == habitId);
    if (i == -1) return;
    final target = _habits[i];
    target.relapses.removeWhere((r) =>
    r.timestamp.year  == date.year  &&
    r.timestamp.month == date.month &&
    r.timestamp.day   == date.day);
    target.relapses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    target.lastReset = target.relapses.isNotEmpty
    ? target.relapses.first.timestamp
    : target.startDate;
    if (target.lastReset.isAfter(DateTime.now())) target.lastReset = DateTime.now();
    _sweepPeaks(target);
    _persist();
    notifyListeners();
  }

  void updateStartDate(String habitId, DateTime newStart) {
    final i = _habits.indexWhere((h) => h.id == habitId);
    if (i == -1) return;
    final target = _habits[i];
    if (newStart.isAfter(target.startDate)) return;
    _habits[i] = HabitTree(
      id:          target.id,
      name:        target.name,
      color:       target.color,
      startDate:   newStart,
      lastReset:   target.lastReset,
      relapses:    target.relapses,
      geneticSeed: target.geneticSeed,
    );
    _sweepPeaks(_habits[i]);
    _persist();
    notifyListeners();
  }

  void _sweepPeaks(HabitTree target) {
    int absolutePeak    = 0;
    DateTime sweepPivot = target.startDate;
    final chronological = target.relapses.reversed.toList();
    final sweptRelapses = <RelapseEvent>[];
    for (final event in chronological) {
      final validSpan = event.timestamp.difference(sweepPivot).inDays;
      if (validSpan > absolutePeak) absolutePeak = validSpan;
      sweptRelapses.insert(0, RelapseEvent(
        timestamp: event.timestamp,
        reason:    event.reason,
        peakDays:  absolutePeak,
      ));
      sweepPivot = event.timestamp;
    }
    target.relapses..clear()..addAll(sweptRelapses);
  }

  void deleteHabit(String habitId) {
    _habits.removeWhere((h) => h.id == habitId);
    _prefs?.remove(habitId);
    _persist();
    notifyListeners();
  }

  HabitTree? habitById(String id) =>
  _habits.cast<HabitTree?>().firstWhere((h) => h?.id == id, orElse: () => null);

  String exportJson() {
    final payload = {
      'schemaVersion': 1,
      'exportedAt':    DateTime.now().toIso8601String(),
      'treeCount':     _habits.length,
      'trees':         _habits.map((h) => h.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<bool> importFromJson(String raw) async {
    try {
      if (raw.trim().isEmpty) return false;
      final decoded = jsonDecode(raw);
      final List<dynamic> entries;
      if (decoded is Map<String, dynamic> && decoded['trees'] is List) {
        entries = decoded['trees'] as List<dynamic>;
      } else if (decoded is List) {
        entries = decoded;
      } else { return false; }
      final imported = <HabitTree>[];
      for (final entry in entries) {
        if (entry is Map<String, dynamic>) imported.add(HabitTree.fromMap(entry));
      }
      if (imported.isEmpty) return false;
      _habits = imported;
      await _persist();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('JSON import failed: $e');
      return false;
    }
  }
}
