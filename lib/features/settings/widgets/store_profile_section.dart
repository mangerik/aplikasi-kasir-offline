import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
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
      icon: Icons.storefront_outlined,
      title: 'Profil Toko',
      subtitle: 'Tercetak di kepala struk pembeli.',
      children: [
        profileAsync.when(
          data: (profile) => _StoreProfileForm(profile: profile),
          loading: () => const AppLoadingView(compact: true),
          error: (e, _) => AppErrorView(
            title: 'Profil toko gagal dimuat',
            message: AppErrorMessage.from(e),
            compact: true,
            onRetry: () => ref.invalidate(storeProfileProvider),
          ),
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
          decoration: const InputDecoration(
            labelText: 'Nama Toko',
            hintText: 'Warung Bu Erik',
            prefixIcon: Icon(Icons.store_mall_directory_outlined),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppSizes.spaceMs),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Alamat',
            prefixIcon: Icon(Icons.place_outlined),
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSizes.spaceMs),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'No. HP',
            prefixIcon: Icon(Icons.call_outlined),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSizes.spaceMd),
        SizedBox(
          height: AppSizes.buttonHeight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: AppSizes.iconSm,
                    height: AppSizes.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Menyimpan…' : 'Simpan Profil'),
          ),
        ),
      ],
    );
  }
}
