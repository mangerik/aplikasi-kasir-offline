import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/app_user.dart';

/// Avatar inisial pengguna (§8.6).
///
/// Foto pengguna sengaja tidak ada di v1.1 — warung tidak punya bahan
/// fotonya, dan inisial berlatar warna peran sudah cukup untuk membedakan
/// tiga sampai lima orang dalam sekejap.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 56});

  final AppUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = user.isOwner ? AppTone.primary : AppTone.neutral;
    final colors = tone.colorsOf(context);
    final muted = !user.isActive;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? palette.surfaceAlt : colors.bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: muted ? palette.border : colors.border,
          width: AppSizes.hairline,
        ),
      ),
      child: Text(
        user.initials,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          height: 1,
          color: muted ? palette.inkTertiary : colors.fg,
        ),
      ),
    );
  }
}

/// Pil peran: Pemilik (primary) vs Kasir (neutral) — §8.6.
class UserRolePill extends StatelessWidget {
  const UserRolePill({super.key, required this.role, this.dense = true});

  final UserRole role;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AppPill(
      label: role.label,
      tone: role.isOwner ? AppTone.primary : AppTone.neutral,
      icon: role.isOwner ? Icons.verified_user_outlined : Icons.badge_outlined,
      dense: dense,
    );
  }
}
