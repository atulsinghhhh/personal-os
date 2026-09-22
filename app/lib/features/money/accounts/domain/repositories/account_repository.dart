import '../entities/financial_account.dart';
import '../../../../../shared/models/money.dart';

abstract class FinancialAccountRepository {
  Stream<List<FinancialAccount>> watchAll({bool includeArchived = false});
  Future<FinancialAccount?> getById(String id);
  Future<void> create(FinancialAccount account);
  Future<void> update(FinancialAccount account);
  Future<void> delete(String id);

  /// Opening balance + signed sum of the account's transactions.
  Future<Money> currentBalance(String accountId);
}
