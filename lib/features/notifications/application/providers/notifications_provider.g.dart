// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationsRemoteDataSource)
final notificationsRemoteDataSourceProvider =
    NotificationsRemoteDataSourceProvider._();

final class NotificationsRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          NotificationsRemoteDataSource,
          NotificationsRemoteDataSource,
          NotificationsRemoteDataSource
        >
    with $Provider<NotificationsRemoteDataSource> {
  NotificationsRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationsRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationsRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<NotificationsRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationsRemoteDataSource create(Ref ref) {
    return notificationsRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationsRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationsRemoteDataSource>(
        value,
      ),
    );
  }
}

String _$notificationsRemoteDataSourceHash() =>
    r'e2762d5603d951d757c2fb01be8062f60d750b2b';

@ProviderFor(notificationsRepository)
final notificationsRepositoryProvider = NotificationsRepositoryProvider._();

final class NotificationsRepositoryProvider
    extends
        $FunctionalProvider<
          NotificationsRepository,
          NotificationsRepository,
          NotificationsRepository
        >
    with $Provider<NotificationsRepository> {
  NotificationsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationsRepositoryHash();

  @$internal
  @override
  $ProviderElement<NotificationsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationsRepository create(Ref ref) {
    return notificationsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationsRepository>(value),
    );
  }
}

String _$notificationsRepositoryHash() =>
    r'bd05f7b160ac3153e7bd67340cc8b018f114c91c';

@ProviderFor(getNotifications)
final getNotificationsProvider = GetNotificationsProvider._();

final class GetNotificationsProvider
    extends
        $FunctionalProvider<
          GetNotifications,
          GetNotifications,
          GetNotifications
        >
    with $Provider<GetNotifications> {
  GetNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getNotificationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getNotificationsHash();

  @$internal
  @override
  $ProviderElement<GetNotifications> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetNotifications create(Ref ref) {
    return getNotifications(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetNotifications value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetNotifications>(value),
    );
  }
}

String _$getNotificationsHash() => r'848e15ea9747090fc13bca90e1567a1370dba216';

@ProviderFor(markAsRead)
final markAsReadProvider = MarkAsReadProvider._();

final class MarkAsReadProvider
    extends $FunctionalProvider<MarkAsRead, MarkAsRead, MarkAsRead>
    with $Provider<MarkAsRead> {
  MarkAsReadProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'markAsReadProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$markAsReadHash();

  @$internal
  @override
  $ProviderElement<MarkAsRead> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MarkAsRead create(Ref ref) {
    return markAsRead(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MarkAsRead value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MarkAsRead>(value),
    );
  }
}

String _$markAsReadHash() => r'75d44cc28a8aa0566b4d978421a2592cd678b5c4';

@ProviderFor(notifications)
final notificationsProvider = NotificationsProvider._();

final class NotificationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AppNotification>>,
          List<AppNotification>,
          FutureOr<List<AppNotification>>
        >
    with
        $FutureModifier<List<AppNotification>>,
        $FutureProvider<List<AppNotification>> {
  NotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationsHash();

  @$internal
  @override
  $FutureProviderElement<List<AppNotification>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AppNotification>> create(Ref ref) {
    return notifications(ref);
  }
}

String _$notificationsHash() => r'09823f47abf4f89150f6dcda8e1e7287467ec238';

@ProviderFor(NotificationFilter)
final notificationFilterProvider = NotificationFilterProvider._();

final class NotificationFilterProvider
    extends $NotifierProvider<NotificationFilter, String> {
  NotificationFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationFilterHash();

  @$internal
  @override
  NotificationFilter create() => NotificationFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$notificationFilterHash() =>
    r'920cc6d2583bedf8a744cfe17d88943e4af6e6c6';

abstract class _$NotificationFilter extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(unreadCount)
final unreadCountProvider = UnreadCountProvider._();

final class UnreadCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  UnreadCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return unreadCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$unreadCountHash() => r'8ddcdaf18bb2e31ce4efb34fc3f35d83df6252f9';
