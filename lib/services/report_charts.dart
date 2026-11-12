import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/report_options.dart';

class ReportCharts {
  ReportCharts._();

  /// Usable chart width: A4 (595) - page margins (64) - card padding (20) - slack.
  static const double _w = 490;

  static final PdfColor _purple = PdfColor.fromInt(0xFF582F95);
  static final PdfColor _green = PdfColor.fromInt(0xFF10B981);
  static final PdfColor _red = PdfColor.fromInt(0xFFEF4444);
  static final PdfColor _teal = PdfColor.fromInt(0xFF14B8A6);
  static final PdfColor _slate = PdfColor.fromInt(0xFF64748B);
  static final PdfColor _grid = PdfColor.fromInt(0xFFE2E8F0);

  static final List<PdfColor> _incomeColors = [
    PdfColor.fromInt(0xFF10B981),
    PdfColor.fromInt(0xFF34D399),
    PdfColor.fromInt(0xFF6EE7B7),
    PdfColor.fromInt(0xFFA7F3D0),
  ];

  static final List<PdfColor> _palette = [
    PdfColor.fromInt(0xFFA855F7),
    PdfColor.fromInt(0xFF3B82F6),
    PdfColor.fromInt(0xFFF59E0B),
    PdfColor.fromInt(0xFFEC4899),
    PdfColor.fromInt(0xFF06B6D4),
    PdfColor.fromInt(0xFF6366F1),
    PdfColor.fromInt(0xFFF97316),
    PdfColor.fromInt(0xFF84CC16),
  ];

  static const pw.TextStyle _tick = pw.TextStyle(fontSize: 7, color: PdfColors.grey700);

  // ---------------------------------------------------------------------------
  // Shared building blocks
  // ---------------------------------------------------------------------------

