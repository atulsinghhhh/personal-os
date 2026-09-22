import '../entities/bill.dart';

abstract class BillRepository {
  /// All bills that aren't deleted, due-date ascending.
  Stream<List<Bill>> watchAll();

  /// Bills due on or after seven days ago (recently due + upcoming),
  /// due-date ascending, at most [limit] rows.
  Stream<List<Bill>> watchUpcoming(int limit);

  Future<Bill?> getById(String id);
  Future<void> create(Bill bill);
  Future<void> update(Bill bill);
  Future<void> delete(String id);

  /// Marks [bill] paid: sets lastPaidAt to now and, when the bill recurs,
  /// rolls dueDate forward one period (weekly +7 days, monthly +1 month
  /// clamped to the last day of the target month, yearly +1 year). Does NOT
  /// create a transaction — the UI offers that separately.
  Future<void> markPaid(Bill bill, {required String userId});
}
