import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/message.dart';
import 'package:drivio_driver/modules/trip/features/chat/presentation/logic/controller/chat_controller.dart';

/// Driver↔passenger chat scoped to a trip. Receives the trip id via
/// route arguments. Until the passenger app exists, the driver is also
/// the passenger and can chat to themselves for testing.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  String? _tripId;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tripId ??= ModalRoute.of(context)?.settings.arguments as String?;
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? id = _tripId;
    if (id == null) {
      return ScreenScaffold(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Chat opens once you start a trip.',
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final ChatState state = ref.watch(chatControllerProvider(id));
    final ChatController c = ref.read(chatControllerProvider(id).notifier);

    // Auto-scroll on new messages.
    ref.listen<ChatState>(chatControllerProvider(id),
        (ChatState? prev, ChatState next) {
      if (prev == null) return;
      if (prev.messages.length != next.messages.length) {
        _scheduleScrollToBottom();
      }
    });

    final List<String> quickReplies = const <String>[
      "On my way",
      "I've arrived",
      "Stuck in traffic",
      "Can you confirm the address?",
    ];

    return ScreenScaffold(
      child: Column(
        children: <Widget>[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
                const SizedBox(width: 12),
                const Avatar(name: 'Rider', variant: 3, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Rider',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.text,
                            fontWeight: FontWeight.w600,
                          )),
                      Row(
                        children: <Widget>[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: context.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('Online',
                              style: TextStyle(
                                  fontSize: 11, color: context.accent)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconCircleButton(
                  icon: DrivioIcons.phone,
                  fg: context.accent,
                  onTap: () =>
                      AppNavigation.push(AppRoutes.call, arguments: id),
                  size: 36,
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading && state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No messages yet — say hi 👋',
                            style: AppTextStyles.bodySm
                                .copyWith(color: context.textDim),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.all(14),
                        itemCount: state.messages.length,
                        separatorBuilder:
                            (BuildContext _, int __) =>
                                const SizedBox(height: 8),
                        itemBuilder: (BuildContext _, int i) {
                          final Message m = state.messages[i];
                          return _Bubble(
                            message: m,
                            fromMe: m.senderUserId == state.myUserId,
                          );
                        },
                      ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                state.error!,
                style: AppTextStyles.bodySm.copyWith(color: context.red),
              ),
            ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: quickReplies.length,
              separatorBuilder: (BuildContext _, int __) =>
                  const SizedBox(width: 6),
              itemBuilder: (BuildContext _, int i) => GestureDetector(
                onTap: state.isSending
                    ? null
                    : () => c.send(quickReplies[i],
                        kind: MessageKind.quickReply),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.border),
                  ),
                  child: Text(
                    quickReplies[i],
                    style: TextStyle(
                      fontSize: 11,
                      color: context.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.border)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.border),
                    ),
                    child: TextField(
                      controller: _input,
                      onSubmitted: (String text) => _onSend(c, text),
                      cursorColor: context.accent,
                      enabled: !state.isSending,
                      style: TextStyle(color: context.text, fontSize: 13),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Type a message…',
                        hintStyle: TextStyle(
                            color: context.textMuted, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: state.isSending ? context.textMuted : context.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: state.isSending ? null : () => _onSend(c, _input.text),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(DrivioIcons.send,
                          color: context.accentInk, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onSend(ChatController c, String text) {
    if (text.trim().isEmpty) return;
    c.send(text);
    _input.clear();
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.fromMe});
  final Message message;
  final bool fromMe;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: fromMe ? context.accent : context.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomRight: Radius.circular(fromMe ? 4 : 16),
              bottomLeft: Radius.circular(fromMe ? 16 : 4),
            ),
            border: fromMe ? null : Border.all(color: context.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                message.body,
                style: TextStyle(
                  color: fromMe ? context.accentInk : context.text,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _fmtTime(message.createdAt),
                style: TextStyle(
                  color: fromMe
                      ? context.accentInk.withValues(alpha: 0.6)
                      : context.textDim,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtTime(DateTime t) {
    final DateTime local = t.toLocal();
    final int h = local.hour;
    final int m = local.minute;
    final String hh = h == 0
        ? '12'
        : h > 12
            ? (h - 12).toString()
            : h.toString();
    final String mm = m.toString().padLeft(2, '0');
    final String ampm = h >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $ampm';
  }
}