  /// Title + bordered card, kept together so a title is never left alone at the
  /// bottom of a page.
  static pw.Widget section(String title, pw.Widget child) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('  $title', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  static pw.Widget noData(String message) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 12),
      child: pw.Text(message, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
    );
  }

  static PdfColor _lighten(PdfColor c, double t) {
    return PdfColor(
      c.red + (1 - c.red) * t,
      c.green + (1 - c.green) * t,
      c.blue + (1 - c.blue) * t,
    );
  }

  static double _niceStep(double raw) {
    if (raw <= 0 || raw.isNaN || raw.isInfinite) return 1;
    final exp = (math.log(raw) / math.ln10).floor();
    final base = math.pow(10, exp).toDouble();
    final f = raw / base;
    final double nf = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 2.5 ? 2.5 : (f <= 5 ? 5 : 10)));
    return nf * base;
  }

  static _Axis _niceAxis(double lo, double hi, {int ticks = 4}) {
    if (hi - lo < 1e-9) hi = lo + 1;
    final step = _niceStep((hi - lo) / ticks);
    final min = (lo / step).floorToDouble() * step;
    var max = (hi / step).ceilToDouble() * step;
    if (max <= min) max = min + step;
    return _Axis(min, max, step);
  }

  static String _trim(double x, {int digits = 1}) {
    var s = x.toStringAsFixed(digits);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  /// Short axis numbers: 1.5k, 2M, -300.
  static String compact(double v) {
    final a = v.abs();
    final sign = v < 0 ? '-' : '';
    if (a >= 1e6) return '$sign${_trim(a / 1e6)}M';
    if (a >= 1e3) return '$sign${_trim(a / 1e3)}k';
    if (a >= 10) return '$sign${a.toStringAsFixed(0)}';
    return '$sign${_trim(a)}';
  }

  static String _clip(String s, [int max = 14]) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}..';

  static List<pw.Widget> _yLabels(
    _Axis axis,
    double Function(double) yTop,
    double labelWidth,
    bool mask,
  ) {
    if (mask) return <pw.Widget>[];
    return [
      for (final t in axis.ticks)
        pw.Positioned(
          left: 0,
          top: yTop(t) - 4,
          child: pw.SizedBox(
            width: labelWidth,
            child: pw.Text(compact(t), textAlign: pw.TextAlign.right, style: _tick),
          ),
        ),
    ];
  }

  static pw.Widget _legendItem(PdfColor color, String text, {bool line = false}) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(width: line ? 12 : 7, height: line ? 2 : 7, color: color),
        pw.SizedBox(width: 4),
        pw.Text(text, style: const pw.TextStyle(fontSize: 7.5)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Balance trend (line + area chart, one point per day)
  // ---------------------------------------------------------------------------

  static pw.Widget balanceTrend({
    required List<double> series,
    required DateTime start,
    required double opening,
    required double closing,
    required String Function(double) fmt,
    required bool mask,
  }) {
    if (series.length < 2) {
      return noData('The selected period is too short to draw a balance trend.');
    }

    const double w = _w, h = 170, left = 40, right = 6, top = 8, bottom = 20;
    const double plotW = w - left - right;
    const double plotH = h - top - bottom;
    final n = series.length;

    var lo = opening, hi = opening;
    var minIdx = 0, maxIdx = 0;
    for (var i = 0; i < n; i++) {
      if (series[i] < series[minIdx]) minIdx = i;
      if (series[i] > series[maxIdx]) maxIdx = i;
      if (series[i] < lo) lo = series[i];
      if (series[i] > hi) hi = series[i];
    }
    final axis = _niceAxis(lo, hi);

    double yTop(double v) => top + plotH * (1 - (v - axis.min) / (axis.max - axis.min));
    double xOf(int i) => left + plotW * (i / (n - 1));

    void paint(PdfGraphics canvas, PdfPoint size) {
      double py(double v) => h - yTop(v);

      canvas.setLineWidth(0.4);
      canvas.setStrokeColor(_grid);
      for (final t in axis.ticks) {
        canvas.moveTo(left, py(t));
        canvas.lineTo(w - right, py(t));
        canvas.strokePath();
      }

      final baseV = axis.min > 0 ? axis.min : (axis.max < 0 ? axis.max : 0.0);

      // Area under the line
      canvas.setFillColor(_lighten(_purple, 0.85));
      canvas.moveTo(xOf(0), py(baseV));
      for (var i = 0; i < n; i++) {
        canvas.lineTo(xOf(i), py(series[i]));
      }
      canvas.lineTo(xOf(n - 1), py(baseV));
      canvas.closePath();
      canvas.fillPath();

      // Zero line
      if (axis.min < 0 && axis.max > 0) {
        canvas.setStrokeColor(PdfColors.grey600);
        canvas.setLineWidth(0.8);
        canvas.moveTo(left, py(0));
        canvas.lineTo(w - right, py(0));
        canvas.strokePath();
      }

      // The line itself
      canvas.setStrokeColor(_purple);
      canvas.setLineWidth(1.4);
      canvas.moveTo(xOf(0), py(series[0]));
      for (var i = 1; i < n; i++) {
        canvas.lineTo(xOf(i), py(series[i]));
      }
      canvas.strokePath();

      void dot(int i, PdfColor color) {
        canvas.setFillColor(color);
        canvas.drawEllipse(xOf(i), py(series[i]), 2.6, 2.6);
        canvas.fillPath();
      }

      dot(0, _purple);
      dot(n - 1, _purple);
      if (minIdx != 0 && minIdx != n - 1) dot(minIdx, _red);
      if (maxIdx != 0 && maxIdx != n - 1) dot(maxIdx, _green);
    }

    DateTime dayAt(int i) => DateTime(start.year, start.month, start.day + i);
    String dateText(int i) {
      final d = dayAt(i);
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      return n <= 120 ? '$dd/$mm' : '$mm/${d.year % 100}';
    }

    final xLabels = <pw.Widget>[];
    for (var k = 0; k < 5; k++) {
      final i = ((n - 1) * k / 4).round();
      final x = (xOf(i) - 20).clamp(0.0, w - 40.0).toDouble();
      xLabels.add(
        pw.Positioned(
          left: x,
          top: h - bottom + 5,
          child: pw.SizedBox(
            width: 40,
            child: pw.Text(dateText(i), textAlign: pw.TextAlign.center, style: _tick),
          ),
        ),
      );
    }

    final chart = pw.SizedBox(
      width: w,
      height: h,
      child: pw.Stack(
        children: [
          pw.CustomPaint(size: const PdfPoint(w, h), painter: paint),
          ..._yLabels(axis, yTop, left - 6, mask),
          ...xLabels,
        ],
      ),
    );

    final net = closing - opening;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        chart,
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Opening: ${fmt(opening)}', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('Change: ${fmt(net)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.Text('Closing: ${fmt(closing)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            _legendItem(_red, 'Low ${fmt(series[minIdx])} (${dateText(minIdx)})'),
            pw.SizedBox(width: 16),
            _legendItem(_green, 'High ${fmt(series[maxIdx])} (${dateText(maxIdx)})'),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Cash flow trend (income up, expenses down, net line)
  // ---------------------------------------------------------------------------

  static pw.Widget cashflowTrend({
    required List<CashflowBucket> buckets,
    required String Function(double) fmt,
    required bool mask,
  }) {
    if (buckets.isEmpty || buckets.every((b) => b.income == 0 && b.expense == 0)) {
      return noData('No income or expenses in the selected period.');
    }

    const double w = _w, h = 190, left = 40, right = 6, top = 8, bottom = 30;
    const double plotW = w - left - right;
    const double plotH = h - top - bottom;
    final n = buckets.length;

    double lo = 0, hi = 0;
    for (final b in buckets) {
      hi = math.max(hi, math.max(b.income, b.net));
      lo = math.min(lo, math.min(-b.expense, b.net));
    }
    final axis = _niceAxis(lo, hi);

    double yTop(double v) => top + plotH * (1 - (v - axis.min) / (axis.max - axis.min));
    final colW = plotW / n;
    final barW = math.min(24.0, colW * 0.55);
    double cx(int i) => left + colW * (i + 0.5);

    void paint(PdfGraphics canvas, PdfPoint size) {
      double py(double v) => h - yTop(v);

      canvas.setLineWidth(0.4);
      canvas.setStrokeColor(_grid);
      for (final t in axis.ticks) {
        canvas.moveTo(left, py(t));
        canvas.lineTo(w - right, py(t));
        canvas.strokePath();
      }

      for (var i = 0; i < n; i++) {
        final b = buckets[i];
        if (b.income > 0) {
          canvas.setFillColor(_green);
          canvas.drawRect(cx(i) - barW / 2, py(0), barW, py(b.income) - py(0));
          canvas.fillPath();
        }
        if (b.expense > 0) {
          canvas.setFillColor(_red);
          canvas.drawRect(cx(i) - barW / 2, py(-b.expense), barW, py(0) - py(-b.expense));
          canvas.fillPath();
        }
      }

      // Zero baseline above the bars
      canvas.setStrokeColor(PdfColors.grey700);
      canvas.setLineWidth(0.8);
      canvas.moveTo(left, py(0));
      canvas.lineTo(w - right, py(0));
      canvas.strokePath();

      // Net line
      canvas.setStrokeColor(_purple);
      canvas.setLineWidth(1.3);
      if (n >= 2) {
        canvas.moveTo(cx(0), py(buckets[0].net));
        for (var i = 1; i < n; i++) {
          canvas.lineTo(cx(i), py(buckets[i].net));
        }
        canvas.strokePath();
      }
      canvas.setFillColor(_purple);
      for (var i = 0; i < n; i++) {
        canvas.drawEllipse(cx(i), py(buckets[i].net), 2.2, 2.2);
        canvas.fillPath();
      }
    }

    final every = (n / 12).ceil();
    final xLabels = <pw.Widget>[];
    for (var i = 0; i < n; i++) {
      if (i % every != 0) continue;
      final b = buckets[i];
      xLabels.add(
        pw.Positioned(
          left: cx(i) - 17,
          top: h - bottom + 4,
          child: pw.SizedBox(
            width: 34,
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(b.label, textAlign: pw.TextAlign.center, style: _tick),
                if (b.sublabel != null)
                  pw.Text(b.sublabel!, textAlign: pw.TextAlign.center, style: _tick),
              ],
            ),
          ),
        ),
      );
    }

    final chart = pw.SizedBox(
      width: w,
      height: h,
      child: pw.Stack(
        children: [
          pw.CustomPaint(size: const PdfPoint(w, h), painter: paint),
          ..._yLabels(axis, yTop, left - 6, mask),
          ...xLabels,
        ],
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        chart,
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            _legendItem(_green, 'Income'),
            pw.SizedBox(width: 14),
            _legendItem(_red, 'Expenses'),
            pw.SizedBox(width: 14),
            _legendItem(_purple, 'Net result', line: true),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sankey: income sources -> total -> spending categories (+ surplus / deficit)
  // ---------------------------------------------------------------------------

  static List<_SNode> _nodes(
    Map<String, double> src,
    int top,
    List<PdfColor> colors,
    PdfColor otherColor,
  ) {
    final entries = src.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final out = <_SNode>[];
    if (entries.length <= top + 1) {
      for (var i = 0; i < entries.length; i++) {
        out.add(_SNode(_clip(entries[i].key), entries[i].value, colors[i % colors.length]));
      }
    } else {
      for (var i = 0; i < top; i++) {
        out.add(_SNode(_clip(entries[i].key), entries[i].value, colors[i % colors.length]));
      }
      final rest = entries.skip(top).fold<double>(0, (s, e) => s + e.value);
      out.add(_SNode('Other (${entries.length - top})', rest, otherColor));
    }
    return out;
  }

  static pw.Widget sankey({
    required Map<String, double> income,
    required Map<String, double> expenses,
    required double totalIncome,
    required double totalExpense,
    required String Function(double) fmt,
    required bool mask,
  }) {
    if (totalIncome <= 0 && totalExpense <= 0) {
      return noData('No income or expenses in the selected period.');
    }

    final leftNodes = _nodes(income, 3, _incomeColors, _slate);
    if (leftNodes.isEmpty && totalIncome > 0) {
      leftNodes.add(_SNode('Income', totalIncome, _incomeColors[0]));
    }
    final deficit = totalExpense - totalIncome;
    if (deficit > 0.005) {
      leftNodes.add(_SNode('From savings', deficit, _red));
    }

    final rightNodes = _nodes(expenses, 7, _palette, _slate);
    if (rightNodes.isEmpty && totalExpense > 0) {
      rightNodes.add(_SNode('Expenses', totalExpense, _palette[0]));
    }
    final surplus = totalIncome - totalExpense;
    if (surplus > 0.005) {
      rightNodes.add(_SNode('Unspent', surplus, _teal));
    }

    final leftSum = leftNodes.fold<double>(0, (s, n) => s + n.value);
    final rightSum = rightNodes.fold<double>(0, (s, n) => s + n.value);
    final total = math.max(leftSum, rightSum);
    if (total <= 0) return noData('No income or expenses in the selected period.');

    const double w = _w, nodeW = 10, gap = 8, topPad = 18, botPad = 4;
    const double leftX = 120, centerX = 240, rightX = 360;
    final maxCount = math.max(leftNodes.length, rightNodes.length);
    final double h = (60 + maxCount * 30).clamp(170, 300).toDouble();
    final plotH = h - topPad - botPad;
    final scale = (plotH - (maxCount - 1) * gap) / total;

    List<double> place(List<_SNode> nodes) {
      final colH = nodes.fold<double>(0, (s, n) => s + n.value * scale) + (nodes.length - 1) * gap;
      var y = topPad + (plotH - colH) / 2;
      final tops = <double>[];
      for (final n in nodes) {
        tops.add(y);
        y += n.value * scale + gap;
      }
      return tops;
    }

    final leftTops = place(leftNodes);
    final rightTops = place(rightNodes);
    final centerH = total * scale;
    final centerTop = topPad + (plotH - centerH) / 2;

    void paint(PdfGraphics canvas, PdfPoint size) {
      double py(double y) => h - y;

      void ribbon(double x1, double y1t, double y1b, double x2, double y2t, double y2b, PdfColor color) {
        final xm = (x1 + x2) / 2;
        canvas.setFillColor(color);
        canvas.moveTo(x1, py(y1t));
        canvas.curveTo(xm, py(y1t), xm, py(y2t), x2, py(y2t));
        canvas.lineTo(x2, py(y2b));
        canvas.curveTo(xm, py(y2b), xm, py(y1b), x1, py(y1b));
        canvas.closePath();
        canvas.fillPath();
      }

      // Sources -> total
      var cursor = centerTop;
      for (var i = 0; i < leftNodes.length; i++) {
        final hh = leftNodes[i].value * scale;
        ribbon(leftX + nodeW, leftTops[i], leftTops[i] + hh, centerX, cursor, cursor + hh,
            _lighten(leftNodes[i].color, 0.6));
        cursor += hh;
      }

      // Total -> spending categories
      cursor = centerTop;
      for (var j = 0; j < rightNodes.length; j++) {
        final hh = rightNodes[j].value * scale;
        ribbon(centerX + nodeW, cursor, cursor + hh, rightX, rightTops[j], rightTops[j] + hh,
            _lighten(rightNodes[j].color, 0.6));
        cursor += hh;
      }

      void node(double x, double top, double height, PdfColor color) {
        final hh = math.max(height, 1.5);
        canvas.setFillColor(color);
        canvas.drawRect(x, py(top + hh), nodeW, hh);
        canvas.fillPath();
      }

      for (var i = 0; i < leftNodes.length; i++) {
        node(leftX, leftTops[i], leftNodes[i].value * scale, leftNodes[i].color);
      }
      node(centerX, centerTop, centerH, _purple);
      for (var j = 0; j < rightNodes.length; j++) {
        node(rightX, rightTops[j], rightNodes[j].value * scale, rightNodes[j].color);
      }
    }

    pw.Widget header(double x, double width, String text, {bool bold = false}) {
      return pw.Positioned(
        left: x,
        top: 0,
        child: pw.SizedBox(
          width: width,
          child: pw.Text(
            text,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 7.5,
              color: PdfColors.grey700,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      );
    }

    String label(_SNode n) => '${n.name}  ${fmt(n.value)}';

    final overlays = <pw.Widget>[
      header(leftX - 45, 100, 'SOURCES'),
      header(centerX - 50, 110, 'TOTAL  ${fmt(total)}', bold: true),
      header(rightX - 30, 100, 'SPENDING'),
      for (var i = 0; i < leftNodes.length; i++)
        pw.Positioned(
          left: 0,
          top: leftTops[i] + leftNodes[i].value * scale / 2 - 4.5,
          child: pw.SizedBox(
            width: leftX - 6,
            child: pw.Text(label(leftNodes[i]), textAlign: pw.TextAlign.right, style: _tick),
          ),
        ),
      for (var j = 0; j < rightNodes.length; j++)
        pw.Positioned(
          left: rightX + nodeW + 6,
          top: rightTops[j] + rightNodes[j].value * scale / 2 - 4.5,
          child: pw.SizedBox(
            width: w - (rightX + nodeW + 6),
            child: pw.Text(label(rightNodes[j]), style: _tick),
          ),
        ),
    ];

    return pw.SizedBox(
      width: w,
      height: h,
      child: pw.Stack(
        children: [
          pw.CustomPaint(size: PdfPoint(w, h), painter: paint),
          ...overlays,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Donut chart with legend (expense distribution)
  // ---------------------------------------------------------------------------

  static pw.Widget donut({
    required Map<String, double> values,
    required String Function(double) fmt,
    required bool mask,
    required String centerLabel,
    required double centerValue,
    int top = 6,
  }) {
    final nodes = _nodes(values, top, _palette, _slate);
    final total = nodes.fold<double>(0, (s, n) => s + n.value);
    if (total <= 0) return noData('No data to chart for the selected period.');

    const double size = 150, outerR = 70, innerR = 42;

    void paint(PdfGraphics canvas, PdfPoint box) {
      const cx = size / 2, cy = size / 2;
      var f0 = 0.0;
      for (final n in nodes) {
        final f1 = f0 + n.value / total;
        final steps = math.max(2, ((f1 - f0) * 120).ceil());

        double angle(double f) => math.pi / 2 - f * 2 * math.pi;

        canvas.setFillColor(n.color);
        canvas.moveTo(cx + outerR * math.cos(angle(f0)), cy + outerR * math.sin(angle(f0)));
        for (var k = 1; k <= steps; k++) {
          final a = angle(f0 + (f1 - f0) * k / steps);
          canvas.lineTo(cx + outerR * math.cos(a), cy + outerR * math.sin(a));
        }
        for (var k = steps; k >= 0; k--) {
          final a = angle(f0 + (f1 - f0) * k / steps);
          canvas.lineTo(cx + innerR * math.cos(a), cy + innerR * math.sin(a));
        }
        canvas.closePath();
        canvas.setStrokeColor(PdfColors.white);
        canvas.setLineWidth(0.8);
        canvas.fillAndStrokePath();
        f0 = f1;
      }
    }

    final ring = pw.SizedBox(
      width: size,
      height: size,
      child: pw.Stack(
        children: [
          pw.CustomPaint(size: const PdfPoint(size, size), painter: paint),
          pw.Positioned(
            left: 0,
            top: size / 2 - 11,
            child: pw.SizedBox(
              width: size,
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(centerLabel, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  pw.Text(
                    fmt(centerValue),
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final legend = <pw.Widget>[];
    for (final n in nodes) {
      final pct = n.value / total * 100;
      legend.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            children: [
              pw.Container(width: 8, height: 8, color: n.color),
              pw.SizedBox(width: 6),
              pw.Expanded(child: pw.Text(n.name, style: const pw.TextStyle(fontSize: 8))),
              pw.Text(fmt(n.value), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 6),
              pw.SizedBox(
                width: 34,
                child: pw.Text(
                  '${pct.toStringAsFixed(1)}%',
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        ring,
        pw.SizedBox(width: 20),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: legend)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Pool balances (horizontal bars; negative balances in red)
  // ---------------------------------------------------------------------------

  static pw.Widget poolBars({
    required Map<String, double> balances,
    required String Function(double) fmt,
  }) {
    final entries = balances.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return noData('No pool balances available.');
    final maxAbs = entries.fold<double>(0, (m, e) => math.max(m, e.value.abs()));

    return pw.Column(
      children: [
        for (final e in entries)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 80,
                  child: pw.Text(e.key.toUpperCase(), style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Expanded(
                  child: pw.Stack(
                    children: [
                      pw.Container(
                        height: 10,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey200,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                      ),
                      pw.Container(
                        height: 10,
                        width: maxAbs > 0 ? 240 * (e.value.abs() / maxAbs) : 0.0,
                        decoration: pw.BoxDecoration(
                          color: e.value >= 0 ? _green : _red,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.SizedBox(
                  width: 90,
                  child: pw.Text(
                    fmt(e.value),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Axis {
  final double min;
  final double max;
  final double step;
  const _Axis(this.min, this.max, this.step);

  List<double> get ticks {
    final out = <double>[];
    final n = ((max - min) / step).round();
    for (var i = 0; i <= n; i++) {
      out.add(min + i * step);
    }
    return out;
  }
}

class _SNode {
  final String name;
  final double value;
  final PdfColor color;
  const _SNode(this.name, this.value, this.color);
}