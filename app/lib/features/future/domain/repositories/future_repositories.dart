import '../entities/future_entities.dart';

abstract class LifeAreaRepository {
  Stream<List<LifeArea>> watchAll();
  Future<LifeArea?> getById(String id);
  Future<void> create(LifeArea lifeArea);
  Future<void> update(LifeArea lifeArea);
  Future<void> delete(String id);
  Future<void> reorder(List<String> orderedIds);
}

abstract class VisionRepository {
  Stream<List<Vision>> watchAll();
  Stream<List<Vision>> watchByLifeArea(String lifeAreaId);
  Future<Vision?> getById(String id);
  Future<void> create(Vision vision);
  Future<void> update(Vision vision);
  Future<void> delete(String id);
}
