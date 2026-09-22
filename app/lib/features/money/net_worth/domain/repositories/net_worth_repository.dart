import '../entities/net_worth.dart';

abstract class NetWorthRepository {
  /// Historical snapshots, date ascending.
  Stream<List<NetWorthSnapshot>> watchSnapshots();

  /// Inserts or replaces the snapshot for its date (caller supplies a
  /// stable id per (user, date)).
  Future<void> upsertSnapshot(NetWorthSnapshot snapshot);

  /// Computes current net worth per currency from recorded data only:
  ///
  ///   assets(currency)      = Σ balances of non-archived, non-credit-card
  ///                           accounts (opening balance + income − expense)
  ///                           where the balance is positive
  ///                         + Σ manual asset values
  ///   liabilities(currency) = Σ debt current balances
  ///                         + amounts owed on credit-card accounts
  ///                           (max(0, −balance))
  ///                         + overdrawn amounts of other accounts
  ///                           (max(0, −balance))
  ///
  /// Transparent arithmetic on user-entered figures; no estimation.
  Future<Map<String, NetWorthEntry>> computeCurrent(String userId);
}
