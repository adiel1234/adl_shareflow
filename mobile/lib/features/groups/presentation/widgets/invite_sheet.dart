import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/network/api_client.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/share_service.dart';
import '../../../../theme/app_colors.dart';
import '../../data/group_repository.dart';

/// Full invite flow: optional split-mode question → invite sheet.
Future<void> openInviteFlow(
  BuildContext context, {
  required String groupId,
  required String groupName,
  required bool isAdmin,
  int expenseCountHint = 0,
  VoidCallback? onGuestAdded,
}) async {
  final l = AppLocalizations.of(context)!;
  final repo = GroupRepository();

  var splitMode = 'forward';
  var expenseCount = expenseCountHint;
  try {
    expenseCount = await repo.fetchExpenseCount(groupId);
  } catch (_) {}

  if (expenseCount > 0) {
    if (!context.mounted) return;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final ll = AppLocalizations.of(ctx)!;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            ll.splitExpenses,
            style: const TextStyle(fontWeight: FontWeight.w700),
            textAlign: TextAlign.right,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ll.howShouldNewMemberJoin,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'full'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.centerRight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(ll.splitAll,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(ll.includePastExpenses,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'forward'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.centerRight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(ll.fromNowOn,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(ll.notChargedPast,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(
                ll.cancel,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        );
      },
    );
    if (choice == null || !context.mounted) return;
    splitMode = choice;
  }

  if (!context.mounted) return;

  try {
    final data = await repo.fetchInviteLink(groupId, splitMode: splitMode);
    final code = data['invite_code'] as String;
    final link = data['invite_link'] as String;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InviteSheet(
        code: code,
        link: link,
        groupId: groupId,
        groupName: groupName,
        splitMode: splitMode,
        expenseCount: expenseCount,
        isAdmin: isAdmin,
        onGuestAdded: onGuestAdded,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    var msg = l.errorLoadingInvite;
    if (e is DioException) {
      msg = (e.response?.data?['message'] as String?) ?? msg;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Shows the invite bottom sheet for [groupId] / [groupName].
/// Prefer [openInviteFlow] when starting from the UI (handles split mode).
Future<void> showInviteSheet(
  BuildContext context, {
  required String groupId,
  required String groupName,
  String splitMode = 'forward',
  bool isAdmin = false,
  int expenseCount = 0,
  VoidCallback? onGuestAdded,
}) async {
  try {
    final api = ApiClient.instance;
    final resp = await api.get('/groups/$groupId/invite-link');
    final data = resp.data['data'] as Map<String, dynamic>;
    final code = data['invite_code'] as String;
    final link = data['invite_link'] as String;
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InviteSheet(
        code: code,
        link: link,
        groupId: groupId,
        groupName: groupName,
        splitMode: splitMode,
        expenseCount: expenseCount,
        isAdmin: isAdmin,
        onGuestAdded: onGuestAdded,
      ),
    );
  } catch (e) {
    if (context.mounted) {
      String msg = AppLocalizations.of(context)!.errorLoadingInvite;
      if (e is DioException) {
        msg = (e.response?.data?['message'] as String?) ?? msg;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

/// Compact invite sheet: one primary action, secondary options collapsed.
class InviteSheet extends StatefulWidget {
  final String code;
  final String link;
  final String groupId;
  final String groupName;
  final String splitMode;
  final int expenseCount;
  final bool isAdmin;
  final VoidCallback? onGuestAdded;

  const InviteSheet({
    super.key,
    required this.code,
    required this.link,
    required this.groupId,
    required this.groupName,
    this.splitMode = 'forward',
    this.expenseCount = 0,
    this.isAdmin = false,
    this.onGuestAdded,
  });

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  final _emailController = TextEditingController();
  final _guestNameController = TextEditingController();
  bool _sendingEmail = false;
  bool _addingGuest = false;
  int _invitedCount = 0;
  final _addedGuests = <String>[];

  @override
  void dispose() {
    _emailController.dispose();
    _guestNameController.dispose();
    super.dispose();
  }

  String get _inviteText =>
      AppLocalizations.of(context)!.sendExpenseSplit(
        widget.groupName,
        widget.code,
        widget.link,
      );

  Future<void> _shareViaWhatsApp() async {
    await ShareService.shareViaWhatsApp(_inviteText);
    if (mounted) setState(() => _invitedCount++);
  }

  Future<void> _shareGeneric() async {
    await Share.share(
      _inviteText,
      subject: AppLocalizations.of(context)!.inviteSubject(widget.groupName),
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.linkCopied)),
    );
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.codeCopied)),
    );
  }

  Future<void> _addGuest() async {
    final name = _guestNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _addingGuest = true);
    try {
      await GroupRepository().addGuest(
        widget.groupId,
        name,
        splitMode: widget.splitMode,
      );
      widget.onGuestAdded?.call();
      if (mounted) {
        setState(() {
          _addedGuests.add(name);
          _guestNameController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = AppLocalizations.of(context)!.errorAddingGuest;
        if (e is DioException) {
          msg = (e.response?.data?['message'] as String?) ?? msg;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _addingGuest = false);
    }
  }

  Future<void> _sendEmailInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.invalidEmail)),
      );
      return;
    }
    setState(() => _sendingEmail = true);
    try {
      await ApiClient.instance.post(
        '/groups/${widget.groupId}/invite/email',
        data: {'email': email},
      );
      if (mounted) {
        _emailController.clear();
        setState(() => _invitedCount++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.inviteSentTo(email)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = AppLocalizations.of(context)!.errorSendingInvite;
        if (e is DioException) {
          msg = (e.response?.data?['message'] as String?) ?? msg;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Text(
                  l.inviteFriends,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_invitedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    l.invitedCount(_invitedCount),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: l.notifClose,
              ),
            ],
          ),

          Text(
            l.tipInvitePrimary,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Primary: WhatsApp
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareViaWhatsApp,
              icon: const Icon(Icons.chat_outlined, size: 20),
              label: Text(
                _invitedCount == 0
                    ? l.sendViaWhatsApp
                    : l.sendToAnotherWhatsApp,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary: copy + share
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(l.copyLink),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareGeneric,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: Text(l.shareOtherWay),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Collapsed: QR + code
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(
                l.showQrAndCode,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                InviteQrCard(code: widget.code, link: widget.link),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        l.inviteCode,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.code,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(l.copyCode),
                ),
              ],
            ),
          ),

          // Collapsed: email
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(
                l.inviteEmailOption,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          hintText: 'example@email.com',
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _sendingEmail
                        ? const SizedBox(
                            width: 42,
                            height: 42,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton.filled(
                            onPressed: _sendEmailInvite,
                            icon: const Icon(Icons.send),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),

          // Collapsed: guest (admin)
          if (widget.isAdmin)
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(
                  l.addGuestOption,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  l.guestNoApp,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                children: [
                  if (_addedGuests.isNotEmpty) ...[
                    ..._addedGuests.map(
                      (name) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _guestNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: l.addGuestHint,
                            filled: true,
                            fillColor: AppColors.surfaceVariant,
                            prefixIcon:
                                const Icon(Icons.person_outline, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _addGuest(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _addingGuest
                          ? const SizedBox(
                              width: 42,
                              height: 42,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton.filled(
                              onPressed: _addGuest,
                              icon: const Icon(Icons.person_add),
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.doneBtn),
          ),
        ],
      ),
    );
  }
}

/// Compact QR for the invite sheet (shown only when expanded).
class InviteQrCard extends StatelessWidget {
  final String code;
  final String link;
  const InviteQrCard({super.key, required this.code, required this.link});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            l.qrCodeSubtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          QrImageView(
            data: link,
            version: QrVersions.auto,
            size: 160,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF1A1A2E),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}
