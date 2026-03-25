// ============================================================
// Data Exporter — Reusable XLSX/CSV export dialog
// ============================================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

enum ExportFormat { xlsx, csv }
enum ExportScope  { all, filtered, selected }

class ExportColumnDef {
  final String key;
  final String label;
  final bool defaultSelected;
  const ExportColumnDef({required this.key, required this.label, this.defaultSelected = true});
}

class ExportRequest {
  final ExportFormat format;
  final ExportScope scope;
  final List<String> columnKeys;
  const ExportRequest({required this.format, required this.scope, required this.columnKeys});
}

/// Show the export dialog. Returns the ExportRequest the user chose, or null if cancelled.
Future<ExportRequest?> showExportDialog({
  required BuildContext context,
  required List<ExportColumnDef> columns,
  required int totalCount,
  required int filteredCount,
  required int selectedCount,
  String title = 'Export Data',
}) {
  return showDialog<ExportRequest>(
    context: context,
    builder: (_) => _ExportDialog(
      columns: columns,
      totalCount: totalCount,
      filteredCount: filteredCount,
      selectedCount: selectedCount,
      title: title,
    ),
  );
}

class _ExportDialog extends StatefulWidget {
  final List<ExportColumnDef> columns;
  final int totalCount;
  final int filteredCount;
  final int selectedCount;
  final String title;

  const _ExportDialog({
    required this.columns,
    required this.totalCount,
    required this.filteredCount,
    required this.selectedCount,
    required this.title,
  });

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  ExportFormat _format = ExportFormat.xlsx;
  ExportScope  _scope  = ExportScope.filtered;
  late List<bool> _selected;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.columns.map((c) => c.defaultSelected).toList();
    // If no selected rows, default to filtered
    if (widget.selectedCount == 0 && _scope == ExportScope.selected) {
      _scope = ExportScope.filtered;
    }
  }

  int get _selectedColCount => _selected.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(widget.title,
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ]),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Format
                  _Section(title: 'Format', icon: Icons.file_present_rounded, child:
                    Row(children: [
                      _FormatChip(
                        label: 'Excel (.xlsx)', icon: Icons.table_chart_rounded,
                        color: const Color(0xFF1B5E20),
                        selected: _format == ExportFormat.xlsx,
                        onTap: () => setState(() => _format = ExportFormat.xlsx),
                      ),
                      const SizedBox(width: 10),
                      _FormatChip(
                        label: 'CSV (.csv)', icon: Icons.text_snippet_rounded,
                        color: const Color(0xFF1565C0),
                        selected: _format == ExportFormat.csv,
                        onTap: () => setState(() => _format = ExportFormat.csv),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Scope
                  _Section(title: 'Rows to Export', icon: Icons.dataset_rounded, child:
                    Column(children: [
                      _ScopeOption(
                        value: ExportScope.filtered,
                        current: _scope,
                        label: 'Filtered rows',
                        count: widget.filteredCount,
                        icon: Icons.filter_alt_rounded,
                        onTap: () => setState(() => _scope = ExportScope.filtered),
                      ),
                      _ScopeOption(
                        value: ExportScope.all,
                        current: _scope,
                        label: 'All rows',
                        count: widget.totalCount,
                        icon: Icons.select_all_rounded,
                        onTap: () => setState(() => _scope = ExportScope.all),
                      ),
                      if (widget.selectedCount > 0)
                        _ScopeOption(
                          value: ExportScope.selected,
                          current: _scope,
                          label: 'Selected rows',
                          count: widget.selectedCount,
                          icon: Icons.check_box_rounded,
                          onTap: () => setState(() => _scope = ExportScope.selected),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Columns
                  _Section(
                    title: 'Columns  ($_selectedColCount/${widget.columns.length} selected)',
                    icon: Icons.view_column_rounded,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(
                        onPressed: () => setState(() => _selected = List.filled(widget.columns.length, true)),
                        child: Text('All', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.primary)),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selected = List.filled(widget.columns.length, false)),
                        child: Text('None', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
                      ),
                    ]),
                    child: Wrap(
                      spacing: 6, runSpacing: 6,
                      children: widget.columns.asMap().entries.map((entry) {
                        final sel = _selected[entry.key];
                        return FilterChip(
                          label: Text(entry.value.label, style: GoogleFonts.poppins(fontSize: 11,
                            color: sel ? AppTheme.primary : AppTheme.grey600)),
                          selected: sel,
                          onSelected: (v) => setState(() => _selected[entry.key] = v),
                          selectedColor: AppTheme.primary.withOpacity(0.1),
                          checkmarkColor: AppTheme.primary,
                          side: BorderSide(color: sel ? AppTheme.primary : AppTheme.grey300),
                          backgroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }).toList(),
                    ),
                  ),
                ]),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${_countLabel()} · $_selectedColCount columns',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500),
                  ),
                ])),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.poppins(fontSize: 13)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _selectedColCount == 0 ? null : _export,
                  icon: _exporting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(_exporting ? 'Exporting...' : 'Export', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.grey300,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _countLabel() {
    switch (_scope) {
      case ExportScope.all:      return '${widget.totalCount} rows';
      case ExportScope.filtered: return '${widget.filteredCount} rows';
      case ExportScope.selected: return '${widget.selectedCount} rows';
    }
  }

  void _export() {
    final selectedKeys = <String>[];
    for (int i = 0; i < widget.columns.length; i++) {
      if (_selected[i]) selectedKeys.add(widget.columns[i].key);
    }
    Navigator.pop(context, ExportRequest(format: _format, scope: _scope, columnKeys: selectedKeys));
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  const _Section({required this.title, required this.icon, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 15, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.grey800)),
        if (trailing != null) ...[const Spacer(), trailing!],
      ]),
      const SizedBox(height: 10),
      child,
    ]);
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FormatChip({required this.label, required this.icon, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : AppTheme.grey300, width: selected ? 2 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: selected ? color : AppTheme.grey500),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? color : AppTheme.grey700)),
        ]),
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  final ExportScope value;
  final ExportScope current;
  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onTap;
  const _ScopeOption({required this.value, required this.current, required this.label, required this.count, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.grey200, width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Radio<ExportScope>(value: value, groupValue: current, onChanged: (_) => onTap(), activeColor: AppTheme.primary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          const SizedBox(width: 4),
          Icon(icon, size: 16, color: selected ? AppTheme.primary : AppTheme.grey500),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? AppTheme.primary : AppTheme.grey800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primary.withOpacity(0.12) : AppTheme.grey100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700,
              color: selected ? AppTheme.primary : AppTheme.grey600)),
          ),
        ]),
      ),
    );
  }
}
