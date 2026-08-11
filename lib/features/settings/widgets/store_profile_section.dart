import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/error_message.dart';
import '../../../domain/entities/store_profile.dart';
import '../providers/settings_providers.dart';
import 'settings_card.dart';

/// Seksi Profil Toko (plan.md Milestone 5 poin 1) — nama/alamat/no. HP,
/// tersimpan di `settings` dan otomatis tampil di struk digital lewat
/// `storeProfileProvider` yang dipakai `ReceiptWidget`/`ReceiptService`.
class StoreProfileSection extends ConsumerWidget {
  const StoreProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(storeProfileProvider);
    return SettingsCard(
      title: 'Profil Toko',
      subtitle: 'Nama, alamat, dan no. HP tampil otomatis di struk.',
      children: [
        profileAsync.when(
          data: (profile) => _StoreProfileForm(profile: profile),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.spaceMd),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Gagal memuat profil toko: ${AppErrorMessage.from(e)}'),
        ),
      ],
    );
  }
}

class _StoreProfileForm extends ConsumerStatefulWidget {
  const _StoreProfileForm({required this.profile});

  final StoreProfile profile;

  @override
  ConsumerState<_StoreProfileForm> createState() => _StoreProfileFormState();
}

class _StoreProfileFormState extends ConsumerState<_StoreProfileForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name ?? '');
    _addressController = TextEditingController(text: widget.profile.address ?? '');
    _phoneController = TextEditingController(text: widget.profile.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(settingsRepoProvider);
    await repo.setValue('store_name', _nameController.text.trim());
    await repo.setValue('store_address', _addressController.text.trim());
    await repo.setValue('store_phone', _phoneController.text.trim());
    ref.invalidate(storeProfileProvider);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profil toko disimpan.')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nama Toko'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppSizes.spaceSm),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(labelText: 'Alamat'),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSizes.spaceSm),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(labelText: 'No. HP'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSizes.spaceMd),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan'),
          ),
        ),
      ],
    );
  }
}
