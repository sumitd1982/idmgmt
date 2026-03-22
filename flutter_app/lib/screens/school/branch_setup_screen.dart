// ============================================================
// Branch Setup Screen — shown after new school creation
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

class BranchSetupScreen extends ConsumerStatefulWidget {
  final String schoolId;
  final String schoolName;
  final String schoolCode;
  final String schoolPhone;
  final String schoolEmail;
  final String schoolAddress;
  final String schoolCity;

  const BranchSetupScreen({
    super.key,
    required this.schoolId,
    required this.schoolName,
    required this.schoolCode,
    required this.schoolPhone,
    required this.schoolEmail,
    required this.schoolAddress,
    required this.schoolCity,
  });

  @override
  ConsumerState<BranchSetupScreen> createState() => _BranchSetupScreenState();
}

class _BranchSetupScreenState extends ConsumerState<BranchSetupScreen> {
  final _formKey     = GlobalKey<FormState>();
  bool _singleBranch = false;
  bool _saving       = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController();
    _codeCtrl    = TextEditingController();
    _phoneCtrl   = TextEditingController();
    _emailCtrl   = TextEditingController();
    _addressCtrl = TextEditingController();
    _cityCtrl    = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _applySchoolInfo(bool checked) {
    setState(() => _singleBranch = checked);
    if (checked) {
      _nameCtrl.text    = widget.schoolName;
      _codeCtrl.text    = '${widget.schoolCode}-MAIN';
      _phoneCtrl.text   = widget.schoolPhone;
      _emailCtrl.text   = widget.schoolEmail;
      _addressCtrl.text = widget.schoolAddress;
      _cityCtrl.text    = widget.schoolCity;
    } else {
      _nameCtrl.clear();
      _codeCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
      _addressCtrl.clear();
      _cityCtrl.clear();
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ApiService().post('/branches', body: {
        'school_id':    widget.schoolId,
        'name':         _nameCtrl.text.trim(),
        'code':         _codeCtrl.text.trim().toUpperCase(),
        'phone1':       _phoneCtrl.text.trim(),
        'email':        _emailCtrl.text.trim(),
        'address_line1': _addressCtrl.text.trim(),
        'city':         _cityCtrl.text.trim(),
      });

      if (!mounted) return;

      final shouldUpload = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BranchCreatedDialog(branchName: _nameCtrl.text.trim()),
      );

      if (!mounted) return;
      if (shouldUpload == true) {
        context.go('/employees');
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up First Branch'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress hint
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree_outlined,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Great! "${widget.schoolName}" is registered. '
                        'Every school needs at least one branch. '
                        'You can add more branches later.',
                        style: GoogleFonts.poppins(
                            fontSize: 12.5, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Single-branch checkbox
              Container(
                decoration: BoxDecoration(
                  color: _singleBranch
                      ? AppTheme.statusGreen.withOpacity(0.07)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _singleBranch
                        ? AppTheme.statusGreen.withOpacity(0.4)
                        : AppTheme.grey300,
                  ),
                ),
                child: CheckboxListTile(
                  value: _singleBranch,
                  onChanged: (v) => _applySchoolInfo(v ?? false),
                  title: Text('This school has only one branch',
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, fontWeight: FontWeight.w600,
                          color: AppTheme.grey900)),
                  subtitle: Text('Branch details will be pre-filled from school info',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppTheme.grey600)),
                  activeColor: AppTheme.statusGreen,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              ),
              const SizedBox(height: 24),

              _sectionTitle('Branch Details'),
              const SizedBox(height: 12),

              _field(
                label: 'Branch Name *',
                controller: _nameCtrl,
                hint: 'e.g. Main Branch / North Campus',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      label: 'Branch Code *',
                      controller: _codeCtrl,
                      hint: 'e.g. ABC-MAIN',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!RegExp(r'^[A-Z0-9\-]+$')
                            .hasMatch(v.trim().toUpperCase())) {
                          return 'Alphanumeric / hyphens only';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _field(
                      label: 'Phone',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _field(
                label: 'Email',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _field(
                label: 'Address',
                controller: _addressCtrl,
                hint: 'Street address',
              ),
              const SizedBox(height: 14),
              _field(
                label: 'City',
                controller: _cityCtrl,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color:     AppTheme.primary.withOpacity(0.08),
              blurRadius: 10,
              offset:    const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Skip for now'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 16),
              label: Text(_saving ? 'Saving...' : 'Submit Branch'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.grey900),
      );

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey400),
      ),
    );
  }
}

// ── Branch Created Dialog ─────────────────────────────────────
class _BranchCreatedDialog extends StatelessWidget {
  final String branchName;
  const _BranchCreatedDialog({required this.branchName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppTheme.statusGreen.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_tree_rounded,
                color: AppTheme.statusGreen, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Branch Submitted!',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppTheme.grey900)),
          const SizedBox(height: 8),
          Text(
            '"$branchName" has been created successfully.\n\n'
            'Next step: upload your staff list via Excel to build the organisation structure.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey600),
          ),
          const SizedBox(height: 24),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Done'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.upload_file, size: 16),
          label: const Text('Upload Employees'),
        ),
      ],
    );
  }
}
