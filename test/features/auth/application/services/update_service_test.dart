import 'package:app/features/auth/application/services/update_service.dart';
import 'package:app/features/auth/data/datasources/update_remote_ds.dart';
import 'package:app/features/auth/domain/entities/update_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUpdateRemoteDataSource extends Mock implements UpdateRemoteDataSource {}

void main() {
  late MockUpdateRemoteDataSource mockRemote;
  late UpdateService service;

  setUp(() {
    mockRemote = MockUpdateRemoteDataSource();
    service = UpdateService(mockRemote);
  });

  group('checkForUpdate', () {
    test('returns forceUpdate when current version is below min_app_version',
        () async {
      when(() => mockRemote.fetchConfig()).thenAnswer(
        (_) async => {
          'latest_version': '2.0.0',
          'min_app_version': '2.0.0',
          'force_update': true,
          'update_message': 'Please update',
          'store_link_android': 'https://play.google.com/store',
          'store_link_ios': '',
        },
      );

      final result = await service.checkForUpdate('1.0.0');

      expect(result.status, UpdateStatus.forceUpdate);
    });

    test('returns optionalUpdate when current version is below latest but above min',
        () async {
      when(() => mockRemote.fetchConfig()).thenAnswer(
        (_) async => {
          'latest_version': '1.5.0',
          'min_app_version': '1.0.0',
          'force_update': false,
          'update_message': 'New version available',
          'store_link_android': 'https://play.google.com/store',
          'store_link_ios': '',
        },
      );

      final result = await service.checkForUpdate('1.2.0');

      expect(result.status, UpdateStatus.optionalUpdate);
    });

    test('returns upToDate when current version matches latest', () async {
      when(() => mockRemote.fetchConfig()).thenAnswer(
        (_) async => {
          'latest_version': '1.0.0',
          'min_app_version': '1.0.0',
          'force_update': false,
          'update_message': '',
          'store_link_android': '',
          'store_link_ios': '',
        },
      );

      final result = await service.checkForUpdate('1.0.0');

      expect(result.status, UpdateStatus.upToDate);
    });

    test('returns upToDate (fail-safe) when remote throws', () async {
      when(() => mockRemote.fetchConfig())
          .thenThrow(Exception('network error'));

      final result = await service.checkForUpdate('1.0.0');

      expect(result.status, UpdateStatus.upToDate);
    });
  });
}
