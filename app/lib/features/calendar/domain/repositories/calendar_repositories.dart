import '../entities/calendar_entities.dart';

abstract class CalendarEventRepository {
  Stream<List<CalendarEvent>> watchForDate(DateTime date);
  Stream<List<CalendarEvent>> watchForRange(DateTime start, DateTime end);
  Future<void> create(CalendarEvent event);
  Future<void> update(CalendarEvent event);
  Future<void> delete(String id);
}

abstract class TimeBlockRepository {
  Stream<List<TimeBlock>> watchForDate(DateTime date);
  Future<void> create(TimeBlock block);
  Future<void> update(TimeBlock block);
  Future<void> delete(String id);
}
