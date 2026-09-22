import '../entities/asset.dart';

abstract class AssetRepository {
  Stream<List<Asset>> watchAll();
  Future<Asset?> getById(String id);
  Future<void> create(Asset asset);
  Future<void> update(Asset asset);
  Future<void> delete(String id);
}
