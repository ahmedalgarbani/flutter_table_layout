# دليل استخدام flutter_table_layout (بالعربية)

هذا الدليل يشرح كل ميزة مع مثال جاهز للنسخ. الأمثلة تستخدم هذا النموذج:

```dart
class Employee {
  final int id;
  final String name;
  final String department;
  final double salary;
  final DateTime hiredOn;
  final bool active;
  const Employee(this.id, this.name, this.department, this.salary, this.hiredOn, this.active);
}
```

---

## ١. البداية السريعة

```dart
AdaptiveTableLayout<Employee>(
  title: 'الموظفون',
  items: employees,
  columns: [
    AdaptiveTableColumn(id: 'id', title: 'الرقم', width: 80),
    AdaptiveTableColumn(id: 'name', title: 'الاسم', flex: 2),
    AdaptiveTableColumn(id: 'salary', title: 'الراتب',
        alignment: TableColumnAlignment.end),
    AdaptiveTableColumn(id: 'hiredOn', title: 'تاريخ التعيين'),
  ],
  // قيمة كل عمود: تُستخدم في العرض والبحث والفرز والتصدير
  valueProviders: {
    'id': (e) => e.id,
    'name': (e) => e.name,
    'salary': (e) => e.salary,
    'hiredOn': (e) => e.hiredOn,
  },
  dateProvider: (e) => e.hiredOn, // يُظهر فلتر "من تاريخ / إلى تاريخ"
)
```

- **الشاشات الكبيرة:** جدول.
- **الجوال** (أقل من 600px): بطاقات تلقائياً.
- **النصوص:** تظهر بالعربية تلقائياً إذا كانت لغة التطبيق `ar`.

### فلتر التاريخ (زر "الفترة")
عند تمرير `dateProvider` يظهر زر واحد: "📅 الفترة: هذا الشهر ▾"، وبجانبه ✕ للمسح. عند الضغط عليه:
- **الكمبيوتر والويب:** نافذة صغيرة تحت الزر، فيها قائمة فترات جاهزة، وتقويم لشهرين، وخانتا "من" و"إلى" للكتابة بصيغة yyyy-mm-dd.
- **الجوال:** نفس المحتوى في نافذة من الأسفل، والفترات الجاهزة فيها أزرار أفقية.

طريقة الاختيار:
- اضغط يوم البداية ثم يوم النهاية، فتتلوّن الأيام بينهما.
- **تطبيق** يفلتر الصفوف، أو ينتظر زر "استعلام" إذا مرّرت `onQueryPressed`.
- **مسح** يلغي الفلتر.

```dart
AdaptiveTableLayout<Employee>(
  dateProvider: (e) => e.hiredOn,
  datePresets: [                        // اختياري: اختر الفترات أو أضف فترات خاصة
    DateRangePreset.all,
    DateRangePreset.thisMonth,
    DateRangePreset.lastMonth,
    DateRangePreset(
      id: 'quarter',
      label: (l) => 'هذا الربع',
      range: (now) {
        final q = (now.month - 1) ~/ 3;
        return DateTimeRange(
          start: DateTime(now.year, q * 3 + 1),
          end: DateTime(now.year, q * 3 + 4, 0),
        );
      },
    ),
  ],
  // الشكل القديم (زرّا من/إلى) ما زال متوفراً:
  // dateFilterStyle: DateFilterStyle.separateFields,
)
```

---

## ٢. الشبكة المتقدمة

### تثبيت الأعمدة (Frozen columns)
```dart
AdaptiveTableColumn(id: 'id', title: 'الرقم', pin: ColumnPin.start),     // مثبت في البداية
AdaptiveTableColumn(id: 'actions', title: 'إجراءات', pin: ColumnPin.end), // مثبت في النهاية
```
- الأعمدة المثبتة تبقى ظاهرة عند التمرير الأفقي، وفي العربية تكون "البداية" هي اليمين.
- يمكن للمستخدم التثبيت بنفسه من زر 📌 في قائمة الأعمدة.
- من الكود: `controller.setColumnPin('city', ColumnPin.start)`.

### آلاف الصفوف مع رأس ثابت (Virtualization)
```dart
AdaptiveTableLayout<Employee>(
  items: employees,        // حتى 100,000 صف
  showPagination: false,
  bodyHeight: 500,         // أو fillHeight: true داخل Expanded
  ...
)
```
- تُبنى الصفوف الظاهرة فقط، ويبقى رأس الجدول ثابتاً أثناء التمرير.
- `fillHeight: true` يملأ ارتفاع الأب (مثل `Expanded` أو صفحة `TabBarView`).

