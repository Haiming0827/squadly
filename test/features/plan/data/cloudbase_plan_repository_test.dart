import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';

import 'package:squadly/features/plan/data/repositories/cloudbase_plan_repository.dart';
import 'package:squadly/features/plan/domain/entities/squad_plan.dart';

void main() {
  test(
    'creates a Squad-linked private plan with the authenticated owner',
    () async {
      http.Request? capturedRequest;
      final client = PostgrestClient(
        'https://env.example/v1/rdb/rest',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode(_planRow(visibility: 'private')),
            201,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = CloudBasePlanRepository(
        client: client,
        currentUserId: () async => 'user-a',
      );

      final result = await repository.createPlan(
        squadId: 'squad-1',
        title: '  我的跑步计划  ',
        category: PlanCategory.fitness,
        visibility: PlanVisibility.private,
        startDate: DateTime(2026, 10, 18),
      );

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['squad_id'], 'squad-1');
      expect(body['created_by'], 'user-a');
      expect(body['title'], '我的跑步计划');
      expect(body['visibility'], 'private');
      expect(body['start_date'], '2026-10-18');
      expect(
        result.match((failure) => failure, (plan) => plan.visibility),
        PlanVisibility.private,
      );
    },
  );

  test('rejects invalid plan dates without making a request', () async {
    var requestCount = 0;
    final client = PostgrestClient(
      'https://env.example/v1/rdb/rest',
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200, request: request);
      }),
    );
    addTearDown(client.dispose);

    final result =
        await CloudBasePlanRepository(
          client: client,
          currentUserId: () async => 'user-a',
        ).createPlan(
          squadId: 'squad-1',
          title: 'Plan',
          category: PlanCategory.custom,
          visibility: PlanVisibility.squad,
          startDate: DateTime(2026, 10, 20),
          endDate: DateTime(2026, 10, 19),
        );

    expect(result.isLeft(), isTrue);
    expect(requestCount, 0);
  });

  test('maps preserved legacy travel fields on a unified plan', () async {
    final legacyRow = _planRow()
      ..['legacy_source'] = 'travel_plan'
      ..['legacy_id'] = 'legacy-travel-1'
      ..['legacy_data'] = {
        'destination': '杭州',
        'budget': 1200,
        'linked_fund_id': 'fund-1',
      };
    final client = PostgrestClient(
      'https://env.example/v1/rdb/rest',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode([legacyRow]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    final result = await CloudBasePlanRepository(
      client: client,
      currentUserId: () async => 'user-a',
    ).getSquadPlans(squadId: 'squad-1');

    expect(
      result.match((failure) => failure, (plans) => plans.single.legacySource),
      'travel_plan',
    );
    expect(
      result.match((failure) => failure, (plans) => plans.single.legacyId),
      'legacy-travel-1',
    );
    expect(
      result.match(
        (failure) => failure,
        (plans) => plans.single.legacyData['destination'],
      ),
      '杭州',
    );
    expect(
      result.match(
        (failure) => failure,
        (plans) => plans.single.legacyData['budget'],
      ),
      1200,
    );
  });

  test('groups visible task counts by plan for progress indicators', () async {
    http.Request? capturedRequest;
    final client = PostgrestClient(
      'https://env.example/v1/rdb/rest',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode([
            {'plan_id': 'plan-1', 'is_complete': true},
            {'plan_id': 'plan-1', 'is_complete': false},
            {'plan_id': 'plan-2', 'is_complete': true},
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await CloudBasePlanRepository(
      client: client,
      currentUserId: () async => 'user-a',
    ).getSquadPlanProgress(squadId: 'squad-1');

    expect(
      capturedRequest!.url.queryParameters['select'],
      'plan_id,is_complete',
    );
    expect(capturedRequest!.url.queryParameters['squad_id'], 'eq.squad-1');
    expect(
      result.match(
        (failure) => failure,
        (value) => value['plan-1']?.completedCount,
      ),
      1,
    );
    expect(
      result.match(
        (failure) => failure,
        (value) => value['plan-1']?.totalCount,
      ),
      2,
    );
    expect(
      result.match((failure) => failure, (value) => value['plan-2']?.fraction),
      1,
    );
  });

  test('creates a task with its plan and squad context', () async {
    http.Request? capturedRequest;
    final client = PostgrestClient(
      'https://env.example/v1/rdb/rest',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(_taskRow()),
          201,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result =
        await CloudBasePlanRepository(
          client: client,
          currentUserId: () async => 'user-a',
        ).createTask(
          planId: 'plan-1',
          squadId: 'squad-1',
          title: '  第一次训练  ',
          assignedTo: 'user-a',
          dueDate: DateTime(2026, 10, 20),
        );

    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    expect(body['plan_id'], 'plan-1');
    expect(body['squad_id'], 'squad-1');
    expect(body['created_by'], 'user-a');
    expect(body['title'], '第一次训练');
    expect(body['assigned_to'], 'user-a');
    expect(body['due_date'], '2026-10-20');
    expect(result.match((failure) => failure, (task) => task.title), '第一次训练');
  });

  test(
    'changes plan status without changing owner or Squad association',
    () async {
      http.Request? capturedRequest;
      final client = PostgrestClient(
        'https://env.example/v1/rdb/rest',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode(_planRow()..['status'] = 'completed'),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);

      final result = await CloudBasePlanRepository(
        client: client,
        currentUserId: () async => 'user-a',
      ).setPlanStatus(planId: 'plan-1', status: PlanStatus.completed);

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(capturedRequest!.method, 'PATCH');
      expect(body['status'], 'completed');
      expect(body.containsKey('created_by'), isFalse);
      expect(body.containsKey('squad_id'), isFalse);
      expect(
        result.match((failure) => failure, (plan) => plan.status),
        PlanStatus.completed,
      );
    },
  );

  test('edits plan metadata without changing its owner or Squad', () async {
    http.Request? capturedRequest;
    final client = PostgrestClient(
      'https://env.example/v1/rdb/rest',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        final row = _planRow()..['title'] = '更新后的计划';
        return http.Response(
          jsonEncode(row),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result =
        await CloudBasePlanRepository(
          client: client,
          currentUserId: () async => 'user-a',
        ).updatePlan(
          planId: 'plan-1',
          title: ' 更新后的计划 ',
          category: PlanCategory.travel,
          visibility: PlanVisibility.private,
          description: '新的说明',
          startDate: DateTime(2026, 10, 19),
          endDate: DateTime(2026, 10, 21),
        );

    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    expect(capturedRequest!.method, 'PATCH');
    expect(body['title'], '更新后的计划');
    expect(body['description'], '新的说明');
    expect(body['category'], 'travel');
    expect(body['visibility'], 'private');
    expect(body['start_date'], '2026-10-19');
    expect(body['end_date'], '2026-10-21');
    expect(body.containsKey('created_by'), isFalse);
    expect(body.containsKey('squad_id'), isFalse);
    expect(result.match((failure) => failure, (plan) => plan.title), '更新后的计划');
  });

  test('requires an authenticated owner before creating a plan', () async {
    var requestCount = 0;
    final client = PostgrestClient(
      'https://env.example/v1/rdb/rest',
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200, request: request);
      }),
    );
    addTearDown(client.dispose);

    final result =
        await CloudBasePlanRepository(
          client: client,
          currentUserId: () async => null,
        ).createPlan(
          squadId: 'squad-1',
          title: 'Plan',
          category: PlanCategory.custom,
          visibility: PlanVisibility.squad,
        );

    expect(result.isLeft(), isTrue);
    expect(requestCount, 0);
  });
}

Map<String, dynamic> _planRow({String visibility = 'squad'}) => {
  'id': 'plan-1',
  'squad_id': 'squad-1',
  'title': '我的跑步计划',
  'description': null,
  'category': 'fitness',
  'visibility': visibility,
  'status': 'active',
  'start_date': '2026-10-18',
  'end_date': null,
  'created_by': 'user-a',
  'created_at': '2026-10-18T00:00:00Z',
  'updated_at': '2026-10-18T00:00:00Z',
};

Map<String, dynamic> _taskRow() => {
  'id': 'task-1',
  'plan_id': 'plan-1',
  'squad_id': 'squad-1',
  'title': '第一次训练',
  'details': null,
  'assigned_to': 'user-a',
  'due_date': '2026-10-20',
  'is_complete': false,
  'completed_by': null,
  'completed_at': null,
  'position': 0,
  'created_by': 'user-a',
  'created_at': '2026-10-18T00:00:00Z',
  'updated_at': '2026-10-18T00:00:00Z',
};
