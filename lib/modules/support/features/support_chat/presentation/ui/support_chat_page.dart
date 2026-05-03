import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';

class SupportChatPage extends ConsumerStatefulWidget {
  const SupportChatPage({super.key});

  @override
  ConsumerState<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends ConsumerState<SupportChatPage> {
  final List<_Msg> _messages = <_Msg>[
    const _Msg(fromMe: false, text: "Hi Tunde — I'm Eli from Drivio support. How can I help?", time: '2:42 PM'),
  ];
  final TextEditingController _input = TextEditingController();
  final List<String> _topics = const <String>[
    'Payout issue',
    'Trip dispute',
    'App crash',
    'Account access',
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
                const SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[context.accent, context.accentDim],
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'E',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.accentInk,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Drivio support',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                          Text(
                            'Eli · typing…',
                            style: TextStyle(fontSize: 11, color: context.accent),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text('Avg reply',
                        style: TextStyle(fontSize: 10, color: context.textDim)),
                    Text('< 4 min',
                        style: TextStyle(fontSize: 10, color: context.textDim)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: <Widget>[
                ..._messages.map((_Msg m) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _Bubble(message: m),
                    )),
                if (_messages.length == 1) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Pick a topic to get started:',
                    style: TextStyle(fontSize: 11, color: context.textDim),
                  ),
                  const SizedBox(height: 6),
                  ..._topics.map(
                    (String t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector(
                        onTap: () => _send(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.border),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(fontSize: 13, color: context.text),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.border),
                    ),
                    child: TextField(
                      controller: _input,
                      onSubmitted: _send,
                      cursorColor: context.accent,
                      style: TextStyle(color: context.text, fontSize: 13),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Type your question…',
                        hintStyle: TextStyle(color: context.textMuted, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: context.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _send(_input.text),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(DrivioIcons.send, size: 18, color: context.accentInk),
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

  void _send(String text) {
    if (text.trim().isEmpty) {
      return;
    }
    setState(() {
      _messages.add(_Msg(fromMe: true, text: text, time: 'now'));
      _input.clear();
    });
    Timer(const Duration(milliseconds: 600), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(const _Msg(
          fromMe: false,
          text: 'Thanks — pulling up your account now. Give me 30 seconds…',
          time: 'now',
        ));
      });
    });
  }
}

class _Msg {
  const _Msg({required this.fromMe, required this.text, required this.time});
  final bool fromMe;
  final String text;
  final String time;
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message});
  final _Msg message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool me = message.fromMe;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: me ? context.accent : context.surface,
            borderRadius: BorderRadius.circular(16),
            border: me ? null : Border.all(color: context.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                message.text,
                style: TextStyle(
                  color: me ? context.accentInk : context.text,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message.time,
                style: TextStyle(
                  fontSize: 10,
                  color: me
                      ? context.accentInk.withValues(alpha: 0.6)
                      : context.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
