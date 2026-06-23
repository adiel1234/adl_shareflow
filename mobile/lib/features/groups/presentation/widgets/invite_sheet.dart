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

/// Shows the invite bottom sheet for [groupId] / [groupName].
/// Fetches the invite link, then opens [InviteSheet].
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

/// Reusable invite bottom-sheet with multi-invite counter.
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
  final _guestFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _sendingEmail = false;
  bool _addingGuest = false;
  int _invitedCount = 0;
  final _addedGuests = <String>[];

  @override
  void initState() {
    super.initState();
    _guestFocus.addListener(() {
      if (_guestFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _guestNameController.dispose();
    _guestFocus.dispose();
    _scrollCtrl.dispose();
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
    await Share.share(_inviteText,
        subject: AppLocalizations.of(context)!.inviteSubject(widget.groupName));
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
        _guestFocus.requestFocus();
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
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.invalidEmail)),
      );
      return;
    }
    setState(() => _sendingEmail = true);
    try {
      final api = ApiClient.instance;
      await api.post('/groups/${widget.groupId}/invite/email',
          data: {'email': email});
      if (mounted) {
        _emailController.clear();
        setState(() => _invitedCount++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.inviteSentTo(email))),
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
      controller: _scrollCtrl,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
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

          // Title + close
          Row(
            children: [
              Expanded(
                child: Text(
                  l.inviteFriends,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              if (_invitedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        l.invitedCount(_invitedCount),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: l.notifClose,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // QR Code
          InviteQrCard(code: widget.code, link: widget.link),
          const SizedBox(height: 16),

          // Invite code display
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(l.inviteCode,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  widget.code,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Copy buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: widget.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.codeCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l.copyCode),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: widget.link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.linkCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: Text(l.copyLink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // WhatsApp button — multi-invite
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareViaWhatsApp,
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: Text(_invitedCount == 0
                  ? l.sendViaWhatsApp
                  : l.sendToAnotherWhatsApp),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          if (_invitedCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              l.whatsappOpenHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),

          // Generic share
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _shareGeneric,
              icon: const Icon(Icons.share_outlined, size: 18),
              label: Text(l.shareOtherWay),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Email invite
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              l.sendEmailInviteTitle,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
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
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _sendingEmail
                  ? const SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(strokeWidth: 2))
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
          const SizedBox(height: 8),

          // Guest section — admin only
          if (widget.isAdmin) ...[
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.addGuestTitle,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) {
                      final ll = AppLocalizations.of(ctx)!;
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(Icons.person_outline,
                                color: Colors.purple, size: 20),
                            const SizedBox(width: 8),
                            Text(ll.guestExplainTitle,
                                style: const TextStyle(fontSize: 15)),
                          ],
                        ),
                        content: Text(
                          ll.guestExplainBody,
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: AppColors.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(AppLocalizations.of(ctx)!.gotIt),
                          ),
                        ],
                      );
                    },
                  ),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.info_outline,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.purple.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.guestNoApp,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.purple,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            // Added guests list
            if (_addedGuests.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._addedGuests.map((name) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(name,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _guestNameController,
                    focusNode: _guestFocus,
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
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _addingGuest
                    ? const SizedBox(
                        width: 42,
                        height: 42,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
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
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// QR code card for the invite sheet.
class InviteQrCard extends StatelessWidget {
  final String code;
  final String link;
  const InviteQrCard({super.key, required this.code, required this.link});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            l.qrCodeTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.qrCodeSubtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          QrImageView(
            data: link,
            version: QrVersions.auto,
            size: 200,
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
