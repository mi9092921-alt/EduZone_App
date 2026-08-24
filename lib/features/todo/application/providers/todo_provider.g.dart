// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(todoRemoteDataSource)
final todoRemoteDataSourceProvider = TodoRemoteDataSourceProvider._();

final class TodoRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          TodoRemoteDataSourceImpl,
          TodoRemoteDataSourceImpl,
          TodoRemoteDataSourceImpl
        >
    with $Provider<TodoRemoteDataSourceImpl> {
  TodoRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todoRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todoRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<TodoRemoteDataSourceImpl> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TodoRemoteDataSourceImpl create(Ref ref) {
    return todoRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TodoRemoteDataSourceImpl value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TodoRemoteDataSourceImpl>(value),
    );
  }
}

String _$todoRemoteDataSourceHash() =>
    r'3b219ea6a52a11307bce22cb66f54df7bffd3a77';

@ProviderFor(todoRepository)
final todoRepositoryProvider = TodoRepositoryProvider._();

final class TodoRepositoryProvider
    extends $FunctionalProvider<TodoRepository, TodoRepository, TodoRepository>
    with $Provider<TodoRepository> {
  TodoRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todoRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todoRepositoryHash();

  @$internal
  @override
  $ProviderElement<TodoRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TodoRepository create(Ref ref) {
    return todoRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TodoRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TodoRepository>(value),
    );
  }
}

String _$todoRepositoryHash() => r'5ec0ebe663459f8185c580d2ac7dbe812315ff05';

@ProviderFor(getTodos)
final getTodosProvider = GetTodosProvider._();

final class GetTodosProvider
    extends $FunctionalProvider<GetTodos, GetTodos, GetTodos>
    with $Provider<GetTodos> {
  GetTodosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getTodosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getTodosHash();

  @$internal
  @override
  $ProviderElement<GetTodos> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetTodos create(Ref ref) {
    return getTodos(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetTodos value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetTodos>(value),
    );
  }
}

String _$getTodosHash() => r'41006a6b6b389a6ba860f629510853f065f2dac0';

@ProviderFor(addTodo)
final addTodoProvider = AddTodoProvider._();

final class AddTodoProvider
    extends $FunctionalProvider<AddTodo, AddTodo, AddTodo>
    with $Provider<AddTodo> {
  AddTodoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'addTodoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$addTodoHash();

  @$internal
  @override
  $ProviderElement<AddTodo> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AddTodo create(Ref ref) {
    return addTodo(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AddTodo value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AddTodo>(value),
    );
  }
}

String _$addTodoHash() => r'0b22cb7793612ca3fbdcf4614d420569bb5b3e3d';

@ProviderFor(toggleTodo)
final toggleTodoProvider = ToggleTodoProvider._();

final class ToggleTodoProvider
    extends $FunctionalProvider<ToggleTodo, ToggleTodo, ToggleTodo>
    with $Provider<ToggleTodo> {
  ToggleTodoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toggleTodoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toggleTodoHash();

  @$internal
  @override
  $ProviderElement<ToggleTodo> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ToggleTodo create(Ref ref) {
    return toggleTodo(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ToggleTodo value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ToggleTodo>(value),
    );
  }
}

String _$toggleTodoHash() => r'4b9bb1ac087ec47c12735a5c77d75efad94be1c1';

@ProviderFor(deleteTodo)
final deleteTodoProvider = DeleteTodoProvider._();

final class DeleteTodoProvider
    extends $FunctionalProvider<DeleteTodo, DeleteTodo, DeleteTodo>
    with $Provider<DeleteTodo> {
  DeleteTodoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deleteTodoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deleteTodoHash();

  @$internal
  @override
  $ProviderElement<DeleteTodo> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeleteTodo create(Ref ref) {
    return deleteTodo(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeleteTodo value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeleteTodo>(value),
    );
  }
}

String _$deleteTodoHash() => r'70b33297c332cf53ab092e05186dde97f49a4edf';

@ProviderFor(updateTodo)
final updateTodoProvider = UpdateTodoProvider._();

final class UpdateTodoProvider
    extends $FunctionalProvider<UpdateTodo, UpdateTodo, UpdateTodo>
    with $Provider<UpdateTodo> {
  UpdateTodoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateTodoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateTodoHash();

  @$internal
  @override
  $ProviderElement<UpdateTodo> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UpdateTodo create(Ref ref) {
    return updateTodo(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateTodo value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateTodo>(value),
    );
  }
}

String _$updateTodoHash() => r'47094c7f54015a8469ec94cef4911d9b5b9fce9d';

@ProviderFor(TodoNotifier)
final todoProvider = TodoNotifierProvider._();

final class TodoNotifierProvider
    extends $NotifierProvider<TodoNotifier, TodoState> {
  TodoNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todoNotifierHash();

  @$internal
  @override
  TodoNotifier create() => TodoNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TodoState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TodoState>(value),
    );
  }
}

String _$todoNotifierHash() => r'b8c7cd02e2d44d1426a98ccf95426e442c378190';

abstract class _$TodoNotifier extends $Notifier<TodoState> {
  TodoState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<TodoState, TodoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TodoState, TodoState>,
              TodoState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