### تغيير عرض الأعمدة وترتيبها
- **العرض:** اسحب الحافة اليمنى لرأس العمود. نقرتان على الحافة تعيدان العرض الأصلي.
- **الترتيب:** اضغط مطولاً على رأس العمود ثم اسحبه فوق عمود آخر.
- **الإرجاع:** "إعادة ضبط الأعمدة" في قائمة الأعمدة، أو `controller.resetColumnLayout()`.
- **التعطيل:** `allowColumnResize: false` / `allowColumnReorder: false`، أو `isResizable: false` لعمود واحد.

### فلتر لكل عمود
```dart
AdaptiveTableLayout<Employee>(showColumnFilters: true, ...)
```

| اكتب في الفلتر | المعنى |
|---|---|
| `أحمد` | يحتوي |
| `=المبيعات` / `!=المبيعات` | يساوي / لا يساوي |
| `!تجربة` | لا يحتوي |
| `>1000` `>=1000` `<50` `<=50` | مقارنة رقمية أو تاريخ أو نص |
| `1000..5000` | بين قيمتين (شامل) |
| `>=2026-01-01` | من تاريخ معيّن |
| `صنعاء, عدن` | أي واحد منها |

من الكود: `controller.setColumnFilter('salary', '>=3000')`.

### الفرز بأكثر من عمود
- انقر على رأس العمود للفرز.
- **Shift + نقر** على عمود آخر يضيف مستوى فرز ثانياً، ويظهر رقم المستوى (1، 2…) بجانب السهم.
```dart
controller.setSorts(const [ColumnSort('department'), ColumnSort('salary', ascending: false)]);
```

### تجميع الصفوف
```dart
AdaptiveTableLayout<Employee>(
  groupByColumnId: 'department',
  groupHeaderBuilder: (context, group) => Text(
    'المتوسط: ${group.rows.fold<double>(0, (s, e) => s + e.salary) / group.rows.length}',
  ),
)
```
- انقر على رأس المجموعة لطيّها أو فتحها.
- يمكن التغيير من الكود: `controller.groupBy('city')` أو `controller.groupBy(null)`.

### التعديل المباشر داخل الخلية
```dart
AdaptiveTableLayout<Employee>(
  columns: [
    AdaptiveTableColumn(id: 'name', title: 'الاسم', isEditable: true,
        cellValidator: (v) => (v as String).trim().isEmpty ? 'مطلوب' : null),
    AdaptiveTableColumn(id: 'salary', title: 'الراتب', isEditable: true),      // حقل رقم تلقائياً
    AdaptiveTableColumn(id: 'department', title: 'القسم', isEditable: true,
        editor: const CellEditor.dropdown(['المبيعات', 'الهندسة', 'المالية'])),
    AdaptiveTableColumn(id: 'hiredOn', title: 'التعيين', isEditable: true),   // منتقي تاريخ تلقائياً
    AdaptiveTableColumn(id: 'active', title: 'نشط', isEditable: true),        // يتبدّل بنقرتين
  ],
  canEditCell: (e, column) => user.canEdit,           // الصلاحيات
  onCellEdited: (e, column, value) async {
    final ok = await api.update(e.id, {column: value}); // احفظ التعديل
    if (ok) setState(() { /* حدّث القائمة */ });
    return ok;                                         // false = رفض التعديل
  },
)
```
- **البدء:** نقرتان على الخلية، أو Enter، أو F2.
- **الحفظ:** Enter، أو النقر خارج الخلية.
- **الإلغاء:** Esc.
- **التنقل:** Tab للخلية التالية، وShift+Tab للسابقة.
- **الأرقام:** تقبل `1,250.5`.
- **القيمة غير الصحيحة:** تُبقي المحرر مفتوحاً مع رسالة الخطأ.

### التحكم بلوحة المفاتيح
- **الأسهم:** التنقل بين الخلايا (معكوسة تلقائياً في العربية).
- **Space:** تحديد الصف.
- **Enter:** تعديل الخلية، أو فتح الصف.
- **Home / End:** أول / آخر عمود.
- **Page Up / Down:** الصفحة السابقة / التالية.
- **Ctrl+A:** تحديد الكل.
- **Esc:** الخروج من الخلية.

