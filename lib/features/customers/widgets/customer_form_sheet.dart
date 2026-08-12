import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/customer.dart';
import '../providers/customer_providers.dart';

/// Membuka form pelanggan (tambah bila [customer] `null`, ubah bila
/// terisi). Mengembalikan `true` bila tersimpan.
Future<bool?> showCustomerForm(BuildContext context, {Customer? customer}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CustomerFormSheet(customer: customer),
  );
}

/// Form pelanggan: nama (wajib), no. HP, catatan.
///
/// Hanya tiga field — daftar pelanggan warung tidak butuh lebih, dan
/// setiap field tambahan adalah satu alasan lagi untuk tidak mengisinya
/// sama sekali (PRD §7.3.B: "nama saja; nomor HP bisa dilengkapi
/// belakangan").
class CustomerFormSheet extends ConsumerStatefulWidget {
  const CustomerFormSheet({super.key, this.customer});

  final Customer? customer;

  @override
  ConsumerState<CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends ConsumerState<CustomerFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _noteController;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phone ?? '');
    _noteController = TextEditingController(text: widget.customer?.note ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(customerRepoProvider);
      if (_isEdit) {
        await repo.update(
          widget.customer!.id,
          name: name,
          phone: _phoneController.text,
          note: _noteController.text,
        );
        ref.invalidate(customerDetailProvider(widget.customer!.id));
      } else {
        await repo.create(
          name: name,
          phone: _phoneController.text,
          note: _noteController.text,
        );
      }
      ref.invalidate(customerListProvider);
      ref.invalidate(customerDebtOverviewProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorMessage.from(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSave = _nameController.text.trim().isNotEmpty && !_saving;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.spaceMd,
            AppSizes.screenPadding,
            AppSizes.spaceMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Ubah Pelanggan' : 'Pelanggan Baru',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSizes.spaceLg),
              TextField(
                controller: _nameController,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama pelanggan *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSizes.spaceMd),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'No. HP (opsional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: AppSizes.spaceMd),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: AppSizes.spaceMd),
                const AppBanner(
                  tone: AppTone.info,
                  icon: Icons.history_edu_outlined,
                  message: 'Mengganti nama TIDAK mengubah struk lama — nama '
                      'pada struk yang sudah tercetak tetap seperti aslinya.',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSizes.spaceMd),
                AppBanner(
                  tone: AppTone.danger,
                  icon: Icons.error_outline_rounded,
                  title: 'Gagal menyimpan',
                  message: _error!,
                ),
              ],
              const SizedBox(height: AppSizes.spaceLg),
              SizedBox(
                height: AppSizes.buttonHeight,
                child: FilledButton(
                  onPressed: canSave ? _save : null,
                  child: _saving
                      ? SizedBox(
                          width: AppSizes.iconMd,
                          height: AppSizes.iconMd,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: context.palette.onPrimary,
                          ),
                        )
                      : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan Pelanggan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
