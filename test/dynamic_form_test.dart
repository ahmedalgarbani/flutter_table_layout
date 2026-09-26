import 'package:flutter/material.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DynamicFormField Type Detection Tests', () {
    test('should detect correct FieldType from column properties', () {
      final columns = [
        AdaptiveTableColumn<dynamic>(id: 'id', title: 'ID', fieldName: 'id'),
        AdaptiveTableColumn<dynamic>(
          id: 'name',
          title: 'Name',
          fieldName: 'name',
        ),
        AdaptiveTableColumn<dynamic>(
          id: 'amount',
          title: 'Amount',
          fieldName: 'amountValue',
        ),
        AdaptiveTableColumn<dynamic>(
          id: 'created_at',
          title: 'Created At',
          fieldName: 'createdDate',
        ),
        AdaptiveTableColumn<dynamic>(
          id: 'is_active',
          title: 'Is Active',
          fieldName: 'isActive',
        ),
      ];

      final fields = DynamicFormField.detectFromColumns(
        columns,
        dropdownItems: {
          'name': ['Item A', 'Item B'],
        },
      );

      // Verify ID (number detected since it is id)
      final idField = fields.firstWhere((f) => f.id == 'id');
      expect(idField.type, equals(FieldType.number));

      // Verify Name (dropdown detected because of dropdownItems mapping)
      final nameField = fields.firstWhere((f) => f.id == 'name');
      expect(nameField.type, equals(FieldType.dropdown));
      expect(nameField.dropdownItems, containsAll(['Item A', 'Item B']));

      // Verify Amount (number detected because fieldName contains amount)
      final amountField = fields.firstWhere((f) => f.id == 'amount');
      expect(amountField.type, equals(FieldType.number));

      // Verify Date (date detected because fieldName contains Date)
      final dateField = fields.firstWhere((f) => f.id == 'created_at');
      expect(dateField.type, equals(FieldType.date));

      // Verify Boolean (boolean detected because fieldName contains active)
      final activeField = fields.firstWhere((f) => f.id == 'is_active');
      expect(activeField.type, equals(FieldType.boolean));
    });
  });

  group('DynamicForm Widget Tests', () {
    testWidgets('should render input fields and validate inputs', (
      WidgetTester tester,
    ) async {
      final fields = [
        DynamicFormField(
          id: 'name',
          label: 'Item Name',
          type: FieldType.text,
          isRequired: true,
        ),
        DynamicFormField(
          id: 'price',
          label: 'Price',
          type: FieldType.number,
          isRequired: true,
        ),
        DynamicFormField(
          id: 'active',
          label: 'Active',
          type: FieldType.boolean,
          initialValue: true,
        ),
      ];

      Map<String, dynamic>? submittedValues;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicForm(
                fields: fields,
                theme: const AdaptiveTableTheme(
                  cardBackgroundColor: Colors.white,
                  borderRadius: BorderRadius.zero,
                  headerBackgroundColor: Colors.blue,
                  headerTextStyle: TextStyle(),
                  rowBackgroundColor: Colors.white,
                  alternateRowBackgroundColor: Colors.grey,
                  rowTextStyle: TextStyle(),
                  rowHoverColor: Colors.blue,
                  dividerColor: Colors.grey,
                  footerBackgroundColor: Colors.white,
                  footerTextStyle: TextStyle(),
                ),
                onCancel: () {},
                onFormSubmitted: (values) {
                  submittedValues = values;
                },
              ),
            ),
          ),
        ),
      );

      // Verify rendering of form fields
      expect(find.byType(TextFormField), findsNWidgets(2)); // Name & Price
      expect(find.byType(SwitchListTile), findsOneWidget); // Active

      // Click send without typing (should fail validation)
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(submittedValues, isNull);
      expect(find.text('Field is required'), findsNWidgets(2));

      // Enter valid values
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Item Name'),
        'Apples',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Price'),
        '4.99',
      );

      // Toggle Switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Submit Form
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(submittedValues, isNotNull);
      expect(submittedValues!['name'], equals('Apples'));
      expect(submittedValues!['price'], equals(4.99));
      expect(
        submittedValues!['active'],
        equals(false),
      ); // Toggled from true to false
    });
  });

  group('Type inference (whole words)', () {
    test('does not treat words containing "is" as booleans', () {
      expect(
        DynamicFormField.inferType('discount', 'discount'),
        FieldType.number,
      );
      expect(
        DynamicFormField.inferType('description', 'description'),
        FieldType.text,
      );
      expect(
        DynamicFormField.inferType('wishlist', 'wishlist'),
        FieldType.text,
      );
      expect(DynamicFormField.inferType('history', 'history'), FieldType.text);
    });

    test('detects prefixes, suffixes and snake/camel case', () {
      expect(DynamicFormField.inferType('x', 'isDeposit'), FieldType.boolean);
      expect(
        DynamicFormField.inferType('has_stock', 'has_stock'),
        FieldType.boolean,
      );
      expect(
        DynamicFormField.inferType('created', 'createdAt'),
        FieldType.date,
      );
      expect(
        DynamicFormField.inferType('updated_on', 'updated_on'),
        FieldType.date,
      );
      expect(DynamicFormField.inferType('userId', 'userId'), FieldType.number);
      expect(
        DynamicFormField.inferType('generatedBy', 'generatedBy'),
        FieldType.text,
      );
    });

    test('fieldTypes overrides and excluded / non-exportable columns', () {
      final fields = DynamicFormField.detectFromColumns<dynamic>(
        [
          AdaptiveTableColumn<dynamic>(id: 'status', title: 'Status'),
          AdaptiveTableColumn<dynamic>(id: 'actions', title: 'Actions'),
          AdaptiveTableColumn<dynamic>(
            id: 'menu',
            title: 'Menu',
            isExportable: false,
          ),
        ],
        fieldTypes: {'status': FieldType.text},
      );
      expect(fields.map((f) => f.id), ['status']);
      expect(fields.single.type, FieldType.text);
    });
  });

  group('DynamicForm values', () {
    Future<Map<String, dynamic>?> submit(
      WidgetTester tester,
      List<DynamicFormField> fields,
    ) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicForm(
                fields: fields,
                onFormSubmitted: (v) => result = v,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('required dropdown submits the displayed first item', (
      tester,
    ) async {
      final v = await submit(tester, [
        DynamicFormField(
          id: 'cur',
          label: 'Currency',
          type: FieldType.dropdown,
          dropdownItems: ['USD', 'EUR'],
          isRequired: true,
        ),
      ]);
      expect(v?['cur'], 'USD');
    });

    testWidgets('invalid dropdown initial value does not crash', (
      tester,
    ) async {
      final v = await submit(tester, [
        DynamicFormField(
          id: 'cur',
          label: 'Currency',
          type: FieldType.dropdown,
          dropdownItems: ['USD', 'EUR'],
          initialValue: 'GBP',
        ),
      ]);
      expect(tester.takeException(), isNull);
      expect(v, isNotNull);
      expect(v!['cur'], isNull);
    });

    testWidgets('empty optional number submits null, dates default', (
      tester,
    ) async {
      final v = await submit(tester, [
        DynamicFormField(id: 'n', label: 'N', type: FieldType.number),
        DynamicFormField(
          id: 'd',
          label: 'D',
          type: FieldType.date,
          initialValue: DateTime(2026, 1, 2),
        ),
      ]);
      expect(v?['n'], isNull);
      expect(v?['d'], DateTime(2026, 1, 2));
    });

    testWidgets('custom validators run for every field type', (tester) async {
      final v = await submit(tester, [
        DynamicFormField(
          id: 'agree',
          label: 'Agree',
          type: FieldType.boolean,
          validator: (val) => val == true ? null : 'Must agree',
        ),
      ]);
      expect(v, isNull);
      expect(find.text('Must agree'), findsOneWidget);
    });

    testWidgets('submitted map is a copy', (tester) async {
      final results = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicForm(
              fields: [
                DynamicFormField(
                  id: 't',
                  label: 'T',
                  type: FieldType.text,
                  initialValue: 'a',
                ),
              ],
              onFormSubmitted: results.add,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      results.first['t'] = 'changed';
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(results.last['t'], 'a');
      expect(identical(results.first, results.last), isFalse);
    });

    testWidgets('DynamicFormDialog.show returns the values', (tester) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await DynamicFormDialog.show(
                  context,
                  title: 'New',
                  fields: [
                    DynamicFormField(
                      id: 'name',
                      label: 'Name',
                      type: FieldType.text,
                      initialValue: 'Ada',
                    ),
                  ],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(result, {'name': 'Ada'});
    });

    testWidgets(
      'should support custom controllers and update programmatically',
      (WidgetTester tester) async {
        final controller = TextEditingController(text: 'Initial Temp');
        final fields = [
          DynamicFormField(
            id: 'name',
            label: 'Item Name',
            type: FieldType.text,
            controller: controller,
          ),
        ];

        Map<String, dynamic>? submittedValues;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DynamicForm(
                fields: fields,
                theme: const AdaptiveTableTheme(
                  cardBackgroundColor: Colors.white,
                  borderRadius: BorderRadius.zero,
                  headerBackgroundColor: Colors.blue,
                  headerTextStyle: TextStyle(),
                  rowBackgroundColor: Colors.white,
                  alternateRowBackgroundColor: Colors.grey,
                  rowTextStyle: TextStyle(),
                  rowHoverColor: Colors.blue,
                  dividerColor: Colors.grey,
                  footerBackgroundColor: Colors.white,
                  footerTextStyle: TextStyle(),
                ),
                onCancel: () {},
                onFormSubmitted: (values) {
                  submittedValues = values;
                },
              ),
            ),
          ),
        );

        expect(find.text('Initial Temp'), findsOneWidget);

        // Update programmatically
        controller.text = 'Updated Programmatically';
        await tester.pump();

        expect(find.text('Updated Programmatically'), findsOneWidget);

        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        expect(submittedValues, isNotNull);
        expect(submittedValues!['name'], equals('Updated Programmatically'));
      },
    );

    testWidgets('should support multi-select field type and chips', (
      WidgetTester tester,
    ) async {
      final fields = [
        DynamicFormField(
          id: 'tags',
          label: 'Tags',
          type: FieldType.multiSelect,
          dropdownItems: ['Red', 'Green', 'Blue'],
          initialValue: ['Red'],
        ),
      ];

      Map<String, dynamic>? submittedValues;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicForm(
              fields: fields,
              theme: const AdaptiveTableTheme(
                cardBackgroundColor: Colors.white,
                borderRadius: BorderRadius.zero,
                headerBackgroundColor: Colors.blue,
                headerTextStyle: TextStyle(),
                rowBackgroundColor: Colors.white,
                alternateRowBackgroundColor: Colors.grey,
                rowTextStyle: TextStyle(),
                rowHoverColor: Colors.blue,
                dividerColor: Colors.grey,
                footerBackgroundColor: Colors.white,
                footerTextStyle: TextStyle(),
              ),
              onCancel: () {},
              onFormSubmitted: (values) {
                submittedValues = values;
              },
            ),
          ),
        ),
      );

      // Verify chip renders initial value 'Red'
      expect(find.text('Red'), findsOneWidget);

      // Tap on multiSelect selector to open dialog
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();

      // Dialog is open, we should see checkbox list tiles for Red, Green, Blue
      expect(find.text('Green'), findsOneWidget);
      expect(find.text('Blue'), findsOneWidget);

      // Tap Green checkbox
      await tester.tap(find.text('Green'));
      await tester.pumpAndSettle();

      // Save selection
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Now we should see chips for 'Red' and 'Green'
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Green'), findsOneWidget);

      // Submit Form
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(submittedValues, isNotNull);
      expect(submittedValues!['tags'], containsAll(['Red', 'Green']));
    });

    testWidgets('should invoke onAddInstance callback on inline creation', (
      WidgetTester tester,
    ) async {
      bool addCalled = false;
      final fields = [
        DynamicFormField(
          id: 'category',
          label: 'Category',
          type: FieldType.dropdown,
          dropdownItems: ['Food'],
          onAddInstance: (ctx) async {
            addCalled = true;
            return 'Drinks';
          },
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicForm(
              fields: fields,
              theme: const AdaptiveTableTheme(
                cardBackgroundColor: Colors.white,
                borderRadius: BorderRadius.zero,
                headerBackgroundColor: Colors.blue,
                headerTextStyle: TextStyle(),
                rowBackgroundColor: Colors.white,
                alternateRowBackgroundColor: Colors.grey,
                rowTextStyle: TextStyle(),
                rowHoverColor: Colors.blue,
                dividerColor: Colors.grey,
                footerBackgroundColor: Colors.white,
                footerTextStyle: TextStyle(),
              ),
              onCancel: () {},
              onFormSubmitted: (values) {},
            ),
          ),
        ),
      );

      // Find the add icon button (which has '+' action tooltip or just icon)
      await tester.tap(find.byIcon(Icons.add_circle));
      await tester.pumpAndSettle();

      expect(addCalled, isTrue);
      // 'Drinks' should now be selected value in dropdown
      expect(find.text('Drinks'), findsOneWidget);
    });
  });
}
