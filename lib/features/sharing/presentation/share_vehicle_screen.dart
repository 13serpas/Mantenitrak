import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/routes.dart';
import '../../../core/supabase/data_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../vehicles/domain/vehicle.dart';
import '../../vehicles/presentation/providers/vehicle_detail_provider.dart';
import '../domain/share_code.dart';
import 'share_providers.dart';

/// Punto 7: compartir un vehículo con un código o un QR y gestionar
/// quién tiene acceso. Quien no es el propietario ve solo quién lo
/// comparte con él y puede dejar de verlo.
class ShareVehicleScreen extends ConsumerWidget {
  const ShareVehicleScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(vehicleDetailProvider(vehicleId));
    final v = detail.valueOrNull?.vehicle;
    return Scaffold(
      appBar: AppBar(title: Text(v == null || v.isOwner ? 'Compartir vehículo' : 'Personas con acceso')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: MessageBanner(message: e is DataFailure ? e.message : 'No se ha podido cargar el vehículo.'),
        ),
        data: (d) => d == null
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: MessageBanner(message: 'Este vehículo ya no está disponible.'),
              )
            : _ShareBody(vehicle: d.vehicle),
      ),
    );
  }
}

class _ShareBody extends ConsumerWidget {
  const _ShareBody({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final members = ref.watch(vehicleMembersProvider(vehicle.id));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(vehicleMembersProvider(vehicle.id));
        if (vehicle.isOwner) ref.invalidate(shareInviteProvider(vehicle.id));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('${vehicle.type.emoji}  ${vehicle.displayName}',
              style: TextStyle(color: c.textMid, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (vehicle.isOwner) ...[
            _InviteCard(vehicle: vehicle),
            const SizedBox(height: 12),
            const _WhatTheyCanDo(),
          ],
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              members.valueOrNull == null ? 'Personas con acceso' : 'Personas con acceso (${members.value!.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          members.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => MessageBanner(
              message: e is DataFailure ? e.message : 'No se ha podido cargar la lista.',
              actionLabel: 'Reintentar',
              onAction: () => ref.invalidate(vehicleMembersProvider(vehicle.id)),
            ),
            data: (list) => Column(
              children: [
                for (final m in list) _MemberTile(vehicle: vehicle, member: m),
                if (vehicle.isOwner && list.length <= 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Aún no lo has compartido con nadie.',
                      style: TextStyle(color: c.textSoft, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          if (!vehicle.isOwner) ...[
            const SizedBox(height: 24),
            AppButton(
              label: 'Dejar de ver este vehículo',
              variant: AppButtonVariant.outline,
              onPressed: () => _leave(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Dejar de ver este vehículo',
      message: 'Desaparecerá de tu lista. Lo que hayas registrado se queda en el vehículo. '
          'Para volver a verlo necesitarás un código nuevo del propietario.',
      confirmLabel: 'Dejar de verlo',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(vehicleActionsProvider).removeVehicle(vehicle.id, isOwner: false);
      if (context.mounted) context.go(Routes.home);
      messenger.showSnackBar(SnackBar(content: Text('Ya no ves el ${vehicle.displayName}')));
    } on DataFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// QR, código, copiar, compartir y renovar.
class _InviteCard extends ConsumerStatefulWidget {
  const _InviteCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  bool _busy = false;

  Future<void> _copy(ShareInvite inv) async {
    await Clipboard.setData(ClipboardData(text: inv.code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Código ${ShareCode.pretty(inv.code)} copiado')));
    }
  }

  Future<void> _share(ShareInvite inv) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: ShareCode.message(vehicleName: widget.vehicle.displayName, code: inv.code, expiresAt: inv.expiresAt),
      subject: 'Acceso al ${widget.vehicle.displayName} en ManteniTrack',
      // En iPad la hoja de compartir necesita saber desde dónde se abre.
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  Future<void> _regenerate() async {
    final ok = await confirmDialog(
      context,
      title: 'Generar código nuevo',
      message: 'El código actual dejará de funcionar. Quien ya tiene acceso lo mantiene.',
      confirmLabel: 'Generar',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(shareActionsProvider).regenerate(widget.vehicle.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código nuevo generado')));
    } on DataFailure catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final invite = ref.watch(shareInviteProvider(widget.vehicle.id));
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: invite.when(
        loading: () => const SizedBox(height: 260, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => MessageBanner(
          message: e is DataFailure ? e.message : 'No se ha podido crear el código.',
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(shareInviteProvider(widget.vehicle.id)),
        ),
        data: (inv) => Column(
          children: [
            Text(
              'Que lo escaneen con la app o escribe el código',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMid, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Código QR para unirse al vehículo',
              image: true,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  // El QR siempre en blanco y negro, también en modo oscuro:
                  // muchos lectores no leen QR invertidos.
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: QrImageView(
                  data: ShareCode.link(inv.code),
                  size: 190,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(
              ShareCode.pretty(inv.code),
              semanticsLabel: 'Código: ${inv.code.split('').join(' ')}',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(inv.expiryLabel(), style: TextStyle(color: c.textSoft, fontSize: 12.5)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Copiar',
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    variant: AppButtonVariant.outline,
                    onPressed: _busy ? null : () => _copy(inv),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Enviar',
                    icon: const Icon(Icons.share_outlined, size: 18),
                    onPressed: _busy ? null : () => _share(inv),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _busy ? null : _regenerate,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Generar código nuevo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhatTheyCanDo extends StatelessWidget {
  const _WhatTheyCanDo();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget line(String emoji, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Text(emoji)),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: TextStyle(color: c.textMid, fontSize: 13, height: 1.4))),
            ],
          ),
        );
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quien se una podrá…', style: TextStyle(fontWeight: FontWeight.w700)),
          line('✅', 'Ver el estado, el historial y los gastos, y registrar mantenimientos, repostajes y km.'),
          line('🔒', 'Solo tú puedes editar o eliminar el vehículo, cambiar la ficha y compartirlo.'),
          line('⏱️', 'El código caduca a los 7 días. Quien ya se ha unido mantiene el acceso hasta que se lo quites.'),
        ],
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.vehicle, required this.member});

  final Vehicle vehicle;
  final VehicleMember member;

  Future<void> _changeRole(BuildContext context, WidgetRef ref, AccessRole role) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(shareActionsProvider).setRole(vehicle.id, member.userId, role);
      messenger.showSnackBar(SnackBar(content: Text('${member.name}: ${role.label}')));
    } on DataFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Quitar acceso',
      message: '${member.name} dejará de ver el ${vehicle.displayName}. '
          'Lo que haya registrado se queda en el vehículo.',
      confirmLabel: 'Quitar acceso',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(shareActionsProvider).removeMember(vehicle.id, member.userId);
      messenger.showSnackBar(SnackBar(content: Text('${member.name} ya no tiene acceso')));
    } on DataFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final m = member;
    final owner = m.role == AccessRole.owner;
    final canManage = vehicle.isOwner && !owner;
    final subtitle = [
      m.role.label,
      if (m.joinedAt != null && !owner) 'desde ${Fmt.date(m.joinedAt)}',
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: owner ? c.okLight : c.surfaceAlt,
            child: Text(m.initials, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: owner ? c.ok : c.textMid)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.isMe ? '${m.name} (tú)' : m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: c.textSoft, fontSize: 12.5)),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              tooltip: 'Opciones de ${m.name}',
              onSelected: (value) {
                if (value == 'remove') {
                  _remove(context, ref);
                } else {
                  _changeRole(context, ref, AccessRole.parse(value));
                }
              },
              itemBuilder: (_) => [
                for (final r in const [AccessRole.regular, AccessRole.company, AccessRole.mechanic])
                  CheckedPopupMenuItem(value: r.name, checked: m.role == r, child: Text(r.label)),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'remove',
                  child: Text('Quitar acceso', style: TextStyle(color: c.danger)),
                ),
              ],
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}
