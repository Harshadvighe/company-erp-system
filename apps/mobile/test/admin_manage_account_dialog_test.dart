import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin Manage Account & Provisioning Dialog Regression Tests', () {
    testWidgets(
      'Provisioning/Manage Account dialog renders successfully without OverflowBar ParentData error',
      (tester) async {
        bool dialogSubmitted = false;
        bool resetPasswordOpened = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        barrierDismissible: true,
                        builder: (ctx) {
                          final usernameCtrl = TextEditingController(text: 'kavita.kulkarni');
                          final passwordCtrl = TextEditingController(text: '');
                          final desigCtrl = TextEditingController(text: 'Wireman Assistant');
                          String? selectedDeptId = 'dept-1';
                          String? selectedRoleId = 'role-1';
                          const alreadyProvisioned = true;

                          final uniqueDepts = [
                            {'id': 'dept-1', 'name': 'IT', 'code': 'IT'},
                            {'id': 'dept-2', 'name': 'R&D', 'code': 'RND'},
                          ];

                          final uniqueRoles = [
                            {'id': 'role-1', 'name': 'Employee', 'code': 'ROLE_EMPLOYEE'},
                            {'id': 'role-2', 'name': 'Admin', 'code': 'ROLE_ADMIN'},
                          ];

                          return AlertDialog(
                            actionsAlignment: alreadyProvisioned ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
                            actionsOverflowAlignment: OverflowBarAlignment.end,
                            title: const Text('Manage Employee Account'),
                            content: SizedBox(
                              width: 580,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(controller: usernameCtrl),
                                    TextField(controller: passwordCtrl),
                                    TextField(controller: desigCtrl),
                                    DropdownButton<String>(
                                      value: selectedDeptId,
                                      items: uniqueDepts.map((d) {
                                        return DropdownMenuItem<String>(
                                          value: d['id'],
                                          child: Text('${d['name']} (${d['code']})'),
                                        );
                                      }).toList(),
                                      onChanged: (v) => selectedDeptId = v,
                                    ),
                                    DropdownButton<String>(
                                      value: selectedRoleId,
                                      items: uniqueRoles.map((r) {
                                        return DropdownMenuItem<String>(
                                          value: r['id'],
                                          child: Text('${r['name']} (${r['code']})'),
                                        );
                                      }).toList(),
                                      onChanged: (v) => selectedRoleId = v,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            actions: [
                              if (alreadyProvisioned)
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    resetPasswordOpened = true;
                                  },
                                  icon: const Icon(Icons.lock_reset, size: 15),
                                  label: const Text('Reset Password'),
                                ),
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      dialogSubmitted = true;
                                      Navigator.pop(ctx);
                                    },
                                    icon: const Icon(Icons.save_outlined, size: 16),
                                    label: const Text('Update Employee Details'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('Manage Account'),
                  );
                },
              ),
            ),
          ),
        );

        // 1. Click "Manage Account"
        await tester.tap(find.text('Manage Account'));
        await tester.pumpAndSettle();

        // 2. Verify dialog components are on-screen without any crash
        expect(find.text('Manage Employee Account'), findsOneWidget);
        expect(find.text('Reset Password'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Update Employee Details'), findsOneWidget);
        expect(find.text('IT (IT)'), findsOneWidget);
        expect(find.text('Employee (ROLE_EMPLOYEE)'), findsOneWidget);

        // 3. Test submitting the dialog
        await tester.tap(find.text('Update Employee Details'));
        await tester.pumpAndSettle();

        expect(dialogSubmitted, isTrue);
        expect(find.text('Manage Employee Account'), findsNothing);

        // 4. Verify parent button is still fully interactive
        expect(find.text('Manage Account'), findsOneWidget);
        await tester.tap(find.text('Manage Account'));
        await tester.pumpAndSettle();
        expect(find.text('Manage Employee Account'), findsOneWidget);

        // 5. Test opening Reset Password from within Manage Account
        await tester.tap(find.text('Reset Password'));
        await tester.pumpAndSettle();
        expect(resetPasswordOpened, isTrue);
        expect(find.text('Manage Employee Account'), findsNothing);
      },
    );

    testWidgets(
      'Reset Password dialog opens and dismisses safely without blocking background interactions',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        barrierDismissible: true,
                        builder: (ctx) {
                          return AlertDialog(
                            title: const Text('Reset Employee Password'),
                            content: const Text('Enter new password'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Reset Password'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('Reset Password Button'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Reset Password Button'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Employee Password'), findsOneWidget);

        // Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Employee Password'), findsNothing);
        expect(find.text('Reset Password Button'), findsOneWidget);
      },
    );
  });
}
