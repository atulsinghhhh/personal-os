import '../entities/subscription.dart';

abstract class SubscriptionRepository {
  Stream<List<Subscription>> watchAll({bool activeOnly = false});
  Future<Subscription?> getById(String id);
  Future<void> create(Subscription subscription);
  Future<void> update(Subscription subscription);
  Future<void> delete(String id);
}
