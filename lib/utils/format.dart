import 'package:intl/intl.dart';

String formatTime(DateTime? time) {
  if (time == null) return '--:--';
  return DateFormat('hh:mm a').format(time);
}

String formatHours(double hours) {
  final whole = hours.floor();
  final minutes = ((hours - whole) * 60).round();
  if (minutes == 0) return '${whole}h';
  return '${whole}h ${minutes}m';
}

String formatDateLong(DateTime day) {
  return DateFormat('EEEE, d MMMM yyyy').format(day);
}

String formatMonthYear(DateTime day) {
  return DateFormat('MMMM yyyy').format(day);
}