للتعطيل: `enableKeyboardNavigation: false`.

### البيانات من السيرفر
```dart
// أنشئه مرة واحدة (في initState أو كحقل late final)، وليس داخل build
late final source = AdaptiveTableDataSource<Employee>.fromCallback((q) async {
  final res = await api.employees(
    page: q.currentPage,
    size: q.pageSize,
    search: q.searchQuery,
    sort: [for (final s in q.sorts) '${s.columnId}:${s.ascending ? 'asc' : 'desc'}'],
    filters: q.columnFilters,
  );
  return TableDataPage(items: res.rows, totalCount: res.total);
});

AdaptiveTableLayout<Employee>(
  dataSource: source,        // لا حاجة لـ items
  columns: columns,
  valueProviders: providers,
  fillHeight: true,
)
```
- كل تغيير في البحث أو الفلاتر أو الفرز أو الصفحة يستدعي السيرفر.
- يظهر شريط تحميل أثناء الطلب، وتُتجاهل الردود القديمة.
- عند الخطأ يظهر زر **إعادة المحاولة**، ويمكن أيضاً استدعاء `controller.refresh()`.

---

## ٣. إخفاء الأجزاء والصلاحيات

```dart
AdaptiveTableLayout<Employee>(
  showSearch: false,                  // إخفاء البحث
  showDateFilter: false,              // إخفاء فلتر التاريخ
  showExport: user.canExport,
  showPrint: user.canPrint,
  showSelection: user.canEdit,
  showColumnsToggle: true,
  showPagination: true,
  showSummary: true,
  showClearFilters: true,
  onAddNewPressed: user.canCreate ? openMyAddDialog : null, // null = الزر مخفي
  exportOptions: const TableExportOptions(formats: {ExportFormat.excel}), // Excel فقط
  columns: [
    ...,
    if (user.canEdit) actionsColumn,  // عمود التعديل والحذف لمن يملك الصلاحية فقط
  ],
)
```

---

## ٤. التخصيص

| تريد | استخدم |
|---|---|
| نموذج إضافة أو تعديل خاص بك | `onAddNewPressed: () => showMyDialog()` |
| تصدير أو PDF خاص بك | `onExportRequested: (format, rows) async { ... }` |
| طباعة خاصة بك | `onPrintRequested: (rows) async { ... }` |
| أزرار إضافية في الشريط | `toolbarActions: [ ... ]` |
| فلاتر خاصة | `customFilters: [ ... ]` + `customFilterMatcher` |
| شكل الخلية | `cellBuilder` في العمود |
| تنسيق القيمة | `valueFormatter: (v) => ...` |
| لون صف معيّن | `rowColorBuilder: (e) => ...` |
| جدول دائماً أو بطاقات دائماً | `layoutMode: TableLayoutMode.table` / `.cards` |
| الألوان والتصميم | `theme: AdaptiveTableTheme.light(context).copyWith(...)` |
| كل النصوص | `labels: AdaptiveTableLabels.ar.copyWith(search: '...')` |

---

## ٥. التحكم من خارج الجدول

```dart
final controller = AdaptiveTableController<Employee>();
AdaptiveTableLayout<Employee>(controller: controller, ...);

controller.search('أحمد');
controller.setColumnFilter('salary', '>3000');
controller.sortBy('salary', ascending: false);
controller.addSort('name');
controller.groupBy('department');
controller.setColumnPin('name', ColumnPin.start);
controller.goToPage(2);
controller.selectAll();
final selected = controller.selectedItems;
final filtered = controller.filteredItems;
controller.resetFilters();
controller.refresh();
```

---

## ٦. التجاوب مع الشاشات والمنصات

| الشاشة | الشكل |
|---|---|
| جوال (أقل من 600px) | بطاقات قابلة للتوسيع، مع التجميع والتمرير الكسول، وشريط أدوات وترقيم مضغوط |
| تابلت وكمبيوتر وويب | جدول كامل بكل الميزات المتقدمة، مع تمرير أفقي إذا لم تتسع الأعمدة |
| RTL (العربية) | كل شيء معكوس تلقائياً: الأعمدة، والتثبيت، والأسهم، ولوحة المفاتيح |

المنصات المدعومة: Android وiOS وWeb وWindows وmacOS وLinux.

الاختبارات تغطي عرض 320 و390 و768 و1024 و1440 بكسل، بالاتجاهين، بدون أي فيضان (overflow).
