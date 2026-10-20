import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import '../services/exam_api.dart';

typedef ExamRow = Map<String, dynamic>;
Future<List<String>?> examSelection(
  BuildContext context,
  String title,
  List<(String, String)> items, {
  bool selectAll = false,
}) {
  final selected = selectAll
      ? items.map((item) => item.$1).toSet()
      : <String>{};
  return showDialog<List<String>>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items)
                  CheckboxListTile(
                    value: selected.contains(item.$1),
                    onChanged: (checked) => setState(
                      () => checked == true
                          ? selected.add(item.$1)
                          : selected.remove(item.$1),
                    ),
                    title: Text(item.$2),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selected.toList()),
            child: const Text('Dùng lựa chọn này'),
          ),
        ],
      ),
    ),
  );
}

List<ExamRow> examRows(dynamic value) =>
    (value as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();

class ExamCard extends StatelessWidget {
  const ExamCard({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadii.panel),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            ...actions,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class ExamEmpty extends StatelessWidget {
  const ExamEmpty(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(
          Icons.description_outlined,
          size: 38,
          color: AppColors.primary,
        ),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, height: 1.5),
        ),
      ],
    ),
  );
}

class ExamError extends StatelessWidget {
  const ExamError(this.error, {super.key});
  final Object error;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.errorSurface,
      borderRadius: BorderRadius.circular(AppRadii.control),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(error.toString(), style: const TextStyle(color: AppColors.error)),
        if (error is ExamApiException)
          for (final detail in (error as ExamApiException).details)
            Text(
              detail is Map
                  ? '${detail['label']}: cần ${detail['required']}, có ${detail['available']}, thiếu ${detail['missing']}'
                  : detail.toString(),
              style: const TextStyle(color: AppColors.error),
            ),
      ],
    ),
  );
}

class ExamAsset extends StatefulWidget {
  const ExamAsset({super.key, required this.api, required this.id});
  final ExamApi api;
  final String id;
  @override
  State<ExamAsset> createState() => _ExamAssetState();
}

class _ExamAssetState extends State<ExamAsset> {
  late final bytes = widget.api.bytes('assets/${widget.id}');
  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) return ExamError(snapshot.error!);
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(),
        );
      }
      return Image.memory(snapshot.data!, fit: BoxFit.contain);
    },
  );
}

class ExamInput {
  const ExamInput(
    this.name,
    this.label, {
    this.value = '',
    this.required = true,
    this.kind = 'text',
    this.options = const [],
    this.lines = 1,
  });
  final String name, label, kind;
  final Object? value;
  final bool required;
  final List<(String, String)> options;
  final int lines;
}

Future<ExamRow?> examForm(
  BuildContext context,
  String title,
  List<ExamInput> inputs, {
  String submit = 'Lưu',
}) => showDialog<ExamRow>(
  context: context,
  builder: (_) => _ExamForm(title: title, inputs: inputs, submit: submit),
);

class _ExamForm extends StatefulWidget {
  const _ExamForm({
    required this.title,
    required this.inputs,
    required this.submit,
  });
  final String title, submit;
  final List<ExamInput> inputs;
  @override
  State<_ExamForm> createState() => _ExamFormState();
}

class _ExamFormState extends State<_ExamForm> {
  final key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;
  late final Map<String, String> choices;
  @override
  void initState() {
    super.initState();
    controllers = {
      for (final i in widget.inputs)
        if (i.options.isEmpty)
          i.name: TextEditingController(text: i.value?.toString() ?? ''),
    };
    choices = {
      for (final i in widget.inputs)
        if (i.options.isNotEmpty)
          i.name: i.options.any((o) => o.$1 == i.value)
              ? i.value.toString()
              : i.options.first.$1,
    };
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? validate(ExamInput i, String? value) {
    if (i.required && (value == null || value.trim().isEmpty)) {
      return 'Vui lòng nhập ${i.label.toLowerCase()}';
    }
    if (value != null &&
        value.isNotEmpty &&
        i.kind == 'int' &&
        int.tryParse(value) == null) {
      return 'Cần nhập số nguyên';
    }
    if (value != null &&
        value.isNotEmpty &&
        i.kind == 'number' &&
        double.tryParse(value) == null) {
      return 'Cần nhập số';
    }
    return null;
  }

  void save() {
    if (!key.currentState!.validate()) return;
    final values = <String, dynamic>{};
    for (final i in widget.inputs) {
      final value = choices[i.name] ?? controllers[i.name]!.text.trim();
      values[i.name] = i.kind == 'int'
          ? (value.isEmpty ? null : int.parse(value))
          : i.kind == 'number'
          ? (value.isEmpty ? null : double.parse(value))
          : value;
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.panel),
    ),
    title: Text(
      widget.title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final i in widget.inputs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: i.options.isEmpty
                      ? TextFormField(
                          controller: controllers[i.name],
                          maxLines: i.lines,
                          keyboardType: i.kind == 'int' || i.kind == 'number'
                              ? TextInputType.number
                              : TextInputType.text,
                          decoration: InputDecoration(labelText: i.label),
                          validator: (v) => validate(i, v),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: choices[i.name],
                          isExpanded: true,
                          decoration: InputDecoration(labelText: i.label),
                          items: i.options
                              .map(
                                (o) => DropdownMenuItem(
                                  value: o.$1,
                                  child: Text(
                                    o.$2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => choices[i.name] = v ?? '',
                          validator: (v) => validate(i, v),
                        ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: save, child: Text(widget.submit)),
    ],
  );
}

