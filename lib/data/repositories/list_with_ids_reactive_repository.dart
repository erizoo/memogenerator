import 'package:rxdart/rxdart.dart';
import 'package:collection/collection.dart';

abstract class ListWithIdsReactiveRepository<T> {
  final updater = PublishSubject<Null>();

  Future<List<String>> getRawData();

  Future<bool> saveRawData(final List<String> items);

  T convertFromString(final String rawItem);

  String convertToString(final T item);

  dynamic getId(final T item);

  Future<List<T>> getItems() async {
    // получаем сырой список мемов, листы со стрингами
    final rawItems = await getRawData();
    // получаем мем по id, сырой список превратили в стринг
    return rawItems.map((rawItem) => convertFromString(rawItem)).toList();
  }

  Future<bool> setItems(final List<T> items) async {
    final rawItems = items.map((item) => convertToString(item)).toList();
    // сохраняем
    return _setRawItems(rawItems);
  }

  // отображение всего списка избранного на главном экране
  // при изменении данных запашивать данные у shared_Preferences
  // подписка на мемы
  Stream<List<T>> observeItems() async* {
    // возвращаем значение в Stream подождав, от сюда _getMemes()
    yield await getItems();
    await for (final _ in updater) {
      // приходит инфа в updater
      // отдаем текущее состояние хранилища
      yield await getItems();
    }
  }

  // метод добавления в главный экран
  Future<bool> addItem(final T item) async {
    // получаем сырой список memes, листы со стрингами
    final items = await getItems();
    // сохраняем
    items.add(item);
    return setItems(items);
  }

  // удаление
  Future<bool> removeItem(final T item) async {
    // получаем сырой список memes, листы со стрингами
    final items = await getItems();
    // удаляем
    items.remove(item);
    return setItems(items);
  }

  // метод добавления в главный экран по id
  Future<bool> addItemOrReplaceById(final T newItem) async {
    // получаем сырой список memes, листы со стрингами
    final items = await getItems();
    // получение доступа к id существующего мема и сравниваем с новым
    final itemIndex = items.indexWhere((item) => getId(item) == getId(newItem));
    // если нет мема, то добавляем его
    if (itemIndex == -1) {
      // возвращаем старые мемы и новые
      items.add(newItem);
    } else {
      items[itemIndex] = newItem;
    }

    // возвращаем все мемы
    return setItems(items);
  }

  // удаление по id
  Future<bool> removeFromItemsById(final dynamic id) async {
    // получаем мем по id, сырой список превратили в стринг
    final items = await getItems();
    // удаляем новый мем
    items.removeWhere((item) => getId(item) == id);
    // сохраняем
    return setItems(items);
  }

  // сохранение списка избранного в локальном хранилище
  // и его отображение на экране
  Future<T?> getItemById(final dynamic id) async {
    // получаем meme
    final items = await getItems();
    return items.firstWhereOrNull((item) => getId(item) == id);
  }

  Future<bool> _setRawItems(final List<String> rawItems) {
    updater.add(null);
    return saveRawData(rawItems);
  }
}
