import '../entities/debt.dart';

abstract class DebtRepository {
  Stream<List<Debt>> watchAll();
  Future<Debt?> getById(String id);
  Future<void> create(Debt debt);
  Future<void> update(Debt debt);
  Future<void> delete(String id);
}
