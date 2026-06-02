import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RoutePreview extends StatelessWidget {
  const RoutePreview({super.key, required this.polyline});
  final String? polyline;

  @override
  Widget build(BuildContext context) {
    final points =
        polyline == null ? <RouteLatLng>[] : decodePolyline(polyline!);
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: points.length < 2
          ? const Center(
              child: Text('NO ROUTE MAP AVAILABLE', style: KickerStyle.text),
            )
          : CustomPaint(
              painter: RoutePainter(points),
            ),
    );
  }
}

class RouteLatLng {
  const RouteLatLng(this.lat, this.lng);
  final double lat;
  final double lng;
}

List<RouteLatLng> decodePolyline(String polyline) {
  final points = <RouteLatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < polyline.length) {
    var result = 0;
    var shift = 0;
    var byte = 0;
    do {
      byte = polyline.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

    result = 0;
    shift = 0;
    do {
      byte = polyline.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

    points.add(RouteLatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}

class RoutePainter extends CustomPainter {
  RoutePainter(this.points);
  final List<RouteLatLng> points;

  @override
  void paint(Canvas canvas, Size size) {
    final minLat = points.map((point) => point.lat).reduce(math.min);
    final maxLat = points.map((point) => point.lat).reduce(math.max);
    final minLng = points.map((point) => point.lng).reduce(math.min);
    final maxLng = points.map((point) => point.lng).reduce(math.max);
    final latSpan = maxLat - minLat == 0 ? 1.0 : maxLat - minLat;
    final lngSpan = maxLng - minLng == 0 ? 1.0 : maxLng - minLng;
    const pad = 18.0;
    final scale = math.min(
        (size.width - pad * 2) / lngSpan, (size.height - pad * 2) / latSpan);
    final routeWidth = lngSpan * scale;
    final routeHeight = latSpan * scale;
    final offsetX = (size.width - routeWidth) / 2;
    final offsetY = (size.height - routeHeight) / 2;

    Offset project(RouteLatLng point) {
      return Offset(
        offsetX + (point.lng - minLng) * scale,
        offsetY + (maxLat - point.lat) * scale,
      );
    }

    final path = Path()
      ..moveTo(project(points.first).dx, project(points.first).dy);
    for (final point in points.skip(1)) {
      final offset = project(point);
      path.lineTo(offset.dx, offset.dy);
    }

    final linePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final outlinePaint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final startPaint = Paint()..color = AppColors.foreground;
    final endPaint = Paint()..color = AppColors.accent;
    final start = project(points.first);
    final end = project(points.last);
    canvas.drawCircle(start, 6, startPaint);
    canvas.drawCircle(start, 6, outlinePaint);
    canvas.drawCircle(end, 6, endPaint);
    canvas.drawCircle(end, 6, outlinePaint);
  }

  @override
  bool shouldRepaint(RoutePainter oldDelegate) => oldDelegate.points != points;
}
