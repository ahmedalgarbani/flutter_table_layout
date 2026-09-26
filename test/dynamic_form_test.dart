import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';

void main() {
  group('DynamicFormField Type Detection Tests', () {
    test('should detect correct FieldType from column properties', () {
      final columns = [
        AdaptiveTableColumn<dynamic>(
          id: 'id',
          title: 'ID',
          fieldName: 'id',
        ),
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
    testWidgets('should render input fields and validate inputs', (WidgetTester tester) async {
      final fields = [
        DynamicFormField(id: 'name', label: 'Item Name', type: FieldType.text, isRequired: true),
        DynamicFormField(id: 'price', label: 'Price', type: FieldType.number, isRequired: true),
        DynamicFormField(id: 'active', label: 'Active', type: FieldType.boolean, initialValue: true),
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
      await tester.enterText(find.widgetWithText(TextFormField, 'Item Name'), 'Apples');
      await tester.enterText(find.widgetWithText(TextFormField, 'Price'), '4.99');
      
      // Toggle Switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Submit Form
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(submittedValues, isNotNull);
      expect(submittedValues!['name'], equals('Apples'));
      expect(submittedValues!['price'], equals(4.99));
      expect(submittedValues!['active'], equals(false)); // Toggled from true to false
    });

    testWidgets('should support custom controllers and update programmatically', (WidgetTester tester) async {
      final controller = TextEditingController(text: 'Initial Temp');
      final fields = [
        DynamicFormField(id: 'name', label: 'Item Name', type: FieldType.text, controller: controller),
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
    });

    testWidgets('should support multi-select field type and chips', (WidgetTester tester) async {
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

    testWidgets('should invoke onAddInstance callback on inline creation', (WidgetTester tester) async {
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
